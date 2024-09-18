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

# Function to find the first active video device and determine its format and resolution
find_video_device() {
    for device in /dev/video*; do
        if [ -e "$device" ]; then
            # Detect video format and resolution
            resolution=$(v4l2-ctl --list-formats-ext -d "$device" | grep -m 1 'Size: Discrete' | awk '{print $3}')
            format=$(v4l2-ctl --list-formats-ext -d "$device" | grep -m 1 'Pixel Format' | awk '{print $3}')
            
            # Set default values if not detected
            if [ -z "$resolution" ]; then
                resolution=$DEFAULT_RESOLUTION
            fi
            
            if [ -z "$format" ]; then
                format="mjpeg"  # Default to MJPEG if format not detected
            fi
            
            echo "$device $resolution $format"
            return 0
        fi
    done
    return 1
}

# Function to run ffmpeg with the active video device
run_ffmpeg() {
    local device="$1"
    local resolution="$2"
    local format="$3"
    
    ffmpeg \
        -f v4l2 -input_format "$format" -thread_queue_size "$THREAD_QUEUE_SIZE" -framerate "$FRAMERATE" -video_size "$resolution" -use_wallclock_as_timestamps 1 -vsync 0 -i "$device" \
        -vf "hflip,format=rgb565le" \
        -pix_fmt rgb565le \
        -fflags nobuffer -flags low_delay -an \
        -f fbdev /dev/fb0
}

# Main loop to continuously check for active video devices and run ffmpeg when available
while true; do
    device_info=$(find_video_device)
    if [ -n "$device_info" ]; then
        device=$(echo $device_info | awk '{print $1}')
        resolution=$(echo $device_info | awk '{print $2}')
        format=$(echo $device_info | awk '{print $3}')
        
        echo "Active video device found: $device with resolution $resolution and format $format"
        
        # Run ffmpeg and wait for it to finish (i.e., the device is disconnected)
        run_ffmpeg "$device" "$resolution" "$format"
        
        echo "Device $device disconnected. Restarting detection..."
        sleep 2  # Give some time before re-detecting devices
    else
        show_message
    fi
    
    sleep 1  # Short delay before checking again
done
