#!/bin/bash
# Mesh Network Listener for Device_A
# Serial: 60e0c72f
# IP: 10.42.0.139

echo "Starting mesh listener on Device_A (60e0c72f)..."
echo "IP: 10.42.0.139, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s 60e0c72f shell "cd /data/local/tmp/mesh && ./mesh_listener.sh Device_A 9999"
