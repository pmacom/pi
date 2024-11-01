#!/bin/bash

# streaming.sh
# Streams video from the Raspberry Pi camera to the UVC gadget

set -e

echo "Starting video stream from Pi camera to UVC gadget..."

# Ensure the camera module is loaded
sudo modprobe bcm2835-v4l2

# Start uvc-gadget with specified resolution and frame rate
uvc-gadget -f -s 1024x600 -r 30 -d /dev/video0

echo "Video streaming started."
