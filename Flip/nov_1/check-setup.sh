#!/bin/bash
# check_setup.sh - Validation script to confirm USB webcam setup on Raspberry Pi Zero

echo "Starting validation checks..."

# Check if v4l2loopback is loaded
#if lsmod | grep -q v4l2loopback; then
#  echo "✅ v4l2loopback module is loaded"
#else
#  echo "❌ v4l2loopback module is not loaded"
#fi

# Check if dwc2 and libcomposite are loaded
if lsmod | grep -q dwc2 && lsmod | grep -q libcomposite; then
  echo "✅ dwc2 and libcomposite modules are loaded"
else
  echo "❌ dwc2 and/or libcomposite module is not loaded"
fi

# Check /boot/config.txt for USB gadget overlay
if grep -q "^dtoverlay=dwc2,dr_mode=peripheral" /boot/config.txt; then
  echo "✅ USB gadget overlay is set in /boot/config.txt"
else
  echo "❌ USB gadget overlay is missing in /boot/config.txt"
fi

# Check if configfs is mounted
if mountpoint -q /sys/kernel/config; then
  echo "✅ configfs is mounted"
else
  echo "❌ configfs is not mounted"
fi

# Check if USB gadget directory exists
if [ -d /sys/kernel/config/usb_gadget/uvc_gadget ]; then
  echo "✅ USB gadget is configured"
else
  echo "❌ USB gadget is not configured"
fi

# Check if usb_gadget.service is active
if systemctl is-active --quiet usb_gadget.service; then
  echo "✅ usb_gadget.service is active"
else
  echo "❌ usb_gadget.service is not active"
  echo "Displaying usb_gadget.service logs:"
  journalctl -u usb_gadget.service --no-pager | tail -n 10
fi

# Check if streaming.service is active
if systemctl is-active --quiet streaming.service; then
  echo "✅ streaming.service is active"
else
  echo "❌ streaming.service is not active"
  echo "Displaying streaming.service logs:"
  journalctl -u streaming.service --no-pager | tail -n 10
fi

# Check if /dev/video2 is available
if [ -e /dev/video2 ]; then
  echo "✅ /dev/video2 device is available"
else
  echo "❌ /dev/video2 device is not available"
fi

# Final summary
echo ""
echo "Validation checks complete."
echo "Please review the output above to verify that all settings are correctly configured."
