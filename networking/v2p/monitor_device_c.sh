#!/bin/bash
# Monitor DeviceC logs in real-time

DEVICE_SERIAL="RZCT90P1WAK"
DEVICE_NAME="DeviceC"
LOG_FILE="/sdcard/mesh_network/mesh.log"

echo "========================================="
echo "Monitoring $DEVICE_NAME Logs (Live)"
echo "========================================="
echo ""

# Check if device is connected
if ! adb devices | grep -q "$DEVICE_SERIAL"; then
    echo "Error: $DEVICE_NAME ($DEVICE_SERIAL) is not connected"
    exit 1
fi

echo "Press Ctrl+C to stop monitoring"
echo ""
echo "----------------------------------------"

# Tail the log file and prefix each line with [DeviceC]
adb -s "$DEVICE_SERIAL" shell "tail -f $LOG_FILE 2>/dev/null" | while IFS= read -r line; do
    echo "[$DEVICE_NAME] $line"
done
