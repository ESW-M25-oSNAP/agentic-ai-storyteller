#!/bin/bash
# Check mesh network status

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
LETTERS=("A" "B" "C" "D" "E" "F")

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Mesh Network Status Check                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Device $DEVICE_ID ($SERIAL)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if mesh directory exists
    if adb -s $SERIAL shell "[ -d /data/local/tmp/mesh ]" 2>/dev/null; then
        echo "✓ Mesh directory exists"
        
        # Show device info
        echo ""
        echo "Device Info:"
        adb -s $SERIAL shell "cat /data/local/tmp/mesh/my_info.txt 2>/dev/null"
        
        # Show peers
        echo ""
        echo "Known Peers:"
        adb -s $SERIAL shell "cat /data/local/tmp/mesh/peers.txt 2>/dev/null"
        
        # Show recent log entries
        echo ""
        echo "Recent Activity (last 5 lines):"
        adb -s $SERIAL shell "tail -5 /data/local/tmp/mesh/mesh_*.log 2>/dev/null"
        
    else
        echo "✗ Mesh directory not found"
    fi
    
    echo ""
done
