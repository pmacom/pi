#!/bin/bash

# usb_gadget_setup.sh
# Configures the USB gadget via configfs for UVC (USB Video Class)

set -e

echo "Loading libcomposite module..."
sudo modprobe libcomposite

GADGET_DIR="/sys/kernel/config/usb_gadget/pi_gadget"
if [ -d $GADGET_DIR ]; then
    echo "Gadget already configured."
    exit 0
fi

echo "Creating USB gadget configuration..."
sudo mkdir -p $GADGET_DIR
cd $GADGET_DIR

echo "Setting basic gadget parameters..."
echo 0x1d6b > idVendor   # Linux Foundation
echo 0x0104 > idProduct  # Multifunction Composite Gadget
echo 0x0100 > bcdDevice  # v1.0.0
echo 0x0200 > bcdUSB     # USB 2.0

echo "Creating English strings..."
mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "Your Company" > strings/0x409/manufacturer
echo "Pi Zero W USB Camera" > strings/0x409/product

echo "Creating configuration..."
mkdir -p configs/c.1/strings/0x409
echo 250 > configs/c.1/MaxPower
echo "USB Camera Configuration" > configs/c.1/strings/0x409/configuration

echo "Adding UVC function..."
mkdir -p functions/uvc.usb0
UVC_DIR="functions/uvc.usb0"

echo "Setting up UVC descriptors..."
mkdir -p $UVC_DIR/control/header/h
ln -s $UVC_DIR/control/header/h $UVC_DIR/control/class/fs/h
ln -s $UVC_DIR/control/header/h $UVC_DIR/control/class/hs/h

mkdir -p $UVC_DIR/streaming/uncompressed/u
echo 1 > $UVC_DIR/streaming/uncompressed/u/bDescriptorSubtype
echo 1 > $UVC_DIR/streaming/uncompressed/u/bFormatIndex
echo 1 > $UVC_DIR/streaming/uncompressed/u/bNumFrameDescriptors
echo 2 > $UVC_DIR/streaming/uncompressed/u/bBitsPerPixel
echo 1 > $UVC_DIR/streaming/uncompressed/u/bDefaultFrameIndex
echo 0 > $UVC_DIR/streaming/uncompressed/u/bAspectRatioX
echo 0 > $UVC_DIR/streaming/uncompressed/u/bAspectRatioY

echo "Linking UVC streaming headers..."
mkdir -p $UVC_DIR/streaming/header/h
ln -s $UVC_DIR/streaming/uncompressed/u $UVC_DIR/streaming/header/h/u
ln -s $UVC_DIR/streaming/header/h $UVC_DIR/streaming/class/fs/h
ln -s $UVC_DIR/streaming/header/h $UVC_DIR/streaming/class/hs/h

echo "Linking UVC function to configuration..."
ln -s $UVC_DIR configs/c.1/

echo "Enabling the USB gadget..."
echo "$(ls /sys/class/udc)" > UDC

echo "USB gadget configuration completed."
