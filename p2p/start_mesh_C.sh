#!/bin/bash
# Mesh Network Listener for Device_C
# Serial: ZD222LPWKD
# IP: 10.42.0.160

echo "Starting mesh listener on Device_C (ZD222LPWKD)..."
echo "IP: 10.42.0.160, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s ZD222LPWKD shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_C 9999"
