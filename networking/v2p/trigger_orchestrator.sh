#!/bin/bash
# Trigger orchestrator mode on a specific device with a prompt
# Usage: ./trigger_orchestrator.sh <device_name> "<prompt>"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <device_name> \"<prompt>\""
    echo ""
    echo "Example: $0 DeviceA \"What is France's capital?\""
    echo ""
    echo "Available devices: DeviceA, DeviceB, DeviceC"
    exit 1
fi

DEVICE_NAME=$1
PROMPT=$2
DEVICE_DIR="/sdcard/mesh_network"

echo "========================================="
echo "Triggering Orchestrator on $DEVICE_NAME"
echo "========================================="
echo ""

# Map device name to serial
case $DEVICE_NAME in
    DeviceA) SERIAL="60e0c72f";;
    DeviceB) SERIAL="9688d142";;
    DeviceC) SERIAL="RZCT90P1WAK";;
    *) echo "Error: Unknown device name: $DEVICE_NAME"; 
       echo "Available: DeviceA, DeviceB, DeviceC"; 
       exit 1;;
esac

# Check if device is connected
if ! adb devices | grep -q "$SERIAL"; then
    echo "Error: Device $DEVICE_NAME ($SERIAL) is not connected"
    exit 1
fi

echo "Sending orchestrator trigger to $DEVICE_NAME..."
echo "Prompt: $PROMPT"
echo ""

# Create orchestrator flag file on the device
adb -s "$SERIAL" shell "echo 'orchestrator' > $DEVICE_DIR/mode.flag"

# Save the prompt to a file on the orchestrator device
adb -s "$SERIAL" shell "echo '$PROMPT' > $DEVICE_DIR/orchestrator_prompt.txt"

# Send orchestrator command to all peers (broadcast bid request)
echo "Broadcasting bid request from $DEVICE_NAME..."
adb -s "$SERIAL" shell "echo '{\"type\":\"orchestrator_start\",\"from\":\"$DEVICE_NAME\"}' > $DEVICE_DIR/orchestrator.cmd"

echo ""
echo "✓ Orchestrator mode triggered on $DEVICE_NAME"
echo ""
echo "The orchestrator is now collecting bids from all devices."
echo ""
echo "To view orchestrator output:"
echo "  adb -s $SERIAL shell cat $DEVICE_DIR/orchestrator.log"
echo ""
echo "To view mesh logs:"
echo "  adb -s $SERIAL shell tail -f $DEVICE_DIR/mesh.log"
echo ""
