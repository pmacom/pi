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

# Update the package list and upgrade existing packages
apt update && apt -y upgrade

# Check if GStreamer is installed
if ! command -v gst-launch-1.0 &> /dev/null; then
  log "GStreamer not found. Installing GStreamer..."
  apt install -y gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good
  log "✅ GStreamer installed successfully."
else
  log "✅ GStreamer is already installed."
fi

# Install v4l2loopback-dkms and force a rebuild
log "Installing v4l2loopback-dkms and forcing a module rebuild..."
apt install -y v4l2loopback-dkms
dpkg-reconfigure v4l2loopback-dkms

# Check if v4l2loopback module loads successfully
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

# Create usb_gadget_setup.sh script
GADGET_SCRIPT="/usr/bin/usb_gadget_setup.sh"
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
  for function in /sys/kernel/config/usb_gadget/uvc_gadget/configs/*/uvc.usb*; do
    if [ -L "$function" ]; then
      rm "$function"
    fi
  done
  rm -rf /sys/kernel/config/usb_gadget/uvc_gadget
fi

# Load necessary modules
modprobe libcomposite

# Set up gadget directory
GADGET_DIR=/sys/kernel/config/usb_gadget/uvc_gadget
mkdir -p $GADGET_DIR
cd $GADGET_DIR

# Set Vendor and Product IDs
echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

# Set device attributes
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Create English locale strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Raspberry Pi Foundation" > strings/0x409/manufacturer
echo "Pi Zero USB Camera" > strings/0x409/product

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "UVC" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower

# Create UVC function
mkdir -p functions/uvc.usb0
echo 0 > functions/uvc.usb0/streaming_maxpacket
echo 1 > functions/uvc.usb0/streaming_maxburst
mkdir -p functions/uvc.usb0/control/header/h
mkdir -p functions/uvc.usb0/control/class/fs
mkdir -p functions/uvc.usb0/control/class/ss
ln -s functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/fs/h
ln -s functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/ss/h

# Configure streaming interface
mkdir -p functions/uvc.usb0/streaming/uncompressed/u/1
echo 640 > functions/uvc.usb0/streaming/uncompressed/u/1/wWidth
echo 480 > functions/uvc.usb0/streaming/uncompressed/u/1/wHeight
echo 333333 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMinBitRate
echo 1843200 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMaxVideoFrameBufferSize
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwDefaultFrameInterval
echo 1 > functions/uvc.usb0/streaming/uncompressed/u/1/bFrameIntervalType
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwFrameInterval.1
mkdir -p functions/uvc.usb0/streaming/header/h
mkdir -p functions/uvc.usb0/streaming/class/fs
mkdir -p functions/uvc.usb0/streaming/class/hs
ln -s functions/uvc.usb0/streaming/uncompressed/u functions/uvc.usb0/streaming/header/h
ln -s functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/fs/h
ln -s functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/hs/h

# Link function to configuration
ln -s functions/uvc.usb0 configs/c.1/

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
echo "$UDC_DEVICE" > UDC
EOF
chmod +x "$GADGET_SCRIPT"

# Create and enable usb_gadget.service
SERVICE_FILE="/etc/systemd/system/usb_gadget.service"
log "Creating $SERVICE_FILE..."
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=USB Gadget Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=sudo /usr/bin/usb_gadget_setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now usb_gadget.service

# Create and enable streaming.service
STREAMING_SERVICE="/etc/systemd/system/streaming.service"
log "Creating $STREAMING_SERVICE..."
cat << EOF > "$STREAMING_SERVICE"
[Unit]
Description=Camera Streaming Service
After=usb_gadget.service

[Service]
Type=simple
ExecStart=/usr/bin/streaming.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now streaming.service

# Create streaming.sh script
STREAMING_SCRIPT="/usr/bin/streaming.sh"
log "Creating $STREAMING_SCRIPT..."
cat << 'EOF' > "$STREAMING_SCRIPT"
#!/bin/bash
# streaming.sh - Script to start video streaming with verbose logging

LOG_FILE="/var/log/streaming.log"
> "$LOG_FILE" # Clear the previous log

echo "$(date): Starting streaming service..." | tee -a "$LOG_FILE"

# Wait for /dev/video2 to become available
RETRY=5
while [ ! -e /dev/video2 ] && [ $RETRY -gt 0 ]; do
  echo "$(date): Waiting for /dev/video2..." | tee -a "$LOG_FILE"
  sleep 2
  RETRY=$((RETRY-1))
done

if [ ! -e /dev/video2 ]; then
  echo "$(date): /dev/video2 not found after retries. Exiting." | tee -a "$LOG_FILE"
  exit 1
fi

echo "$(date): /dev/video2 is available. Starting GStreamer pipeline..." | tee -a "$LOG_FILE"

# Load v4l2loopback module if not already loaded
if ! lsmod | grep -q v4l2loopback; then
  echo "$(date): Loading v4l2loopback module..." | tee -a "$LOG_FILE"
  modprobe v4l2loopback video_nr=2 exclusive_caps=1
fi

# Test if v4l2src can initialize (use fakesink to discard output)
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,width=640,height=480 ! videoconvert ! fakesink 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "$(date): GStreamer fakesink test failed. Exiting." | tee -a "$LOG_FILE"
  exit 1
fi

# If fakesink test passes, continue with autovideosink
echo "$(date): fakesink test passed. Launching main GStreamer pipeline..." | tee -a "$LOG_FILE"
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,width=640,height=480 ! videoconvert ! autovideosink 2>&1 | tee -a "$LOG_FILE"

EOF
chmod +x "$STREAMING_SCRIPT"

# Adjust AppArmor settings if necessary (for Ubuntu)
if command -v aa-status &> /dev/null; then
  log "Adjusting AppArmor settings..."
  aa-complain /sys/kernel/config/**
fi

log "Automated setup complete. Services are now running."
