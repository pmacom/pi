#!/bin/bash
set -e  # Exit on error

LOG_FILE="/var/log/init.log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    log "Please run as root: sudo ./init.sh"
    exit 1
fi

log "Starting automated setup..."

# Function to safely update files
update_file() {
    local source_file="$1"
    local target_file="$2"
    
    if [ -f "$source_file" ]; then
        log "Updating $target_file with $source_file..."
        cat "$source_file" > "$target_file" || { log "Failed to update $target_file"; exit 1; }
        chmod +x "$target_file" 2>/dev/null || true
    else
        log "Warning: $source_file not found; skipping."
    fi
}

# Update configuration files
DIR_PATH="./"
declare -A files=(
    ["streaming.service"]="/etc/systemd/system/streaming.service"
    ["streaming.sh"]="/usr/bin/streaming.sh"
    ["usb_gadget_setup.sh"]="/usr/bin/usb_gadget_setup.sh"
    ["usb_gadget.service"]="/etc/systemd/system/usb_gadget.service"
)

for source_file in "${!files[@]}"; do
    update_file "$DIR_PATH$source_file" "${files[$source_file]}"
done

log "File updates complete. Proceeding with system configuration..."

# Update and upgrade system packages
log "Updating system packages..."
apt update && apt -y upgrade || { log "Failed to update system packages"; exit 1; }

# Install and configure kernel headers and v4l2loopback
log "Installing and configuring kernel headers and v4l2loopback..."
apt install -y raspberrypi-kernel-headers v4l2loopback-dkms || { log "Failed to install packages"; exit 1; }
dpkg-reconfigure v4l2loopback-dkms || { log "Failed to reconfigure v4l2loopback-dkms"; exit 1; }

# Load v4l2loopback module
log "Loading v4l2loopback module..."
modprobe v4l2loopback video_nr=2 exclusive_caps=1 || { log "Failed to load v4l2loopback module"; exit 1; }

# Ensure modules load on boot
log "Configuring modules to load on boot..."
echo -e "v4l2loopback\ndwc2\nlibcomposite" >> /etc/modules

# Configure boot files
log "Configuring boot files..."
echo "dtoverlay=dwc2,dr_mode=peripheral" >> /boot/config.txt
sed -i 's/$/ modules-load=dwc2/' /boot/cmdline.txt

# Mount configfs
log "Mounting configfs..."
mount -t configfs none /sys/kernel/config || { log "Failed to mount configfs"; exit 1; }
echo "none /sys/kernel/config configfs defaults 0 0" >> /etc/fstab

# Enable and start services
log "Enabling and starting services..."
systemctl daemon-reload
systemctl enable --now usb_gadget.service || { log "Failed to enable usb_gadget service"; exit 1; }
systemctl enable --now streaming.service || { log "Failed to enable streaming service"; exit 1; }

log "Automated setup complete. Please reboot to apply all changes."