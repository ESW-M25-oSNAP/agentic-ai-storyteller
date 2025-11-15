#!/bin/bash
# Complete Automated Setup for Orchestrator System
# This script does everything needed to get the system running

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     ORCHESTRATOR SYSTEM - AUTOMATED SETUP                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check ADB
if ! command -v adb &> /dev/null; then
    echo "❌ Error: ADB not found"
    exit 1
fi

# Check devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

echo "✓ Found $DEVICE_COUNT connected device(s)"
echo ""

if [ "$DEVICE_COUNT" -lt 2 ]; then
    echo "❌ Error: Need at least 2 devices connected"
    exit 1
fi

# STEP 1: Clean up
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Cleaning up existing processes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "./stop_bid_listeners.sh" ]; then
    ./stop_bid_listeners.sh 2>/dev/null || true
fi

if [ -f "./nuclear_cleanup.sh" ]; then
    ./nuclear_cleanup.sh 2>/dev/null || true
fi

echo ""

# STEP 2: Deploy mesh network
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Deploying mesh network configs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$DEVICE_COUNT" -eq 3 ]; then
    # Automatic deployment for 3 devices
    echo "Deploying to 3 devices automatically..."
    echo ""
    ./deploy_to_devices.sh 2>&1 | grep -v "bytes in"
elif [ "$DEVICE_COUNT" -eq 2 ]; then
    # Manual selection for 2 devices
    echo "You have 2 devices. Please select which devices to use:"
    echo ""
    i=1
    for device in $DEVICES; do
        echo "$i) $device"
        i=$((i+1))
    done
    echo ""
    read -p "Select device for DeviceA (1-2): " CHOICE_A
    read -p "Select device for DeviceB (1-2): " CHOICE_B
    echo ""
    echo "$CHOICE_A" | ./deploy_to_devices.sh 2>&1 | grep -v "bytes in"
fi

echo ""
sleep 2

# STEP 3: Deploy orchestrator
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Deploying orchestrator scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./deploy_orchestrator.sh 2>&1 | grep -v "bytes in"

echo ""
sleep 2

# STEP 4: Start bid listeners
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Starting bid listeners"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./start_bid_listeners.sh

echo ""
echo "Waiting for bid listeners to stabilize..."
sleep 3
echo ""

# STEP 5: Verify
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Verifying setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count bid listeners
LISTENER_COUNT=0
for device in $DEVICES; do
    if adb -s "$device" shell "pgrep -f bid_listener.sh" &>/dev/null; then
        LISTENER_COUNT=$((LISTENER_COUNT + 1))
    fi
done

echo "✓ Bid listeners running: $LISTENER_COUNT/$DEVICE_COUNT"
echo ""

# Show device configs
echo "Device configurations:"
echo "─────────────────────"
for device in $DEVICES; do
    DEVICE_NAME=$(adb -s "$device" shell "cat /sdcard/mesh_network/device_config.json 2>/dev/null" | grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' | tr -d '\r')
    HAS_NPU=$(adb -s "$device" shell "cat /sdcard/mesh_network/device_config.json 2>/dev/null" | grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' | sed 's/.*: *\([a-z]*\)/\1/' | tr -d '\r')
    FREE_NPU=$(adb -s "$device" shell "cat /sdcard/mesh_network/device_config.json 2>/dev/null" | grep -o '"free_npu"[[:space:]]*:[[:space:]]*[a-z]*' | sed 's/.*: *\([a-z]*\)/\1/' | tr -d '\r')
    
    if [ -n "$DEVICE_NAME" ]; then
        echo "  $DEVICE_NAME ($device): has_npu=$HAS_NPU, free_npu=$FREE_NPU"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ SETUP COMPLETE!                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 Ready to test! Run:"
echo ""
echo "   ./trigger_orchestrator.sh DeviceA"
echo "   ./trigger_orchestrator.sh DeviceB"
echo "   ./trigger_orchestrator.sh DeviceC"
echo ""
echo "📚 For more info, see: COMPLETE_SETUP_GUIDE.md"
echo ""
