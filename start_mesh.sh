#!/bin/bash
# Start mesh network on all connected Android devices
# Uses ADB to execute mesh_node.py on each device

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Starting Mesh Network on All Devices"
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

# Function to start mesh on a device
start_on_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Starting mesh network on Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # Check if netcat is available
    if ! adb -s "$DEVICE_SERIAL" shell "which nc" 2>/dev/null | grep -q "nc"; then
        echo "⚠️  Warning: netcat not found on Device $DEVICE_NUM"
        echo "   Please install: pkg install netcat-openbsd"
        return 1
    fi
    
    # Kill any existing mesh_node processes
    adb -s "$DEVICE_SERIAL" shell "pkill -f mesh_node.sh" 2>/dev/null
    sleep 1
    
    # Start mesh node in background (use sh which is always available)
    # Run in background without waiting for output
    adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && sh mesh_node.sh > mesh.log 2>&1 &" &
    
    sleep 1
    
    sleep 2
    
    # Check if process started
    if adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node.sh" &>/dev/null; then
        echo "✓ Mesh network started on Device $DEVICE_NUM"
    else
        echo "✗ Failed to start mesh network on Device $DEVICE_NUM"
        echo "   Check logs: adb -s $DEVICE_SERIAL shell cat $DEVICE_DIR/mesh.log"
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
echo "Mesh Network Startup Complete"
echo "========================================="
echo ""
echo "To check status:"
echo "  ./status_mesh.sh"
echo ""
echo "To view logs on a device:"
echo "  adb -s <device_serial> shell cat $DEVICE_DIR/mesh.log"
echo ""
echo "To stop mesh network:"
echo "  ./stop_mesh.sh"
echo ""
