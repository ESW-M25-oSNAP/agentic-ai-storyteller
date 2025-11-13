#!/bin/bash
# Mesh Network Listener for Device_B
# Serial: 9688d142
# IP: 172.20.10.2

echo "Starting mesh listener on Device_B (9688d142)..."
echo "IP: 172.20.10.2, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s 9688d142 shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_B 9999"
