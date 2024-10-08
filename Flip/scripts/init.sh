#!/bin/bash
# init-bookworm.sh - Automated setup script to configure Raspberry Pi Zero as a USB webcam

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./init-bookworm.sh"
  exit
fi

# Log file for tracking progress and errors
LOG_FILE="/var/log/init-bookworm.log"
> "$LOG_FILE"

log() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting automated setup..."

# Update file contents with the latest from the init directory
DIR_PATH="./"
TARGET_PATHS=(
  "/etc/systemd/system/streaming.service"
  "/usr/bin/streaming.sh"
  "/usr/bin/usb_gadget_setup.sh"
  "/etc/systemd/system/usb_gadget.service"
)

SOURCE_FILES=("streaming.service" "streaming.sh" "usb_gadget_setup.sh" "usb_gadget.service")

for i in "${!SOURCE_FILES[@]}"; do
  SOURCE_FILE="$DIR_PATH/${SOURCE_FILES[i]}"
  TARGET_FILE="${TARGET_PATHS[i]}"
  
  if [ -f "$SOURCE_FILE" ]; then
    log "Replacing contents of $TARGET_FILE with $SOURCE_FILE..."
    cat "$SOURCE_FILE" > "$TARGET_FILE"
    chmod +x "$TARGET_FILE" # Set execute permission if needed
  else
    log "Warning: $SOURCE_FILE not found; skipping."
  fi
done

log "Replacement of files complete. Proceeding with setup..."

# Update the package list and upgrade existing packages
apt update && apt -y upgrade

# Check for and install necessary kernel headers
log "Checking for Raspberry Pi kernel headers..."
if ! dpkg -s raspberrypi-kernel-headers &> /dev/null; then
  log "Kernel headers not found. Installing headers..."
  apt install -y raspberrypi-kernel-headers
else
  log "Kernel headers are already installed."
fi

# Install and reconfigure v4l2loopback-dkms
log "Installing and configuring v4l2loopback-dkms..."
apt install -y v4l2loopback-dkms
dpkg-reconfigure v4l2loopback-dkms

# Check if v4l2loopback module loads successfully
log "Attempting to load v4l2loopback module..."
if ! modprobe v4l2loopback video_nr=2 exclusive_caps=1; then
  log "❌ Failed to load v4l2loopback. Please check for any installation errors."
else
  log "✅ v4l2loopback module loaded successfully."
fi

# Ensure v4l2loopback loads on boot
if ! grep -q "^v4l2loopback" /etc/modules; then
  echo "v4l2loopback" >> /etc/modules
fi

# Configure /boot/config.txt if necessary
CONFIG_FILE="/boot/config.txt"
if ! grep -q "^dtoverlay=dwc2,dr_mode=peripheral" "$CONFIG_FILE"; then
  log "Configuring $CONFIG_FILE..."
  echo "dtoverlay=dwc2,dr_mode=peripheral" >> "$CONFIG_FILE"
fi

# Configure /boot/cmdline.txt if necessary
CMDLINE_FILE="/boot/cmdline.txt"
if ! grep -q "modules-load=dwc2" "$CMDLINE_FILE"; then
  log "Configuring $CMDLINE_FILE..."
  sed -i 's/\(rootwait\)/\1 modules-load=dwc2/' "$CMDLINE_FILE"
fi

# Ensure dwc2 and libcomposite modules load on boot
if ! grep -q "^dwc2" /etc/modules; then
  echo -e "dwc2\nlibcomposite" >> /etc/modules
fi

# Mount configfs if not already mounted
if ! mountpoint -q /sys/kernel/config; then
  log "Mounting configfs..."
  mount -t configfs none /sys/kernel/config
  if ! grep -q "^none /sys/kernel/config configfs" /etc/fstab; then
    echo "none /sys/kernel/config configfs defaults 0 0" >> /etc/fstab
  fi
fi

# Check for usb_gadget_setup.sh script and recreate if missing
GADGET_SCRIPT="/usr/bin/usb_gadget_setup.sh"
if [ ! -f "$GADGET_SCRIPT" ]; then
  log "Creating $GADGET_SCRIPT..."
  cat << 'EOF' > "$GADGET_SCRIPT"
#!/bin/bash
# usb_gadget_setup.sh - Script to configure USB gadget

# Unbind and remove existing gadget if it exists
if [ -d /sys/kernel/config/usb_gadget/uvc_gadget ]; then
  echo "Cleaning up existing gadget configuration..."
  if [ -e /sys/kernel/config/usb_gadget/uvc_gadget/UDC ]; then
    echo "" > /sys/kernel/config/usb_gadget/uvc_gadget/UDC
  fi
  rm -rf /sys/kernel/config/usb_gadget/uvc_gadget
fi

# Set up gadget directory
modprobe libcomposite
mkdir -p /sys/kernel/config/usb_gadget/uvc_gadget
cd /sys/kernel/config/usb_gadget/uvc_gadget

# Device configuration commands here...
EOF
  chmod +x "$GADGET_SCRIPT"
fi

# Ensure usb_gadget.service is enabled
systemctl daemon-reload
systemctl enable --now usb_gadget.service

# Ensure streaming.service is enabled
systemctl enable --now streaming.service

log "Automated setup complete. Please reboot to apply changes."
