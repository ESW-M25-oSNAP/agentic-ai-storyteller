#!/bin/bash
# Check mesh network status

DEVICES=(60e0c72f 9688d142 ZD222LPWKD)
LETTERS=(A B C)

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Mesh Network Status                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Device $LETTER ($SERIAL)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check connection
    adb -s $SERIAL get-state >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Connected via ADB"
        
        # IP address
        IP=$(adb -s $SERIAL shell "ip addr show wlan0 | grep 'inet '" | awk '{print $2}' | cut -d'/' -f1 | tr -d '\r')
        echo "  IP: $IP"
        
        # Check if listener is running
        LISTENER=$(adb -s $SERIAL shell "ps | grep mesh_listener" | grep -v grep)
        if [ -n "$LISTENER" ]; then
            echo "  ✓ Listener running"
        else
            echo "  ✗ Listener not running"
        fi
        
        # Peer count
        PEER_COUNT=$(adb -s $SERIAL shell "wc -l < /data/local/tmp/mesh/peers.txt 2>/dev/null" | tr -d '\r')
        echo "  Peers configured: $PEER_COUNT"
        
        # Recent log
        echo "  Recent activity:"
        adb -s $SERIAL shell "tail -3 /data/local/tmp/mesh/mesh_Device_${LETTER}.log 2>/dev/null" | sed 's/^/    /'
        
    else
        echo "✗ Not connected"
    fi
    
    echo ""
done
