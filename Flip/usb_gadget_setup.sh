#!/bin/bash

# Unbind and remove existing gadget if it exists
if [ -d /sys/kernel/config/usb_gadget/uvc_gadget ]; then
    echo "Cleaning up existing gadget configuration..."

    # Unbind the gadget
    if [ -e /sys/kernel/config/usb_gadget/uvc_gadget/UDC ]; then
        echo "" | sudo tee /sys/kernel/config/usb_gadget/uvc_gadget/UDC
    fi

    # Unlink functions from configurations
    for function in /sys/kernel/config/usb_gadget/uvc_gadget/configs/*/uvc.usb*; do
        if [ -L "$function" ]; then
            sudo unlink "$function"
        fi
    done

    # Remove the gadget directory
    sudo rm -rf /sys/kernel/config/usb_gadget/uvc_gadget
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

# Create UVC function
mkdir -p functions/uvc.usb0
mkdir -p functions/uvc.usb0/control/header/h
ln -sf functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/fs/h
ln -sf functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/ss/h

# Streaming configuration
mkdir -p functions/uvc.usb0/streaming/uncompressed/u/1
echo 640 > functions/uvc.usb0/streaming/uncompressed/u/1/wWidth
echo 480 > functions/uvc.usb0/streaming/uncompressed/u/1/wHeight
echo 333333 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMinBitRate
echo 1843200 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMaxVideoFrameBufferSize
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwDefaultFrameInterval
echo 1 > functions/uvc.usb0/streaming/uncompressed/u/1/bFrameIntervalType
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwFrameInterval.1

mkdir -p functions/uvc.usb0/streaming/header/h
ln -sf functions/uvc.usb0/streaming/uncompressed/u functions/uvc.usb0/streaming/header/h
ln -sf functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/fs/h
ln -sf functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/hs/h

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "UVC" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower

# Link function to configuration
ln -sf functions/uvc.usb0 configs/c.1/

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc 2>/dev/null)
if [ -z "$UDC_DEVICE" ]; then
    echo "Error: No UDC device found. Check if USB gadget support is enabled in the kernel."
    exit 1
else
    echo "$UDC_DEVICE" > UDC
fi