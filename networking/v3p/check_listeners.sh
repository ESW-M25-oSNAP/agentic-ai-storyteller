#!/bin/bash
# Check if bid and feedback listeners are running on all devices

echo "=========================================
"
echo "Checking Listeners on All Devices"
echo "========================================="
echo ""

# Device serials
DEVICE_A="60e0c72f"
DEVICE_B="9688d142"
DEVICE_C="RZCT90P1WAK"

check_device() {
    local SERIAL=$1
    local NAME=$2
    
    echo "[$NAME]"
    echo "  Bid Listener (nc on 5001):"
    BID_NC=$(adb -s "$SERIAL" shell "ps -A | grep -E 'nc.*5001|5001.*nc'" 2>/dev/null)
    if [ -n "$BID_NC" ]; then
        echo "    ✓ Running"
    else
        echo "    ✗ NOT RUNNING"
    fi
    
    echo "  Feedback Listener (nc on 5003):"
    FDBK_NC=$(adb -s "$SERIAL" shell "ps -A | grep -E 'nc.*5003|5003.*nc'" 2>/dev/null)
    if [ -n "$FDBK_NC" ]; then
        echo "    ✓ Running"
    else
        echo "    ✗ NOT RUNNING"
    fi
    
    echo "  Port 5001 (BID_REQUEST):"
    PORT_5001=$(adb -s "$SERIAL" shell "netstat -tuln | grep ':5001 '" 2>/dev/null)
    if [ -n "$PORT_5001" ]; then
        echo "    ✓ Listening: $PORT_5001"
    else
        echo "    ✗ NOT LISTENING"
    fi
    
    echo "  Port 5003 (FEEDBACK):"
    PORT_5003=$(adb -s "$SERIAL" shell "netstat -tuln | grep ':5003 '" 2>/dev/null)
    if [ -n "$PORT_5003" ]; then
        echo "    ✓ Listening: $PORT_5003"
    else
        echo "    ✗ NOT LISTENING"
    fi
    
    echo ""
}

check_device "$DEVICE_A" "DeviceA"
check_device "$DEVICE_B" "DeviceB"
check_device "$DEVICE_C" "DeviceC"

echo "========================================="
echo "To fix, run: ./stop_mesh.sh && ./start_mesh.sh"
echo "========================================="
