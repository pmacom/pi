#!/bin/bash
# Shell script to install GStreamer packages

# Update the package list
sudo apt update

# Install the necessary GStreamer packages
sudo apt install -y gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good v4l2loopback-dkms

sudo modprobe v4l2loopback video_nr=2