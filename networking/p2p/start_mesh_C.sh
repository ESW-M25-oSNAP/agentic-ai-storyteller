#!/bin/bash
# Mesh Network Listener for Device_C
# Serial: ZD222LPWKD
# IP: 172.20.10.4

echo "Starting mesh listener on Device_C (ZD222LPWKD)..."
echo "IP: 172.20.10.4, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s ZD222LPWKD shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_C 9999"
