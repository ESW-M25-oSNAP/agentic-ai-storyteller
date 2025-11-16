#!/bin/bash
# Start LinUCB bid listeners on all connected Android devices
# Modified to use new LinUCB bidding system

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Starting LinUCB Bid Listeners on All Devices"
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

# Function to start bid listener on a device
start_on_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Starting LinUCB bid listener on Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # Check if netcat is available
    if ! adb -s "$DEVICE_SERIAL" shell "which nc" 2>/dev/null | grep -q "nc"; then
        echo "⚠️  Warning: netcat not found on Device $DEVICE_NUM"
        echo "   Please install: pkg install netcat-openbsd"
        return 1
    fi
    
    # Check if LinUCB solver exists
    if ! adb -s "$DEVICE_SERIAL" shell "test -f /data/local/tmp/lini && echo exists" | grep -q "exists"; then
        echo "⚠️  Warning: LinUCB solver not found on Device $DEVICE_NUM"
        echo "   Run: cd device_scripts && ./deploy_lini.sh"
        return 1
    fi
    
    # Kill any existing bid_listener and feedback_listener processes
    adb -s "$DEVICE_SERIAL" shell "pkill -f bid_listener.sh; pkill -f feedback_listener.sh" 2>/dev/null
    sleep 1
    
    # Start bid listener in background
    adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && sh bid_listener.sh > bid_listener.log 2>&1 &" &
    
    sleep 1
    
    # Start feedback listener in background
    adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && sh feedback_listener.sh > feedback_listener.log 2>&1 &" &
    
    sleep 1
    
    # Check if processes started
    BID_RUNNING=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f bid_listener.sh" 2>/dev/null)
    FEEDBACK_RUNNING=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f feedback_listener.sh" 2>/dev/null)
    
    if [ -n "$BID_RUNNING" ] && [ -n "$FEEDBACK_RUNNING" ]; then
        echo "✓ LinUCB bid & feedback listeners started on Device $DEVICE_NUM"
    elif [ -n "$BID_RUNNING" ]; then
        echo "⚠️  Bid listener started but feedback listener failed on Device $DEVICE_NUM"
    elif [ -n "$FEEDBACK_RUNNING" ]; then
        echo "⚠️  Feedback listener started but bid listener failed on Device $DEVICE_NUM"
    else
        echo "✗ Failed to start listeners on Device $DEVICE_NUM"
        echo "   Check logs: adb -s $DEVICE_SERIAL shell cat $DEVICE_DIR/bid_listener.log"
    fi
    echo ""
}

# Start on all devices
i=1
for device in $DEVICES; do
    start_on_device "$device" "$i"
    i=$((i+1))
done

echo "========================================="
echo "LinUCB Bid & Feedback Listeners Started"
echo "========================================="
echo ""
echo "To check status:"
echo "  adb shell ps -A | grep 'bid_listener\\|feedback_listener'"
echo ""
echo "To view logs on a device:"
echo "  adb -s <device_serial> shell cat $DEVICE_DIR/bid_listener.log"
echo "  adb -s <device_serial> shell cat $DEVICE_DIR/feedback_listener.log"
echo ""
echo "To trigger orchestrator:"
echo "  ./trigger_orchestrator.sh <DeviceA/B/C> \"<prompt>\""
echo ""
echo "To stop listeners:"
echo "  ./stop_mesh.sh"
echo ""
