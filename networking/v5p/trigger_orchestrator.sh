#!/bin/bash
# Trigger Multi-LinUCB orchestrator on a specific device with a prompt
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
echo "Triggering Multi-LinUCB Orchestrator on $DEVICE_NAME"
echo "========================================="
echo ""

# Map device name to serial
case $DEVICE_NAME in
    DeviceA) SERIAL="60e0c72f";;
    DeviceB) SERIAL="9688d142";;
    DeviceC) SERIAL="ZD222LPWKD";;
    *) echo "Error: Unknown device name: $DEVICE_NAME"; 
       echo "Available: DeviceA, DeviceB, DeviceC"; 
       exit 1;;
esac

# Check if device is connected
if ! adb devices | grep -q "$SERIAL"; then
    echo "Error: Device $DEVICE_NAME ($SERIAL) is not connected"
    exit 1
fi

echo "Sending Multi-LinUCB orchestrator trigger to $DEVICE_NAME..."
echo "Prompt: $PROMPT"
echo ""

# Calculate prompt length (word count approximation)
PROMPT_LENGTH=$(echo "$PROMPT" | wc -w | awk '{print $1 * 5}')  # ~5 tokens per word
echo "Estimated prompt length: $PROMPT_LENGTH tokens"
echo ""

# Call the new orchestrator.sh with prompt_length and full prompt text
echo "Running Multi-LinUCB orchestrator (with token predictor integration)..."
adb -s "$SERIAL" shell "cd $DEVICE_DIR && sh orchestrator.sh $PROMPT_LENGTH '$PROMPT'"

echo ""
echo "✓ Multi-LinUCB orchestrator completed on $DEVICE_NAME"
echo ""
echo "To view orchestrator log:"
echo "  adb -s $SERIAL shell cat $DEVICE_DIR/orchestrator.log"
echo ""
echo "To view bid listener logs:"
echo "  adb -s $SERIAL shell cat $DEVICE_DIR/bid_listener.log"
echo ""
