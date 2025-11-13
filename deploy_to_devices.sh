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
    
    # Push mesh_node.sh
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
echo ""
echo "Next steps:"
echo "1. Ensure netcat (nc) is installed on devices (pkg install netcat-openbsd)"
echo "2. Use start_mesh.sh to start the mesh network"
echo "3. Use verify_mesh.sh to check connectivity"
echo ""
