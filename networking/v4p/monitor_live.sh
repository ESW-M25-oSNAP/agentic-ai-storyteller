#!/bin/bash
# Monitor messages from all devices in real-time
# Shows only most recent activity (clears old logs on each run)

echo "========================================="
echo "Monitoring Mesh Network - LinUCB Bidding"
echo "Clearing old logs and showing fresh output"
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Get device serials
DEVICE_A="60e0c72f"
DEVICE_B="9688d142"
DEVICE_C="ZD222LPWKD"

# Clear old log files on all devices to start fresh
echo "Clearing old logs on all devices..."
adb -s "$DEVICE_A" shell "cd /sdcard/mesh_network && > orchestrator.log && > bid_listener.log && > feedback_listener.log && > mesh.log" 2>/dev/null
adb -s "$DEVICE_B" shell "cd /sdcard/mesh_network && > orchestrator.log && > bid_listener.log && > feedback_listener.log && > mesh.log" 2>/dev/null
adb -s "$DEVICE_C" shell "cd /sdcard/mesh_network && > orchestrator.log && > bid_listener.log && > feedback_listener.log && > mesh.log" 2>/dev/null
echo "✓ Logs cleared"
echo ""
echo "Monitoring live activity..."
echo ""

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

# Skip showing history since we just cleared logs
# Go straight to live monitoring

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

# Monitor feedback_listener logs (LinUCB learning from feedback)
(adb -s "$DEVICE_A" shell "tail -f /sdcard/mesh_network/feedback_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize A)[DeviceA-FDBK]$(reset_color) $line"
done) &

(adb -s "$DEVICE_B" shell "tail -f /sdcard/mesh_network/feedback_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize B)[DeviceB-FDBK]$(reset_color) $line"
done) &

(adb -s "$DEVICE_C" shell "tail -f /sdcard/mesh_network/feedback_listener.log 2>/dev/null" | while read line; do
    echo "$(colorize C)[DeviceC-FDBK]$(reset_color) $line"
done) &

# Wait for Ctrl+C
wait
