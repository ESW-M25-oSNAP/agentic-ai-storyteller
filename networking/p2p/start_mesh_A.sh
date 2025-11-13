#!/bin/bash
# Mesh Network Listener for Device_A
# Serial: 60e0c72f
# IP: 172.20.10.3

echo "Starting mesh listener on Device_A (60e0c72f)..."
echo "IP: 172.20.10.3, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s 60e0c72f shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_A 9999"
