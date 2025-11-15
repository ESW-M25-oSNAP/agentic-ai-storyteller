#!/bin/bash
# Monitor messages from all devices in real-time

echo "========================================="
echo "Monitoring Mesh Network - LinUCB Bidding"
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Get device serials
DEVICE_A="60e0c72f"
DEVICE_B="9688d142"
DEVICE_C="RZCT90P1WAK"

# Function to colorize output
colorize() {
    local device=$1
    case $device in
        A) echo -e "\033[0;32m";;  # Green
        B) echo -e "\033[0;34m";;  # Blue
        C) echo -e "\033[0;35m";;  # Magenta
    esac
}

reset_color() {
    echo -e "\033[0m"
}

echo "Loading recent log history (last 30 lines from each device)..."
echo ""

# Show recent mesh logs (connection hellos)
echo "=== Recent Mesh Network Activity (Hellos/Connections) ==="
adb -s "$DEVICE_A" shell "tail -30 /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-MESH]$(reset_color) $line"
done

adb -s "$DEVICE_B" shell "tail -30 /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-MESH]$(reset_color) $line"
done

adb -s "$DEVICE_C" shell "tail -30 /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-MESH]$(reset_color) $line"
done

echo ""
echo "=== Recent Bid Listener Activity (LinUCB Bidding) ==="
adb -s "$DEVICE_A" shell "tail -30 /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-BID]$(reset_color) $line"
done

adb -s "$DEVICE_B" shell "tail -30 /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-BID]$(reset_color) $line"
done

adb -s "$DEVICE_C" shell "tail -30 /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-BID]$(reset_color) $line"
done

echo ""
echo "=== Recent Orchestrator Activity (Device Selection) ==="
adb -s "$DEVICE_A" shell "tail -30 /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-ORCH]$(reset_color) $line"
done

adb -s "$DEVICE_B" shell "tail -30 /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-ORCH]$(reset_color) $line"
done

adb -s "$DEVICE_C" shell "tail -30 /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-ORCH]$(reset_color) $line"
done

echo ""
echo "========================================="
echo "NOW MONITORING LIVE UPDATES..."
echo "========================================="
echo ""

# Monitor mesh.log FIRST (general mesh network messages, hellos, connections)
(adb -s "$DEVICE_A" shell "tail -f /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-MESH]$(reset_color) $line"
done) &

(adb -s "$DEVICE_B" shell "tail -f /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-MESH]$(reset_color) $line"
done) &

(adb -s "$DEVICE_C" shell "tail -f /sdcard/mesh_network/mesh.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-MESH]$(reset_color) $line"
done) &

# Monitor bid_listener logs (bidding activity with LinUCB scores)
(adb -s "$DEVICE_A" shell "tail -f /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-BID]$(reset_color) $line"
done) &

(adb -s "$DEVICE_B" shell "tail -f /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-BID]$(reset_color) $line"
done) &

(adb -s "$DEVICE_C" shell "tail -f /sdcard/mesh_network/bid_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-BID]$(reset_color) $line"
done) &

# Monitor orchestrator logs (device selection decisions)
(adb -s "$DEVICE_A" shell "tail -f /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-ORCH]$(reset_color) $line"
done) &

(adb -s "$DEVICE_B" shell "tail -f /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-ORCH]$(reset_color) $line"
done) &

(adb -s "$DEVICE_C" shell "tail -f /sdcard/mesh_network/orchestrator.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-ORCH]$(reset_color) $line"
done) &

# Wait for Ctrl+C
wait
