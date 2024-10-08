#!/bin/bash
# init2.sh - Setup script to configure Raspberry Pi Zero as a USB webcam

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./init2.sh"
  exit
fi

echo "Starting setup..."

# Update the package list and upgrade existing packages
apt update && apt -y upgrade

# Install necessary packages
apt install -y \
  gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  v4l2loopback-dkms \
  linux-modules-extra-raspi

# Load v4l2loopback module with specific options
modprobe v4l2loopback video_nr=2

# Ensure v4l2loopback loads on boot
echo "v4l2loopback" >> /etc/modules

# Modify /boot/firmware/config.txt
CONFIG_FILE="/boot/firmware/config.txt"
if ! grep -q "^dtoverlay=dwc2,dr_mode=peripheral" "$CONFIG_FILE"; then
  echo "Configuring $CONFIG_FILE..."
  echo "dtoverlay=dwc2,dr_mode=peripheral" >> "$CONFIG_FILE"
fi

# Modify /boot/firmware/cmdline.txt
CMDLINE_FILE="/boot/firmware/cmdline.txt"
if ! grep -q "modules-load=dwc2" "$CMDLINE_FILE"; then
  echo "Configuring $CMDLINE_FILE..."
  sed -i 's/\(rootwait\)/\1 modules-load=dwc2/' "$CMDLINE_FILE"
fi

# Ensure dwc2 and libcomposite modules load on boot
echo -e "dwc2\nlibcomposite" >> /etc/modules

# Mount configfs if not already mounted
if ! mountpoint -q /sys/kernel/config; then
  echo "Mounting configfs..."
  mount -t configfs none /sys/kernel/config
  echo "none /sys/kernel/config configfs defaults 0 0" >> /etc/fstab
fi

# Create usb_gadget_setup.sh script
GADGET_SCRIPT="/usr/bin/usb_gadget_setup.sh"
echo "Creating $GADGET_SCRIPT..."
cat << 'EOF' > "$GADGET_SCRIPT"
#!/bin/bash
# usb_gadget_setup.sh - Script to configure USB gadget

# Unbind and remove existing gadget if it exists
if [ -d /sys/kernel/config/usb_gadget/uvc_gadget ]; then
  echo "Cleaning up existing gadget configuration..."
  # Unbind the gadget
  if [ -e /sys/kernel/config/usb_gadget/uvc_gadget/UDC ]; then
    echo "" > /sys/kernel/config/usb_gadget/uvc_gadget/UDC
  fi
  # Unlink functions from configurations
  for function in /sys/kernel/config/usb_gadget/uvc_gadget/configs/*/uvc.usb*; do
    if [ -L "$function" ]; then
      rm "$function"
    fi
  done
  # Remove the gadget directory
  rm -rf /sys/kernel/config/usb_gadget/uvc_gadget
fi

# Load necessary modules
modprobe libcomposite

# Set up gadget directory
GADGET_DIR=/sys/kernel/config/usb_gadget/uvc_gadget
mkdir -p $GADGET_DIR
cd $GADGET_DIR

# Set Vendor and Product IDs
echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

# Set device attributes
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Create English locale strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Raspberry Pi Foundation" > strings/0x409/manufacturer
echo "Pi Zero USB Camera" > strings/0x409/product

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "UVC" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower

# Create UVC function
mkdir -p functions/uvc.usb0
# Configure UVC function (adjust as needed)
echo 0 > functions/uvc.usb0/streaming_maxpacket
echo 1 > functions/uvc.usb0/streaming_maxburst
mkdir -p functions/uvc.usb0/control/header/h
mkdir -p functions/uvc.usb0/control/class/fs
mkdir -p functions/uvc.usb0/control/class/ss
ln -s functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/fs/h
ln -s functions/uvc.usb0/control/header/h functions/uvc.usb0/control/class/ss/h

# Configure streaming interface
mkdir -p functions/uvc.usb0/streaming/uncompressed/u/1
echo 640 > functions/uvc.usb0/streaming/uncompressed/u/1/wWidth
echo 480 > functions/uvc.usb0/streaming/uncompressed/u/1/wHeight
echo 333333 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMinBitRate
echo 1843200 > functions/uvc.usb0/streaming/uncompressed/u/1/dwMaxVideoFrameBufferSize
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwDefaultFrameInterval
echo 1 > functions/uvc.usb0/streaming/uncompressed/u/1/bFrameIntervalType
echo 10000000 > functions/uvc.usb0/streaming/uncompressed/u/1/dwFrameInterval.1
mkdir -p functions/uvc.usb0/streaming/header/h
mkdir -p functions/uvc.usb0/streaming/class/fs
mkdir -p functions/uvc.usb0/streaming/class/hs
ln -s functions/uvc.usb0/streaming/uncompressed/u functions/uvc.usb0/streaming/header/h
ln -s functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/fs/h
ln -s functions/uvc.usb0/streaming/header/h functions/uvc.usb0/streaming/class/hs/h

# Link function to configuration
ln -s functions/uvc.usb0 configs/c.1/

# Bind the gadget
UDC_DEVICE=$(ls /sys/class/udc | head -n 1)
echo "$UDC_DEVICE" > UDC
EOF

# Make the gadget setup script executable
chmod +x "$GADGET_SCRIPT"

# Create usb_gadget.service
SERVICE_FILE="/etc/systemd/system/usb_gadget.service"
echo "Creating $SERVICE_FILE..."
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=USB Gadget Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/usb_gadget_setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable the service
systemctl daemon-reload
systemctl enable usb_gadget.service

# Create streaming.service
STREAMING_SERVICE="/etc/systemd/system/streaming.service"
echo "Creating $STREAMING_SERVICE..."
cat << EOF > "$STREAMING_SERVICE"
[Unit]
Description=Camera Streaming Service
After=usb_gadget.service

[Service]
Type=simple
ExecStart=/usr/bin/streaming.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create streaming.sh script
STREAMING_SCRIPT="/usr/bin/streaming.sh"
echo "Creating $STREAMING_SCRIPT..."
cat << 'EOF' > "$STREAMING_SCRIPT"
#!/bin/bash
# streaming.sh - Script to start video streaming

# Load v4l2loopback module if not already loaded
if ! lsmod | grep -q v4l2loopback; then
  modprobe v4l2loopback video_nr=2
fi

# Start GStreamer pipeline (adjust as needed)
gst-launch-1.0 v4l2src ! video/x-raw,width=640,height=480 ! videoconvert ! v4l2sink device=/dev/video2
EOF

# Make the streaming script executable
chmod +x "$STREAMING_SCRIPT"

# Enable the streaming service
systemctl enable streaming.service

# Adjust AppArmor settings if necessary (for Ubuntu)
if command -v aa-status &> /dev/null; then
  echo "Adjusting AppArmor settings..."
  aa-complain /sys/kernel/config/**
fi

echo "Setup complete. Please reboot the system for changes to take effect."

