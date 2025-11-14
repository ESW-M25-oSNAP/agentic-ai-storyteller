#!/bin/bash
# Force cleanup all mesh processes and network ports
# Use this if you get "Address already in use" errors

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Force Cleanup Mesh Network"
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

for device in $DEVICES; do
    echo "Cleaning up device $device..."
    
    # Kill all mesh_node processes
    adb -s "$device" shell "pkill -9 -f mesh_node.sh" 2>/dev/null
    
    # Kill all nc processes on port 5000
    adb -s "$device" shell "pkill -9 nc" 2>/dev/null
    
    # Kill any tail processes monitoring logs
    adb -s "$device" shell "pkill -9 -f 'tail -f'" 2>/dev/null
    
    # Clear all flag files
    adb -s "$device" shell "rm -f $DEVICE_DIR/*.flag $DEVICE_DIR/*.pid $DEVICE_DIR/bid_mode_start $DEVICE_DIR/chosen_device.txt" 2>/dev/null
    
    echo "✓ Cleaned up device $device"
    sleep 0.5
done

echo ""
echo "========================================="
echo "Force Cleanup Complete"
echo "========================================="
echo ""
echo "You can now start the mesh network:"
echo "  ./start_mesh.sh"
echo ""
