#!/bin/bash
# Dynamic script to capture video from any available video device, adjust to different devices, and handle disconnection/reconnection

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

run_libcamera() {
  local resolution="$1"

  # Adjust the timeout to prevent premature halting
  libcamera-vid \
    --framerate "$FRAMERATE" -=width ${resolution%x*} --height ${resolution#*x} --codec mjpeg \
    --timeout 0 --output - | ffmpeg \
    -f mjpeg -i - \
    -vf "hflip,format=rgb565le" \
    -pix_fmt rgb565le \
    -fflags nobuffer -flags low_delay -an \
    -f fbdev /dev/fb0
}

run_libcamera "$DEFAULT_RESOLUTION"
