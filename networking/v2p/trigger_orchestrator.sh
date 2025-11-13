#!/bin/bash
# Trigger Orchestrator Script - Runs on laptop to trigger orchestrator on a specific device
# Usage: ./trigger_orchestrator.sh <device_name>

DEVICE_DIR="/sdcard/mesh_network"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if device name provided
if [ $# -eq 0 ]; then
    echo "Usage: ./trigger_orchestrator.sh <device_name>"
    echo ""
    echo "Available devices:"
    echo "  DeviceA"
    echo "  DeviceB"
    echo "  DeviceC"
    echo ""
    exit 1
fi

DEVICE_NAME=$1

echo "========================================="
echo "Triggering Orchestrator on $DEVICE_NAME"
echo "========================================="
echo ""

# Map device names to config files and serials
case "$DEVICE_NAME" in
    "DeviceA"|"devicea"|"A"|"a")
        DEVICE_NAME="DeviceA"
        CONFIG_FILE="device_a_config.json"
        ;;
    "DeviceB"|"deviceb"|"B"|"b")
        DEVICE_NAME="DeviceB"
        CONFIG_FILE="device_b_config.json"
        ;;
    "DeviceC"|"devicec"|"C"|"c")
        DEVICE_NAME="DeviceC"
        CONFIG_FILE="device_c_config.json"
        ;;
    *)
        echo "Error: Unknown device name '$DEVICE_NAME'"
        echo "Valid options: DeviceA, DeviceB, DeviceC"
        exit 1
        ;;
esac

# Get connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    exit 1
fi

echo "Found $DEVICE_COUNT connected device(s)"
echo ""

# Find the device serial for the specified device name
DEVICE_SERIAL=""

# Check each connected device to find the matching one
for serial in $DEVICES; do
    # Check if this device has the matching config
    DEVICE_CONFIG=$(adb -s "$serial" shell "cat $DEVICE_DIR/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    
    if [ "$DEVICE_CONFIG" = "$DEVICE_NAME" ]; then
        DEVICE_SERIAL="$serial"
        break
    fi
done

if [ -z "$DEVICE_SERIAL" ]; then
    echo "Error: Could not find $DEVICE_NAME in connected devices"
    echo ""
    echo "Connected devices:"
    for serial in $DEVICES; do
        DEVICE_CONFIG=$(adb -s "$serial" shell "cat $DEVICE_DIR/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
        if [ -n "$DEVICE_CONFIG" ]; then
            echo "  - $serial: $DEVICE_CONFIG"
        else
            echo "  - $serial: (not configured)"
        fi
    done
    echo ""
    exit 1
fi

echo "✓ Found $DEVICE_NAME on device $DEVICE_SERIAL"
echo ""

# Check if orchestrator script exists on device
if ! adb -s "$DEVICE_SERIAL" shell "test -f $DEVICE_DIR/orchestrator.sh && echo exists" | grep -q "exists"; then
    echo "Error: Orchestrator script not found on device"
    echo "Please deploy scripts first using: ./deploy_orchestrator.sh"
    exit 1
fi

echo "Starting orchestrator on $DEVICE_NAME..."
echo "========================================="
echo ""

# Run orchestrator on the device and stream output
adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && sh orchestrator.sh"

echo ""
echo "========================================="
echo "Orchestrator completed on $DEVICE_NAME"
echo "========================================="
echo ""
echo "To view full logs:"
echo "  adb -s $DEVICE_SERIAL shell cat $DEVICE_DIR/orchestrator.log"
echo ""
