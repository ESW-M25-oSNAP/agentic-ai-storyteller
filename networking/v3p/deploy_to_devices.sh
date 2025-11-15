#!/bin/bash
# Deploy mesh network scripts to Android devices via ADB
# Requires: adb installed and devices connected

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Deploying Mesh Network to Devices"
echo "========================================="
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "Error: ADB not found. Please install Android Debug Bridge."
    exit 1
fi

# Check connected devices
echo "Checking connected devices..."
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    echo "Please connect your Android devices and enable USB debugging"
    exit 1
fi

echo "Found $DEVICE_COUNT connected device(s)"
echo ""

# Check if config files exist
if [ ! -f "$SCRIPT_DIR/device_a_config.json" ] || \
   [ ! -f "$SCRIPT_DIR/device_b_config.json" ] || \
   [ ! -f "$SCRIPT_DIR/device_c_config.json" ]; then
    echo "Error: Device config files not found"
    echo "Please run ./setup_configs.sh first to generate configuration files"
    exit 1
fi

# Function to deploy to a specific device
deploy_to_device() {
    local DEVICE_SERIAL=$1
    local CONFIG_FILE=$2
    local DEVICE_NAME=$3
    
    echo "Deploying to $DEVICE_NAME ($DEVICE_SERIAL)..."
    
    # Create directory on device
    adb -s "$DEVICE_SERIAL" shell "mkdir -p $DEVICE_DIR" 2>/dev/null
    
    # Push LinUCB bid_listener.sh, orchestrator.sh, and feedback_listener.sh (NEW)
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/device_scripts/bid_listener.sh" "$DEVICE_DIR/bid_listener.sh"
    adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/bid_listener.sh"
    
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/device_scripts/orchestrator.sh" "$DEVICE_DIR/orchestrator.sh"
    adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/orchestrator.sh"
    
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/device_scripts/feedback_listener.sh" "$DEVICE_DIR/feedback_listener.sh"
    adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/feedback_listener.sh"
    
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/device_scripts/collect_metrics.sh" "$DEVICE_DIR/collect_metrics.sh"
    adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/collect_metrics.sh"
    
    # Push old mesh_node.sh (for backward compatibility)
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/mesh_node.sh" "$DEVICE_DIR/mesh_node.sh"
    adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/mesh_node.sh"
    
    # Push config file as device_config.json
    adb -s "$DEVICE_SERIAL" push "$SCRIPT_DIR/$CONFIG_FILE" "$DEVICE_DIR/device_config.json"
    
    echo "✓ Deployed to $DEVICE_NAME"
    echo ""
}

# Deploy to devices
if [ "$DEVICE_COUNT" -eq 3 ]; then
    # Automatic deployment to 3 devices
    DEVICE_ARRAY=($DEVICES)
    deploy_to_device "${DEVICE_ARRAY[0]}" "device_a_config.json" "DeviceA"
    deploy_to_device "${DEVICE_ARRAY[1]}" "device_b_config.json" "DeviceB"
    deploy_to_device "${DEVICE_ARRAY[2]}" "device_c_config.json" "DeviceC"
else
    # Manual device selection
    echo "Available devices:"
    i=1
    for device in $DEVICES; do
        echo "$i) $device"
        i=$((i+1))
    done
    echo ""
    
    read -p "Select device for DeviceA (1-$DEVICE_COUNT): " CHOICE_A
    read -p "Select device for DeviceB (1-$DEVICE_COUNT): " CHOICE_B
    read -p "Select device for DeviceC (1-$DEVICE_COUNT): " CHOICE_C
    
    DEVICE_ARRAY=($DEVICES)
    deploy_to_device "${DEVICE_ARRAY[$((CHOICE_A-1))]}" "device_a_config.json" "DeviceA"
    deploy_to_device "${DEVICE_ARRAY[$((CHOICE_B-1))]}" "device_b_config.json" "DeviceB"
    deploy_to_device "${DEVICE_ARRAY[$((CHOICE_C-1))]}" "device_c_config.json" "DeviceC"
fi

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Files deployed to: $DEVICE_DIR on each device"
echo "  - bid_listener.sh (LinUCB bidding)"
echo "  - orchestrator.sh (LinUCB orchestration)"
echo "  - feedback_listener.sh (LinUCB feedback loop)"
echo "  - collect_metrics.sh"
echo "  - device_config.json"
echo ""
echo "⚠️  Don't forget to deploy LinUCB solver binary:"
echo "  cd device_scripts && ./deploy_lini.sh"
echo ""
echo "Next steps:"
echo "1. Deploy LinUCB binary: cd device_scripts && ./deploy_lini.sh"
echo "2. Use ./start_mesh.sh to start LinUCB bid listeners"
echo "3. Use ./monitor_live.sh to monitor bidding activity"
echo "4. Use ./trigger_orchestrator.sh to trigger orchestration"
echo ""
