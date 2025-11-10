#!/bin/bash
# Mesh Network Listener for Device_B
# Serial: ZD222LPWKD
# IP: 0.0.0.0

echo "Starting mesh listener on Device_B (ZD222LPWKD)..."
echo "IP: 0.0.0.0, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s ZD222LPWKD shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_B 9999"
