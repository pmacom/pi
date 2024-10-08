#!/bin/bash
# streaming.sh - Script to start video streaming with verbose logging

LOG_FILE="/var/log/streaming.log"
> "$LOG_FILE" # Clear the previous log

echo "$(date): Starting streaming service..." | tee -a "$LOG_FILE"

# Wait for /dev/video2 to become available
RETRY=5
while [ ! -e /dev/video2 ] && [ $RETRY -gt 0 ]; do
  echo "$(date): Waiting for /dev/video2..." | tee -a "$LOG_FILE"
  sleep 2
  RETRY=$((RETRY-1))
done

if [ ! -e /dev/video2 ]; then
  echo "$(date): /dev/video2 not found after retries. Exiting." | tee -a "$LOG_FILE"
  exit 1
fi

echo "$(date): /dev/video2 is available. Starting GStreamer pipeline..." | tee -a "$LOG_FILE"

# Load v4l2loopback module if not already loaded
if ! lsmod | grep -q v4l2loopback; then
  echo "$(date): Loading v4l2loopback module..." | tee -a "$LOG_FILE"
  modprobe v4l2loopback video_nr=2 exclusive_caps=1
fi

# Test if v4l2src can initialize (use fakesink to discard output)
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,width=640,height=480 ! videoconvert ! fakesink 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "$(date): GStreamer fakesink test failed. Exiting." | tee -a "$LOG_FILE"
  exit 1
fi

# If fakesink test passes, continue with v4l2sink
echo "$(date): fakesink test passed. Launching main GStreamer pipeline..." | tee -a "$LOG_FILE"
gst-launch-1.0 -v v4l2src device=/dev/video2 ! video/x-raw,width=640,height=480 ! videoconvert ! v4l2sink device=/dev/video0 2>&1 | tee -a "$LOG_FILE"
