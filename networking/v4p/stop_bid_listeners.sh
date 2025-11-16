#!/bin/bash
# Stop bid listeners on all connected Android devices

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Stopping Bid Listeners on All Devices"
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

# Stop listener on each device
for device in $DEVICES; do
    DEVICE_NAME=$(adb -s "$device" shell "cat $DEVICE_DIR/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="$device"
    fi
    
    echo "Stopping bid listener on $DEVICE_NAME ($device)..."
    
    # Kill bid listener processes
    adb -s "$device" shell "pkill -9 -f bid_listener.sh" 2>/dev/null
    
    sleep 1
    
    # Check if process stopped
    if adb -s "$device" shell "pgrep -f bid_listener.sh" &>/dev/null; then
        echo "⚠️  Warning: Process still running on $DEVICE_NAME"
    else
        echo "✓ Bid listener stopped on $DEVICE_NAME"
    fi
    echo ""
done

echo "========================================="
echo "Bid Listeners Stopped"
echo "========================================="
echo ""
