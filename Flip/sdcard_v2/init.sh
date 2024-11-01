#!/bin/bash

# init.sh
# Initial setup script for Raspberry Pi Zero W

set -e

echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

echo "Installing necessary packages..."
sudo apt-get install -y raspberrypi-kernel-headers build-essential git dkms \
libv4l-dev v4l-utils cmake libjpeg-dev ffmpeg libusb-1.0-0-dev libudev-dev

echo "Enabling the Raspberry Pi camera in /boot/config.txt..."
sudo sed -i '/^start_x=/d' /boot/config.txt
sudo sed -i '/^gpu_mem=/d' /boot/config.txt
echo "start_x=1" | sudo tee -a /boot/config.txt
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

echo "Cloning and installing uvc-gadget..."
git clone https://github.com/pvaret/uvc-gadget.git
cd uvc-gadget
make
sudo make install
cd ..

echo "Loading necessary kernel modules..."
sudo modprobe libcomposite
sudo modprobe dwc2

echo "Ensuring modules are loaded on boot..."
echo "libcomposite" | sudo tee -a /etc/modules
echo "dwc2" | sudo tee -a /etc/modules

echo "Configuring /boot/config.txt to enable dwc2 overlay..."
sudo sed -i '/^dtoverlay=dwc2/d' /boot/config.txt
echo "dtoverlay=dwc2" | sudo tee -a /boot/config.txt

echo "Setting up systemd services..."
sudo cp usb_gadget.service /etc/systemd/system/
sudo cp streaming.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable usb_gadget.service
sudo systemctl enable streaming.service

echo "Setup complete. Please reboot the system to apply changes."
