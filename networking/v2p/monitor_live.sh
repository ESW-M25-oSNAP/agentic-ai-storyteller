#!/bin/bash
# Monitor messages from all devices in real-time

echo "========================================="
echo "Monitoring Mesh Network Messages"
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Get device serials
DEVICE_A="60e0c72f"
DEVICE_B="9688d142"
DEVICE_C="RZCT90P1WAK"

# Function to colorize output
colorize() {
    local device=$1
    case $device in
        A) echo -e "\033[0;32m";;  # Green
        B) echo -e "\033[0;34m";;  # Blue
        C) echo -e "\033[0;35m";;  # Magenta
    esac
}

reset_color() {
    echo -e "\033[0m"
}

# Monitor all devices with color coding
(adb -s "$DEVICE_A" shell "tail -f /sdcard/mesh_network/mesh.log" | while read line; do
    echo "$(colorize A)[DeviceA]$(reset_color) $line"
done) &

(adb -s "$DEVICE_B" shell "tail -f /sdcard/mesh_network/mesh.log" | while read line; do
    echo "$(colorize B)[DeviceB]$(reset_color) $line"
done) &

(adb -s "$DEVICE_C" shell "tail -f /sdcard/mesh_network/mesh.log" | while read line; do
    echo "$(colorize C)[DeviceC]$(reset_color) $line"
done) &

# Wait for Ctrl+C
wait
