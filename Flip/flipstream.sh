#!/bin/bash
# Script to capture video from Raspberry Pi camera and stream as UVC

# Configurable options
FRAMERATE=30                # Target framerate for capture and display
DEFAULT_RESOLUTION="1024x600" # Default resolution
THREAD_QUEUE_SIZE=2048      # Increased thread queue size for buffering

# Function to display a message when no video device is found
show_message() {
    clear
    echo "No active video device found. Please connect a video device."
    sleep 2
}

# Function to run GStreamer pipeline for UVC streaming
run_gstreamer() {
  local resolution="$1"
  local width=${resolution%x*}
  local height=${resolution#*x}

  # GStreamer pipeline to capture from libcamera and output as UVC
  gst-launch-1.0 -e \
    libcamera-vid --framerate "$FRAMERATE" --width "$width" --height "$height" --codec mjpeg --output - \
    ! v4l2sink device=/dev/video1 # Change /dev/video1 to your UVC device if needed
}

# Check if the required video device is available
if ! v4l2-ctl --list-devices | grep -q "video"; then
    show_message
    exit 1
fi

run_gstreamer "$DEFAULT_RESOLUTION"
