#!/bin/bash
# streaming.sh - Script to start video streaming

# Define the source and sink devices explicitly
VIDEO_SOURCE="/dev/video0"
VIDEO_SINK="/dev/video2"

# Check if the source device exists
if [ ! -e "$VIDEO_SOURCE" ]; then
  echo "Source device $VIDEO_SOURCE not found."
  exit 1
fi

# Check if the sink device exists
if [ ! -e "$VIDEO_SINK" ]; then
  echo "Sink device $VIDEO_SINK not found."
  exit 1
fi

echo "Feeding video from $VIDEO_SOURCE to $VIDEO_SINK"

# Start GStreamer pipeline
gst-launch-1.0 -v \
  v4l2src device="$VIDEO_SOURCE" ! \
  video/x-raw,width=640,height=480,framerate=30/1 ! \
  videoconvert ! \
  video/x-raw,format=YUY2 ! \
  v4l2sink device="$VIDEO_SINK"
  