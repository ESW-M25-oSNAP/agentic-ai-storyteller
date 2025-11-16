#!/bin/bash
# Deploy orchestrator scripts to Android devices
# Deploys: collect_metrics.sh, bid_listener.sh, orchestrator.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Deploying Orchestrator Scripts"
echo "========================================="
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "Error: ADB not found"
    exit 1
fi

# Check connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    exit 1
fi

echo "Found $DEVICE_COUNT connected device(s)"
echo ""

# Check if device_scripts directory exists
if [ ! -d "$SCRIPT_DIR/device_scripts" ]; then
    echo "Error: device_scripts directory not found"
    exit 1
fi

# Deploy to each device
for device in $DEVICES; do
    DEVICE_NAME=$(adb -s "$device" shell "cat $DEVICE_DIR/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="$device"
    fi
    
    echo "Deploying to $DEVICE_NAME ($device)..."
    
    # Push scripts
    adb -s "$device" push "$SCRIPT_DIR/device_scripts/collect_metrics.sh" "$DEVICE_DIR/collect_metrics.sh" 2>&1 | grep -v "bytes"
    adb -s "$device" shell "chmod +x $DEVICE_DIR/collect_metrics.sh"
    
    adb -s "$device" push "$SCRIPT_DIR/device_scripts/bid_listener.sh" "$DEVICE_DIR/bid_listener.sh" 2>&1 | grep -v "bytes"
    adb -s "$device" shell "chmod +x $DEVICE_DIR/bid_listener.sh"
    
    adb -s "$device" push "$SCRIPT_DIR/device_scripts/orchestrator.sh" "$DEVICE_DIR/orchestrator.sh" 2>&1 | grep -v "bytes"
    adb -s "$device" shell "chmod +x $DEVICE_DIR/orchestrator.sh"
    
    echo "✓ Deployed to $DEVICE_NAME"
    echo ""
done

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Start bid listeners on all devices:"
echo "   ./start_bid_listeners.sh"
echo ""
echo "2. Trigger orchestrator on a device:"
echo "   ./trigger_orchestrator.sh DeviceA"
echo ""
