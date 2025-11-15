#!/bin/bash
# Stop mesh network on all connected Android devices

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Stopping Mesh Network on All Devices"
echo "========================================="
echo ""

# Check connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    exit 1
fi

echo "Found $DEVICE_COUNT connected device(s)"
echo ""

# Function to stop mesh on a device
stop_on_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Stopping mesh network on Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # Kill mesh_node.sh processes
    adb -s "$DEVICE_SERIAL" shell "pkill -f mesh_node.sh" 2>/dev/null
    
    sleep 1
    
    # Check if process stopped
    if adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node.sh" &>/dev/null; then
        echo "⚠️  Process still running on Device $DEVICE_NUM, forcing kill..."
        adb -s "$DEVICE_SERIAL" shell "pkill -9 -f mesh_node.sh" 2>/dev/null
    else
        echo "✓ Mesh network stopped on Device $DEVICE_NUM"
    fi
    echo ""
}

# Stop on all devices
i=1
for device in $DEVICES; do
    stop_on_device "$device" "$i"
    i=$((i+1))
done

echo "========================================="
echo "Mesh Network Stopped"
echo "========================================="
echo ""
