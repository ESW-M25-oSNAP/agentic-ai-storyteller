#!/bin/bash

# Script to trigger orchestrator on a specific Android device
# Usage: ./run_orchestrator.sh <device_name>
# Example: ./run_orchestrator.sh Device_A

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEVICE_NAME="$1"

if [ -z "$DEVICE_NAME" ]; then
    echo -e "${RED}Error: Device name required${NC}"
    echo "Usage: $0 <device_name>"
    echo "Example: $0 Device_A"
    exit 1
fi

# Map device names to ADB serial numbers
# This will be populated from the mesh setup
MESH_DIR="/data/local/tmp/mesh"
DEVICE_MAP_FILE="$HOME/.mesh_device_map"

# Check if device map exists
if [ ! -f "$DEVICE_MAP_FILE" ]; then
    echo -e "${YELLOW}Device map not found. Creating from available devices...${NC}"
    echo ""
    echo "Available devices:"
    adb devices -l
    echo ""
    echo "Please run setup_mesh_direct.sh first to configure devices."
    exit 1
fi

# Look up device serial from map
DEVICE_SERIAL=$(grep "^${DEVICE_NAME}:" "$DEVICE_MAP_FILE" | cut -d: -f2)

if [ -z "$DEVICE_SERIAL" ]; then
    echo -e "${RED}Error: Device '$DEVICE_NAME' not found in device map${NC}"
    echo "Available devices:"
    cat "$DEVICE_MAP_FILE"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Starting Orchestrator on $DEVICE_NAME                  ${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check device is connected
if ! adb -s "$DEVICE_SERIAL" get-state 2>/dev/null | grep -q device; then
    echo -e "${RED}Error: Device $DEVICE_SERIAL is not connected${NC}"
    exit 1
fi

# Deploy orchestrator script to device
echo -e "${GREEN}[1/4] Deploying orchestrator to device...${NC}"
adb -s "$DEVICE_SERIAL" push src/orchestrator_p2p.py "$MESH_DIR/orchestrator.py" 2>/dev/null

# Ensure Python is available (Termux)
echo -e "${GREEN}[2/4] Checking Python availability...${NC}"
PYTHON_PATH=$(adb -s "$DEVICE_SERIAL" shell "which python3 2>/dev/null || which python 2>/dev/null || echo '/data/data/com.termux/files/usr/bin/python'" | tr -d '\r')

if [ -z "$PYTHON_PATH" ]; then
    echo -e "${YELLOW}Warning: Python not found. Using Termux Python path${NC}"
    PYTHON_PATH="/data/data/com.termux/files/usr/bin/python"
fi

# Create device configuration if it doesn't exist
echo -e "${GREEN}[3/4] Checking device configuration...${NC}"
CONFIG_EXISTS=$(adb -s "$DEVICE_SERIAL" shell "[ -f $MESH_DIR/device_config.json ] && echo 'yes' || echo 'no'" | tr -d '\r')

if [ "$CONFIG_EXISTS" = "no" ]; then
    echo -e "${YELLOW}Device configuration not found. Creating...${NC}"
    echo ""
    read -p "Does this device have NPU? (y/n): " HAS_NPU
    
    if [[ "$HAS_NPU" =~ ^[Yy]$ ]]; then
        NPU_VALUE="true"
    else
        NPU_VALUE="false"
    fi
    
    # Create device config
    adb -s "$DEVICE_SERIAL" shell "echo '{\"device_id\": \"$DEVICE_NAME\", \"has_npu\": $NPU_VALUE}' > $MESH_DIR/device_config.json"
    echo -e "${GREEN}✓ Configuration saved${NC}"
fi

# Start orchestrator on device
echo -e "${GREEN}[4/4] Starting orchestrator...${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Orchestrator running on $DEVICE_NAME${NC}"
echo -e "${BLUE}  Press Ctrl+C to stop${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Run orchestrator with adb shell
# The orchestrator will coordinate with other devices via P2P mesh
adb -s "$DEVICE_SERIAL" shell "cd $MESH_DIR && $PYTHON_PATH orchestrator.py"
