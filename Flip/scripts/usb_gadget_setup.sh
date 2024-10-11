#!/bin/bash
set -x  # Enable debugging

# USB gadget setup script for both DisplayLink and UVC camera functions

# Clean up existing configuration
if [ -d /sys/kernel/config/usb_gadget/dual_gadget ]; then
  echo "" > /sys/kernel/config/usb_gadget/dual_gadget/UDC
  sleep 1  # Allow time for unbinding
  rm -rf /sys/kernel/config/usb_gadget/dual_gadget
fi

# Set up new gadget configuration
mkdir -p /sys/kernel/config/usb_gadget/dual_gadget
cd /sys/kernel/config/usb_gadget/dual_gadget

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
# Link framebuffer config (requires additional steps, see below)

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
ln -s functions/ffs.usb0 configs/c.1/  # DisplayLink
ln -s functions/uvc.usb0 configs/c.1/  # UVC Camera

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
echo "$UDC_DEVICE" > UDC