#!/bin/bash
# streaming.sh - Script to start video streaming with verbose logging

LOG_FILE="/var/log/streaming.log"
> "$LOG_FILE" # Clear the previous log

log() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting streaming service..."

# Check if the device exists and has the correct permissions
log "Checking if /dev/video2 exists..."
if [ ! -e "/dev/video2" ]; then
  log "/dev/video2 does not exist. Exiting."
  exit 1
fi

log "Checking permissions for /dev/video2..."
if [ ! -r "/dev/video2" ] || [ ! -w "/dev/video2" ]; then
  log "Insufficient permissions for /dev/video2. Exiting."
  exit 1
fi

# Wait for /dev/video2 to become available
log "Waiting for /dev/video2 to become available..."
RETRY=5
while [ ! -e "/dev/video2" ] && [ $RETRY -gt 0 ]; do
  log "Retrying... ($RETRY attempts left)"
  sleep 2
  RETRY=$((RETRY-1))
done

# Remove the redundant check for /dev/video2
log "/dev/video2 is available. Starting ffmpeg test video stream..."
ffmpeg -re -f lavfi -i "testsrc=size=1024x768:rate=30" -vf "format=yuv420p" -f v4l2 "/dev/video2" &
log "ffmpeg test video stream started."

# Capture the ffmpeg process ID to manage it later
FFMPEG_PID=$!
log "Captured ffmpeg process ID: $FFMPEG_PID"

# Allow time for the stream to initialize
log "Allowing time for the stream to initialize..."
sleep 2

# Load v4l2loopback module if not already loaded
log "Checking if v4l2loopback module is loaded..."
if ! lsmod | grep -q "v4l2loopback"; then
  log "Loading v4l2loopback module..."
  modprobe v4l2loopback video_nr=2 exclusive_caps=1
  log "v4l2loopback module loaded."
else
  log "v4l2loopback module is already loaded."
fi

# Verify /dev/video2 is a valid capture device
log "Verifying /dev/video2 is a valid capture device..."
if ! v4l2-ctl --list-devices | grep -q "/dev/video2"; then
  log "/dev/video2 is not a valid capture device. Exiting."
  kill $FFMPEG_PID
  log "Killed ffmpeg process with ID: $FFMPEG_PID"
  exit 1
fi
log "/dev/video2 is a valid capture device."

# Test if v4l2src can initialize (use fakesink to discard output)
log "Testing if v4l2src can initialize with fakesink..."
gst-launch-1.0 -v v4l2src device="/dev/video2" ! "video/x-raw,format=YUY2,width=1024,height=768" ! videoconvert ! fakesink 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  log "GStreamer fakesink test failed. Exiting."
  kill $FFMPEG_PID
  log "Killed ffmpeg process with ID: $FFMPEG_PID"
  exit 1
fi
log "GStreamer fakesink test passed."

# If fakesink test passes, continue with main GStreamer pipeline
log "Launching main GStreamer pipeline..."
gst-launch-1.0 -v v4l2src device="/dev/video2" ! "video/x-raw,format=YUY2,width=1024,height=768" ! videoconvert ! v4l2sink device="/dev/video0" 2>&1 | tee -a "$LOG_FILE"

# Kill the ffmpeg process when done
log "Stopping ffmpeg test stream..."
kill $FFMPEG_PID
log "Stopped ffmpeg test stream."
