#!/bin/bash
# USB gadget setup script for both DisplayLink and UVC camera functions

# Clean up existing configuration
if [ -d /sys/kernel/config/usb_gadget/dual_gadget ]; then
  sudo echo "" > /sys/kernel/config/usb_gadget/dual_gadget/UDC
  sudo rm -rf /sys/kernel/config/usb_gadget/dual_gadget
fi

# Set up new gadget configuration
sudo mkdir -p /sys/kernel/config/usb_gadget/dual_gadget
cd /sys/kernel/config/usb_gadget/dual_gadget

# Set Vendor and Product ID
sudo echo 0x1d6b > idVendor  # Linux Foundation
sudo echo 0x0104 > idProduct # Multifunction Composite Gadget

# Set device properties
sudo echo 0x0100 > bcdDevice
sudo echo 0x0200 > bcdUSB

# English strings
sudo mkdir -p strings/0x409
sudo echo "0123456789" > strings/0x409/serialnumber
sudo echo "Raspberry Pi Foundation" > strings/0x409/manufacturer
sudo echo "Pi USB Display and Camera" > strings/0x409/product

# Add DisplayLink function (Framebuffer for USB display)
sudo mkdir -p functions/ffs.usb0
# Link framebuffer config (requires additional steps, see below)

# Add UVC camera function
sudo mkdir -p functions/uvc.usb0
sudo echo 640 > functions/uvc.usb0/streaming/uncompressed/u/1/wWidth
sudo echo 480 > functions/uvc.usb0/streaming/uncompressed/u/1/wHeight
sudo echo 333333 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMinBitRate
sudo echo 1843200 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMaxVideoFrameBufferSize
sudo echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwDefaultFrameInterval
sudo echo 1 > functions/uvc.usb0/streaming/uncompressed/u/1/bFrameIntervalType
sudo echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwFrameInterval.1

# Set configuration
sudo mkdir -p configs/c.1/strings/0x409
sudo echo "Dual Function" > configs/c.1/strings/0x409/configuration
sudo echo 120 > configs/c.1/MaxPower

# Link the functions to the configuration
sudo ln -s functions/ffs.usb0 configs/c.1/  # DisplayLink
sudo ln -s functions/uvc.usb0 configs/c.1/  # UVC Camera

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
sudo echo "$UDC_DEVICE" > UDC
