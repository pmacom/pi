#!/bin/bash
# streaming.sh - Script to start video streaming with verbose logging

LOG_FILE="/var/log/streaming.log"
> "$LOG_FILE" # Clear the previous log

log() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting streaming service..."

# Wait for /dev/video2 to become available
RETRY=5
while [ ! -e /dev/video2 ] && [ $RETRY -gt 0 ]; do
  log "Waiting for /dev/video2..."
  sleep 2
  RETRY=$((RETRY-1))
done

if [ ! -e /dev/video2 ]; then
  log "/dev/video2 not found after retries. Exiting."
  exit 1
fi

log "/dev/video2 is available. Starting ffmpeg test video stream..."
ffmpeg -re -f lavfi -i testsrc=size=640x480:rate=30 -vf format=yuv420p -f v4l2 /dev/video2 &

# Capture the ffmpeg process ID to manage it later
FFMPEG_PID=$!

# Allow time for the stream to initialize
sleep 2

# Load v4l2loopback module if not already loaded
if ! lsmod | grep -q v4l2loopback; then
  log "Loading v4l2loopback module..."
  modprobe v4l2loopback video_nr=2 exclusive_caps=1
fi

# Verify /dev/video2 is a valid capture device
if ! v4l2-ctl --list-devices | grep -q "/dev/video2"; then
  log "/dev/video2 is not a valid capture device. Exiting."
  kill $FFMPEG_PID
  exit 1
fi

# Test if v4l2src can initialize (use fakesink to discard output)
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,format=YUY2,width=640,height=480 ! videoconvert ! fakesink 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  log "GStreamer fakesink test failed. Exiting."
  kill $FFMPEG_PID
  exit 1
fi

# If fakesink test passes, continue with main GStreamer pipeline
log "fakesink test passed. Launching main GStreamer pipeline..."
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,format=YUY2,width=640,height=480 ! videoconvert ! v4l2sink device=/dev/video0 2>&1 | tee -a "$LOG_FILE"

# Kill the ffmpeg process when done
kill $FFMPEG_PID
log "Stopped ffmpeg test stream."
