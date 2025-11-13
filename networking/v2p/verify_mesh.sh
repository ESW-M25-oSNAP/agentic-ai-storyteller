#!/bin/bash
# Verify mesh network connectivity - checks if all nC2 combinations are working
# For 3 devices, verifies all 3 connections: A↔B, B↔C, A↔C

DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Verifying Mesh Network Connectivity"
echo "========================================="
echo ""

# Check connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_ARRAY=($DEVICES)
DEVICE_COUNT=${#DEVICE_ARRAY[@]}

if [ "$DEVICE_COUNT" -ne 3 ]; then
    echo "Error: Expected 3 devices, found $DEVICE_COUNT"
    exit 1
fi

echo "Found 3 devices ✓"
echo ""

# Function to check if a device is running mesh_node.sh
check_running() {
    local DEVICE_SERIAL=$1
    adb -s "$DEVICE_SERIAL" shell "pgrep -f mesh_node.sh" &>/dev/null
    return $?
}

# Function to get device name from config
get_device_name() {
    local DEVICE_SERIAL=$1
    local NAME=$(adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && cat device_config.json 2>/dev/null" | grep device_name | cut -d'"' -f4)
    echo "$NAME"
}

# Function to get connected peers from log
get_connected_peers() {
    local DEVICE_SERIAL=$1
    local LOG=$(adb -s "$DEVICE_SERIAL" shell "cat $DEVICE_DIR/mesh.log 2>/dev/null")
    
    # Find the most recent "Active peers:" line
    local PEERS=$(echo "$LOG" | grep "Active peers:" | tail -n 1 | sed 's/.*Active peers: //')
    
    if [ -z "$PEERS" ] || [ "$PEERS" = "No active connections" ]; then
        echo ""
    else
        echo "$PEERS"
    fi
}

# Check each device
echo "Checking mesh node status..."
echo ""

declare -A DEVICE_NAMES
declare -A DEVICE_PEERS

for i in 0 1 2; do
    DEVICE="${DEVICE_ARRAY[$i]}"
    
    if ! check_running "$DEVICE"; then
        echo "✗ Device $((i+1)) ($DEVICE): mesh_node.py not running"
        exit 1
    fi
    
    DEVICE_NAME=$(get_device_name "$DEVICE")
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="Device$((i+1))"
    fi
    
    DEVICE_NAMES[$i]="$DEVICE_NAME"
    
    PEERS=$(get_connected_peers "$DEVICE")
    DEVICE_PEERS[$i]="$PEERS"
    
    echo "✓ $DEVICE_NAME ($DEVICE): Running"
done

echo ""
echo "Analyzing connectivity..."
echo ""

# Expected connections for 3 devices: A-B, B-C, A-C
# Each device should see 2 peers

ALL_GOOD=true

for i in 0 1 2; do
    DEVICE_NAME="${DEVICE_NAMES[$i]}"
    PEERS="${DEVICE_PEERS[$i]}"
    
    # Count peers
    if [ -z "$PEERS" ]; then
        PEER_COUNT=0
    else
        PEER_COUNT=$(echo "$PEERS" | tr ',' '\n' | wc -l)
    fi
    
    echo "$DEVICE_NAME connections:"
    
    if [ $PEER_COUNT -eq 2 ]; then
        echo "  ✓ Connected to 2 peers: $PEERS"
    else
        echo "  ✗ Expected 2 peers, found $PEER_COUNT"
        if [ ! -z "$PEERS" ]; then
            echo "    Peers: $PEERS"
        fi
        ALL_GOOD=false
    fi
done

echo ""
echo "========================================="

if [ "$ALL_GOOD" = true ]; then
    echo "✓ VERIFICATION PASSED"
    echo "All nC2 connections established successfully!"
    echo ""
    echo "Connection topology (for 3 devices):"
    echo "  ${DEVICE_NAMES[0]} ↔ ${DEVICE_NAMES[1]}"
    echo "  ${DEVICE_NAMES[1]} ↔ ${DEVICE_NAMES[2]}"
    echo "  ${DEVICE_NAMES[0]} ↔ ${DEVICE_NAMES[2]}"
    echo ""
    echo "Checkpoint 0: COMPLETE ✓"
else
    echo "✗ VERIFICATION FAILED"
    echo "Not all connections are established"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if all devices are on the same network"
    echo "  2. Verify IP addresses in config files are correct"
    echo "  3. Check device logs: ./status_mesh.sh"
    echo "  4. Try restarting: ./stop_mesh.sh && ./start_mesh.sh"
fi

echo "========================================="
echo ""
