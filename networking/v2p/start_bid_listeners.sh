#!/bin/bash
# Start bid listeners on all connected Android devices

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Starting Bid Listeners on All Devices"
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

# Start listener on each device
for device in $DEVICES; do
    DEVICE_NAME=$(adb -s "$device" shell "cat $DEVICE_DIR/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="$device"
    fi
    
    echo "Starting bid listener on $DEVICE_NAME ($device)..."
    
    # Kill any existing bid listeners
    adb -s "$device" shell "pkill -f bid_listener.sh" 2>/dev/null
    sleep 1
    
    # Start bid listener in background
    adb -s "$device" shell "cd $DEVICE_DIR && sh bid_listener.sh > bid_listener.log 2>&1 &" &
    
    sleep 2
    
    # Check if process started
    if adb -s "$device" shell "pgrep -f bid_listener.sh" &>/dev/null; then
        echo "✓ Bid listener started on $DEVICE_NAME"
    else
        echo "✗ Failed to start bid listener on $DEVICE_NAME"
    fi
    echo ""
done

echo "========================================="
echo "Bid Listeners Started"
echo "========================================="
echo ""
echo "To check status:"
echo "  adb shell ps -A | grep bid_listener"
echo ""
echo "To view logs on a device:"
echo "  adb -s <device_serial> shell cat $DEVICE_DIR/bid_listener.log"
echo ""
echo "To stop bid listeners:"
echo "  ./stop_bid_listeners.sh"
echo ""
