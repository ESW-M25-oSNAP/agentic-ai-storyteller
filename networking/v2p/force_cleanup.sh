#!/bin/bash
# Force cleanup of all mesh network processes

echo "========================================="
echo "Force Cleanup of Mesh Network"
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

# Function to force cleanup on a device
cleanup_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Cleaning up Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # Kill all nc (netcat) processes
    echo "  Killing netcat processes..."
    adb -s "$DEVICE_SERIAL" shell "pkill -9 nc" 2>/dev/null
    
    # Kill all mesh_node.sh processes
    echo "  Killing mesh_node.sh processes..."
    adb -s "$DEVICE_SERIAL" shell "pkill -9 -f mesh_node.sh" 2>/dev/null
    
    # Kill any sh processes running from mesh directory
    echo "  Killing related shell processes..."
    adb -s "$DEVICE_SERIAL" shell "pkill -9 -f '/sdcard/mesh_network'" 2>/dev/null
    
    sleep 1
    
    # Verify cleanup
    NC_COUNT=$(adb -s "$DEVICE_SERIAL" shell "pgrep nc" 2>/dev/null | wc -l)
    MESH_COUNT=$(adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node" 2>/dev/null | wc -l)
    
    if [ "$NC_COUNT" -eq 0 ] && [ "$MESH_COUNT" -eq 0 ]; then
        echo "✓ Device $DEVICE_NUM cleaned successfully"
    else
        echo "⚠️  Warning: Some processes may still be running on Device $DEVICE_NUM"
        echo "   Netcat processes: $NC_COUNT"
        echo "   Mesh processes: $MESH_COUNT"
    fi
    echo ""
}

# Clean up all devices
i=1
for device in $DEVICES; do
    cleanup_device "$device" "$i"
    i=$((i+1))
done

echo "========================================="
echo "Cleanup Complete"
echo "========================================="
echo ""
echo "You can now restart the mesh network with:"
echo "  ./start_mesh.sh"
echo ""
