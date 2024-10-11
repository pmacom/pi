#!/bin/bash
set -e  # Exit on error
set -x  # Enable debugging

LOG_FILE="/var/log/usb_gadget_setup.log"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function to check if a kernel module is loaded
check_module() {
    if ! lsmod | grep -q "$1"; then
        log "Loading kernel module $1..."
        modprobe "$1" || { log "Failed to load $1"; exit 1; }
    else
        log "Kernel module $1 is already loaded."
    fi
}

# Check and load necessary kernel modules
check_module "libcomposite"
check_module "dwc2"

# Clean up existing configuration
if [ -d /sys/kernel/config/usb_gadget/dual_gadget ]; then
    log "Cleaning up existing gadget configuration..."
    if [ -e /sys/kernel/config/usb_gadget/dual_gadget/UDC ]; then
        echo "" > /sys/kernel/config/usb_gadget/dual_gadget/UDC
    fi
    sleep 2  # Allow time for unbinding
    rm -rf /sys/kernel/config/usb_gadget/dual_gadget
fi

# Set up new gadget configuration
log "Setting up new USB gadget configuration..."
mkdir -p /sys/kernel/config/usb_gadget/dual_gadget
cd /sys/kernel/config/usb_gadget/dual_gadget || { log "Failed to change directory"; exit 1; }

# Set Vendor and Product ID
echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

# Set device properties
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# English strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Raspberry Pi Foundation" > strings/0x409/manufacturer
echo "Pi USB Display and Camera" > strings/0x409/product

# Add DisplayLink function (Framebuffer for USB display)
mkdir -p functions/ffs.usb0

# Add UVC camera function
mkdir -p functions/uvc.usb0/streaming/uncompressed/u/1
echo 640 > functions/uvc.usb0/streaming/uncompressed/u/1/wWidth
echo 480 > functions/uvc.usb0/streaming/uncompressed/u/1/wHeight
echo 333333 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMinBitRate
echo 1843200 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMaxVideoFrameBufferSize
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwDefaultFrameInterval
echo 1 > functions/uvc.usb0/streaming/uncompressed/u/1/bFrameIntervalType
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwFrameInterval.1

# Set configuration
mkdir -p configs/c.1/strings/0x409
echo "Dual Function" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower

# Link the functions to the configuration
ln -s functions/ffs.usb0 configs/c.1/ || log "Failed to link DisplayLink function"
ln -s functions/uvc.usb0 configs/c.1/ || log "Failed to link UVC Camera function"

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
if [ -z "$UDC_DEVICE" ]; then
    log "No UDC device found. Exiting."
    exit 1
fi
log "Using UDC device: $UDC_DEVICE"
echo "$UDC_DEVICE" > UDC || { log "Failed to bind gadget to UDC"; exit 1; }

log "USB gadget setup completed successfully."