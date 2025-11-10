#!/system/bin/sh
# Standalone P2P Mesh Message Sender (No Termux Required)

MESH_DIR="/data/local/tmp/mesh"
PEERS_FILE="$MESH_DIR/peers.txt"
DEVICE_ID=$(cat "$MESH_DIR/my_info.txt" 2>/dev/null | cut -d: -f1)

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="unknown"
fi

# Send message to specific peer
send_to_peer() {
    local peer_ip="$1"
    local peer_port="$2"
    local message="$3"
    
    echo "$message" | nc -w 2 "$peer_ip" "$peer_port" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Message sent successfully"
        return 0
    else
        echo "✗ Failed to send message"
        return 1
    fi
}

# Get peer info
get_peer_info() {
    local target_id="$1"
    grep "^$target_id:" "$PEERS_FILE" 2>/dev/null | head -1
}

# Main command handler
case "$1" in
    text)
        TARGET="$2"
        MESSAGE="$3"
        
        if [ "$TARGET" = "all" ]; then
            # Broadcast to all peers
            echo "Broadcasting TEXT message to all peers..."
            SUCCESS=0
            TOTAL=0
            
            while IFS=: read -r peer_id peer_ip peer_port; do
                if [ -n "$peer_ip" ] && [ -n "$peer_port" ]; then
                    TOTAL=$((TOTAL + 1))
                    echo "Sending to $peer_id ($peer_ip:$peer_port)..."
                    if send_to_peer "$peer_ip" "$peer_port" "TEXT|$DEVICE_ID|$MESSAGE"; then
                        SUCCESS=$((SUCCESS + 1))
                    fi
                fi
            done < "$PEERS_FILE"
            
            echo "Broadcast complete: $SUCCESS/$TOTAL successful"
        else
            # Send to specific peer
            PEER_INFO=$(get_peer_info "$TARGET")
            if [ -n "$PEER_INFO" ]; then
                PEER_IP=$(echo "$PEER_INFO" | cut -d: -f2)
                PEER_PORT=$(echo "$PEER_INFO" | cut -d: -f3)
                
                echo "Sending TEXT to $TARGET ($PEER_IP:$PEER_PORT)..."
                send_to_peer "$PEER_IP" "$PEER_PORT" "TEXT|$DEVICE_ID|$MESSAGE"
            else
                echo "✗ Peer not found: $TARGET"
                exit 1
            fi
        fi
        ;;
        
    slm)
        TARGET="$2"
        PROMPT="$3"
        
        PEER_INFO=$(get_peer_info "$TARGET")
        if [ -n "$PEER_INFO" ]; then
            PEER_IP=$(echo "$PEER_INFO" | cut -d: -f2)
            PEER_PORT=$(echo "$PEER_INFO" | cut -d: -f3)
            
            echo "Sending SLM_PROMPT to $TARGET ($PEER_IP:$PEER_PORT)..."
            send_to_peer "$PEER_IP" "$PEER_PORT" "SLM_PROMPT|$DEVICE_ID|$PROMPT"
        else
            echo "✗ Peer not found: $TARGET"
            exit 1
        fi
        ;;
        
    discover)
        echo "Sending discovery broadcast..."
        MY_IP=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        
        while IFS=: read -r peer_id peer_ip peer_port; do
            if [ -n "$peer_ip" ] && [ -n "$peer_port" ]; then
                echo "Discovering $peer_id ($peer_ip:$peer_port)..."
                send_to_peer "$peer_ip" "$peer_port" "DISCOVER|$DEVICE_ID|$MY_IP:9999"
            fi
        done < "$PEERS_FILE"
        ;;
        
    list)
        echo "=== Known Peers ==="
        if [ -f "$PEERS_FILE" ]; then
            cat "$PEERS_FILE" | nl
        else
            echo "No peers configured"
        fi
        echo "==================="
        ;;
        
    add)
        PEER_ID="$2"
        PEER_IP="$3"
        PEER_PORT="${4:-9999}"
        
        if [ -z "$PEER_ID" ] || [ -z "$PEER_IP" ]; then
            echo "Usage: $0 add <peer_id> <peer_ip> [peer_port]"
            exit 1
        fi
        
        echo "$PEER_ID:$PEER_IP:$PEER_PORT" >> "$PEERS_FILE"
        echo "✓ Added peer: $PEER_ID:$PEER_IP:$PEER_PORT"
        ;;
        
    *)
        echo "Mesh Network Message Sender"
        echo ""
        echo "Usage:"
        echo "  $0 text <target|all> <message>     - Send text message"
        echo "  $0 slm <target> <prompt>            - Send SLM prompt"
        echo "  $0 discover                         - Discover peers"
        echo "  $0 list                             - List known peers"
        echo "  $0 add <id> <ip> [port]            - Add peer manually"
        echo ""
        echo "Examples:"
        echo "  $0 text Device_B 'Hello!'"
        echo "  $0 text all 'Broadcast message'"
        echo "  $0 slm Device_B 'Describe a sunset'"
        echo "  $0 add Device_C 192.168.1.103 9999"
        exit 1
        ;;
esac
