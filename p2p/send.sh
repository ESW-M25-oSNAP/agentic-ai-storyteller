#!/bin/bash
# Quick message sender from laptop

if [ $# -lt 3 ]; then
    echo "Usage: $0 <from_device> <to_device> <message>"
    echo ""
    echo "Devices: A, B, C"
    echo "Special: 'all' to broadcast"
    echo ""
    echo "Examples:"
    echo "  $0 A B 'Hello from A'"
    echo "  $0 B all 'Broadcast message'"
    exit 1
fi

FROM=$1
TO=$2
shift 2
MESSAGE="$*"

# Get device serials
case $FROM in
    A) SERIAL="60e0c72f" ;;
    B) SERIAL="9688d142" ;;
    C) SERIAL="ZD222LPWKD" ;;
    *) echo "Unknown device: $FROM"; exit 1 ;;
esac

TO_DEVICE="Device_$TO"
if [ "$TO" = "all" ]; then
    TO_DEVICE="all"
fi

echo "Sending: Device_$FROM → $TO_DEVICE"
echo "Message: $MESSAGE"
echo ""

adb -s $SERIAL shell "cd /data/local/tmp/mesh && sh mesh_sender.sh text $TO_DEVICE '$MESSAGE'"
