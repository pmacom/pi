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

# Function to find the first active USB video device
find_usb_video_device() {
    for device in /dev/video*; do
        if [[ "$device" != "/dev/video0" ]] && [ -e "$device" ]; then
            # Detect video format and resolution for USB cameras
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

# Function to check for Raspberry Pi camera using libcamera
find_rpi_camera() {
    if libcamera-vid --list-cameras > /dev/null 2>&1; then
        echo "rpi-camera $DEFAULT_RESOLUTION h264"
        return 0
    fi
    return 1
}

# Function to run ffmpeg with the active USB video device
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

# Function to run libcamera-vid for Raspberry Pi camera
run_libcamera() {
    local resolution="$1"
    
    libcamera-vid \
        --framerate "$FRAMERATE" --width ${resolution%x*} --height ${resolution#*x} \
        --output - | ffmpeg \
        -f rawvideo -pix_fmt yuv420p -s "$resolution" -i - \
        -vf "hflip,format=rgb565le" \
        -pix_fmt rgb565le \
        -fflags nobuffer -flags low_delay -an \
        -f fbdev /dev/fb0
}

# Main loop to continuously check for active video devices and run appropriate video capture when available
while true; do
    # First check for USB video devices
    device_info=$(find_usb_video_device)
    
    if [ -n "$device_info" ]; then
        # If USB device is found, use ffmpeg to stream it
        device=$(echo $device_info | awk '{print $1}')
        resolution=$(echo $device_info | awk '{print $2}')
        format=$(echo $device_info | awk '{print $3}')
        
        echo "Active USB video device found: $device with resolution $resolution and format $format"
        run_ffmpeg "$device" "$resolution" "$format"
    else
        # If no USB device is found, check for Raspberry Pi camera
        rpi_camera_info=$(find_rpi_camera)
        
        if [ -n "$rpi_camera_info" ]; then
            # If Raspberry Pi camera is found, use libcamera to stream it
            resolution=$(echo $rpi_camera_info | awk '{print $2}')
            echo "Raspberry Pi camera detected with resolution $resolution"
            run_libcamera "$resolution"
        else
            show_message
        fi
    fi
    
    echo "No video device detected. Checking again..."
    sleep 2
done
