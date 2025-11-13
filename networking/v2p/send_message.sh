#!/bin/bash
# Send a test message from one device to another

if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_device_num> <message>"
    echo ""
    echo "Example: $0 1 \"Hello from device 1\""
    echo ""
    echo "Devices:"
    echo "  1 = DeviceA (60e0c72f)"
    echo "  2 = DeviceB (9688d142)"
    echo "  3 = DeviceC (RZCT90P1WAK)"
    exit 1
fi

SOURCE=$1
MESSAGE=$2

# Device serials and their target peer IPs
case $SOURCE in
    1) SERIAL="60e0c72f"; NAME="DeviceA"; TARGET_IPS=("10.58.124.226" "10.58.124.99");;      # A→B,C
    2) SERIAL="9688d142"; NAME="DeviceB"; TARGET_IPS=("10.58.124.68" "10.58.124.99");;      # B→A,C
    3) SERIAL="RZCT90P1WAK"; NAME="DeviceC"; TARGET_IPS=("10.58.124.68" "10.58.124.226");;  # C→A,B
    *) echo "Invalid device number"; exit 1;;
esac

echo "Sending from $NAME ($SERIAL): $MESSAGE"
echo ""

# Send to all peers
for ip in "${TARGET_IPS[@]}"; do
    echo "→ Sending to $ip"
    adb -s "$SERIAL" shell "echo '{\"type\":\"message\",\"from\":\"$NAME\",\"content\":\"$MESSAGE\"}' | nc -w 1 $ip 5000"
done

echo ""
echo "Message sent! Check logs with:"
echo "  adb shell \"tail -f /sdcard/mesh_network/mesh.log\""
