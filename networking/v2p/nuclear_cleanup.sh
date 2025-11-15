#!/bin/bash
# Nuclear option: Kill everything related to mesh network

echo "========================================="
echo "NUCLEAR CLEANUP - Killing All Processes"
echo "========================================="
echo ""

# Check connected devices
DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | wc -w)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "Error: No devices connected via ADB"
    exit 1
fi

echo "Found $DEVICE_COUNT connected device(s)"
echo ""

# Function to nuclear cleanup on a device
nuclear_cleanup_device() {
    local DEVICE_SERIAL=$1
    local DEVICE_NUM=$2
    
    echo "Nuclear cleanup on Device $DEVICE_NUM ($DEVICE_SERIAL)..."
    
    # First pass: Kill by name
    adb -s "$DEVICE_SERIAL" shell "killall -9 nc" 2>/dev/null
    adb -s "$DEVICE_SERIAL" shell "killall -9 sh" 2>/dev/null
    
    # Second pass: Kill by process ID for nc
    echo "  Finding all nc processes..."
    NC_PIDS=$(adb -s "$DEVICE_SERIAL" shell "ps -A | grep -E 'nc|toybox' | grep -v grep" | awk '{print $2}')
    for pid in $NC_PIDS; do
        echo "    Killing PID: $pid"
        adb -s "$DEVICE_SERIAL" shell "kill -9 $pid" 2>/dev/null
    done
    
    # Third pass: Kill any sh processes from mesh directory
    echo "  Finding mesh-related processes..."
    MESH_PIDS=$(adb -s "$DEVICE_SERIAL" shell "ps -A | grep -E 'mesh_node|/sdcard/mesh' | grep -v grep" | awk '{print $2}')
    for pid in $MESH_PIDS; do
        echo "    Killing PID: $pid"
        adb -s "$DEVICE_SERIAL" shell "kill -9 $pid" 2>/dev/null
    done
    
    sleep 2
    
    # Verify
    NC_COUNT=$(adb -s "$DEVICE_SERIAL" shell "ps -A | grep nc | grep -v grep" 2>/dev/null | wc -l)
    
    if [ "$NC_COUNT" -eq 0 ]; then
        echo "✓ Device $DEVICE_NUM: All processes killed"
    else
        echo "⚠️  Device $DEVICE_NUM: $NC_COUNT processes still running"
        echo ""
        echo "  Remaining processes:"
        adb -s "$DEVICE_SERIAL" shell "ps -A | grep nc | grep -v grep"
    fi
    echo ""
}

# Clean up all devices
i=1
for device in $DEVICES; do
    nuclear_cleanup_device "$device" "$i"
    i=$((i+1))
done

echo "========================================="
echo "Nuclear Cleanup Complete"
echo "========================================="
echo ""