#!/bin/bash
# Manual message sender

if [ $# -lt 3 ]; then
    echo "Usage: $0 <from_device_letter> <to_device_id> <message>"
    echo ""
    echo "Examples:"
    echo "  $0 A Device_B 'Hello from A'"
    echo "  $0 B all 'Broadcast message'"
    exit 1
fi

FROM_LETTER=$1
TO_DEVICE=$2
MESSAGE=$3

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
LETTERS=("A" "B" "C" "D" "E" "F")

# Find serial for from_device
for i in ${!LETTERS[@]}; do
    if [ "${LETTERS[$i]}" == "$FROM_LETTER" ]; then
        SERIAL="${DEVICES[$i]}"
        break
    fi
done

if [ -z "$SERIAL" ]; then
    echo "Error: Device $FROM_LETTER not found"
    exit 1
fi

echo "Sending message from Device_$FROM_LETTER to $TO_DEVICE..."
adb -s $SERIAL shell "cd /data/local/tmp/mesh && ./mesh_sender.sh text $TO_DEVICE '$MESSAGE'"
