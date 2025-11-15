#!/bin/bash
# Update existing device config files to add NPU information
# This preserves existing network settings while adding NPU fields

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Update NPU Configuration for Devices"
echo "========================================="
echo ""
echo "This script will update your existing device configs with NPU information."
echo "Your network settings (IPs, ports) will be preserved."
echo ""

# Function to update a config file with NPU info
update_config_with_npu() {
    local CONFIG_FILE=$1
    local DEVICE_NAME=$2
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️  Warning: $CONFIG_FILE not found, skipping..."
        return 1
    fi
    
    # Check if already has NPU fields
    if grep -q '"has_npu"' "$CONFIG_FILE"; then
        echo "ℹ️  $DEVICE_NAME already has NPU fields configured"
        read -p "Do you want to update them? (y/n): " UPDATE
        if [[ "$UPDATE" != "y" && "$UPDATE" != "Y" ]]; then
            return 0
        fi
    fi
    
    # Ask about NPU
    read -p "Does $DEVICE_NAME have an NPU? (y/n): " HAS_NPU
    if [[ "$HAS_NPU" == "y" || "$HAS_NPU" == "Y" ]]; then
        HAS_NPU_JSON="true"
        read -p "Is $DEVICE_NAME's NPU currently free/available? (y/n): " FREE_NPU
        if [[ "$FREE_NPU" == "y" || "$FREE_NPU" == "Y" ]]; then
            FREE_NPU_JSON="true"
        else
            FREE_NPU_JSON="false"
        fi
    else
        HAS_NPU_JSON="false"
        FREE_NPU_JSON="false"
    fi
    
    # Create temporary file with updated config
    # Use Python to properly parse and update JSON
    python3 << EOF
import json
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    
    # Update or add NPU fields (convert bash boolean strings to Python booleans)
    config['has_npu'] = '$HAS_NPU_JSON' == 'true'
    config['free_npu'] = '$FREE_NPU_JSON' == 'true'
    
    # Write back to file
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(config, f, indent=2)
    
    print("✓ Updated $DEVICE_NAME config")
except Exception as e:
    print(f"✗ Error updating $CONFIG_FILE: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    
    if [ $? -eq 0 ]; then
        echo "  NPU: $HAS_NPU_JSON, Free: $FREE_NPU_JSON"
        return 0
    else
        return 1
    fi
}

# Update each device config
echo "Updating DeviceA configuration..."
update_config_with_npu "device_a_config.json" "DeviceA"
echo ""

echo "Updating DeviceB configuration..."
update_config_with_npu "device_b_config.json" "DeviceB"
echo ""

echo "Updating DeviceC configuration..."
update_config_with_npu "device_c_config.json" "DeviceC"
echo ""

echo "========================================="
echo "NPU Configuration Update Complete"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review the updated config files"
echo "2. Deploy to devices: ./deploy_to_devices.sh"
echo "3. Restart mesh network: ./start_mesh.sh"
echo ""
