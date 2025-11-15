#!/bin/bash
# Quick deploy mesh_node.sh to all devices without stopping mesh
# Useful for testing updates

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Quick Deploy mesh_node.sh to All Devices"
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

# Deploy to all devices
i=1
for device in $DEVICES; do
    echo "Deploying to Device $i ($device)..."
    adb -s "$device" push mesh_node.sh "$DEVICE_DIR/mesh_node.sh"
    adb -s "$device" shell "chmod +x $DEVICE_DIR/mesh_node.sh"
    echo "✓ Deployed to Device $i"
    echo ""
    i=$((i+1))
done

echo "========================================="
echo "Deployment Complete"
echo "========================================="
echo ""
echo "To apply changes:"
echo "  ./stop_mesh.sh"
echo "  ./start_mesh.sh"
echo ""
