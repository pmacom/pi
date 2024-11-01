#!/bin/bash
set -e  # Exit on error
set -x  # Enable debugging

LOG_FILE="/var/log/usb_gadget_setup.log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Check and load necessary kernel modules
check_module() {
    if ! lsmod | grep -q "$1"; then
        log "Loading kernel module $1..."
        modprobe "$1" || { log "Failed to load $1"; exit 1; }
    else
        log "Kernel module $1 is already loaded."
    fi
}

check_module "libcomposite"
check_module "dwc2"

# Clean up existing configuration
if [ -d /sys/kernel/config/usb_gadget/pi_gadget ]; then
    log "Cleaning up existing gadget configuration..."
    if [ -e /sys/kernel/config/usb_gadget/pi_gadget/UDC ]; then
        echo "" > /sys/kernel/config/usb_gadget/pi_gadget/UDC
    fi
    sleep 2  # Allow time for unbinding
    rm -rf /sys/kernel/config/usb_gadget/pi_gadget
fi

# Set up new gadget configuration
log "Setting up new USB gadget configuration..."
mkdir -p /sys/kernel/config/usb_gadget/pi_gadget
cd /sys/kernel/config/usb_gadget/pi_gadget || { log "Failed to change directory"; exit 1; }

# Set Vendor and Product ID
echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

# Set device properties
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Device strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Raspberry Pi Foundation" > strings/0x409/manufacturer
echo "Pi USB Gadget" > strings/0x409/product

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "Pi Composite" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

# Add functions
mkdir -p functions/ecm.usb0  # Ethernet
mkdir -p functions/uvc.usb0  # Video
mkdir -p functions/mass_storage.usb0  # Mass storage for DisplayLink

# Configure functions
# ... (Add specific configuration for each function here)

# Link functions to configuration
ln -s functions/ecm.usb0 configs/c.1/
ln -s functions/uvc.usb0 configs/c.1/
ln -s functions/mass_storage.usb0 configs/c.1/

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
if [ -z "$UDC_DEVICE" ]; then
    log "No UDC device found. Exiting."
    exit 1
fi
log "Using UDC device: $UDC_DEVICE"
echo "$UDC_DEVICE" > UDC || { log "Failed to bind gadget to UDC"; exit 1; }

log "USB gadget setup completed successfully."