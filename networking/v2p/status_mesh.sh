#!/bin/bash
# Check mesh network status on all devices

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Mesh Network Status"
echo "========================================="
echo ""

# Check connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    exit 1
fi

echo "Connected Devices: $DEVICE_COUNT"
echo ""

# Function to check status on a device
check_device_status() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "--- Device $DEVICE_NUM ($DEVICE_SERIAL) ---"
    
    # Check if mesh process is running
    if adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node.sh" &>/dev/null; then
        echo "Status: ✓ Running"
        
        # Get process info
        PID=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node.sh" | tr -d '\r')
        echo "PID: $PID"
        
        # Show last few log lines
        echo "Recent logs:"
        adb -s "$DEVICE_SERIAL" shell "tail -n 5 $DEVICE_DIR/mesh.log 2>/dev/null" | sed 's/^/  /'
    else
        echo "Status: ✗ Not running"
    fi
    echo ""
}

# Check all devices
i=1
for device in $DEVICES; do
    check_device_status "$device" "$i"
    i=$((i+1))
done

echo "========================================="
echo ""
echo "To view full logs:"
echo "  adb -s <device_serial> shell cat $DEVICE_DIR/mesh.log"
echo ""
echo "To start mesh network:"
echo "  ./start_mesh.sh"
echo ""
