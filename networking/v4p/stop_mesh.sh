#!/bin/bash
# Stop LinUCB bid listeners on all connected Android devices

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Stopping LinUCB Listeners on All Devices"
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

# Function to stop bid listener and feedback listener on a device
stop_on_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Stopping LinUCB listeners on Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # Kill bid_listener.sh and feedback_listener.sh processes
    adb -s "$DEVICE_SERIAL" shell "pkill -f bid_listener.sh; pkill -f feedback_listener.sh" 2>/dev/null
    
    # Also kill old mesh_node.sh if it's running
    adb -s "$DEVICE_SERIAL" shell "pkill -f mesh_node.sh" 2>/dev/null
    
    sleep 1
    
    # Check if processes stopped
    BID_RUNNING=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f bid_listener.sh" 2>/dev/null)
    FEEDBACK_RUNNING=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f feedback_listener.sh" 2>/dev/null)
    
    if [ -n "$BID_RUNNING" ] || [ -n "$FEEDBACK_RUNNING" ]; then
        echo "⚠️  Process still running on Device $DEVICE_NUM, forcing kill..."
        adb -s "$DEVICE_SERIAL" shell "pkill -9 -f bid_listener.sh; pkill -9 -f feedback_listener.sh" 2>/dev/null
    else
        echo "✓ LinUCB listeners stopped on Device $DEVICE_NUM"
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
echo "LinUCB Listeners Stopped"
echo "========================================="
echo ""
