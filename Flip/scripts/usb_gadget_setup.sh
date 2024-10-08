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
sleep 2
echo "$UDC_DEVICE" > UDC