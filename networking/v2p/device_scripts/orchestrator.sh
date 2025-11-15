#!/system/bin/sh
# Orchestrator Script - Requests bids and selects device with lowest LinUCB score
# Usage: sh orchestrator.sh [prompt_length]

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/orchestrator.log"
BID_RESPONSE_PORT=5002
TIMEOUT=30
LINUCB_BIN="/data/local/tmp/lini"
STATE_A="/data/local/tmp/state_A.dat"
STATE_B="/data/local/tmp/state_B.dat"

# Get prompt length from argument or default to 100
PROMPT_LENGTH=${1:-100}

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') Orchestrator Starting (prompt_length: $PROMPT_LENGTH)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Parse device info
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
DEVICE_IP=$(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Running on IP: $DEVICE_IP" >> "$LOG_FILE"

# Get list of peer IPs
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Start listener for bid responses in background
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting bid response listener on port $BID_RESPONSE_PORT" >> "$LOG_FILE"

# Create temporary file for bid responses
BID_FILE="$MESH_DIR/bids_temp.txt"
> "$BID_FILE"

# Start background listener
(
    timeout $TIMEOUT nc -l -p $BID_RESPONSE_PORT > "$BID_FILE" 2>/dev/null &
    NC_PID=$!
    
    # Collect responses for timeout duration
    sleep $TIMEOUT
    
    # Kill listener if still running
    kill $NC_PID 2>/dev/null
) &

sleep 1

# Broadcast bid request to all peers with prompt_length
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Broadcasting BID_REQUEST to all peers" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

for peer_ip in $PEER_IPS; do
    if [ -n "$peer_ip" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid request to $peer_ip" >> "$LOG_FILE"
        
        # Send bid request with prompt_length on port 5001
        BID_REQUEST="BID_REQUEST|from:$DEVICE_IP|prompt_length:$PROMPT_LENGTH"
        echo "$BID_REQUEST" | nc -w 2 "$peer_ip" 5001 >> "$LOG_FILE" 2>&1 &
    fi
done

# Calculate self bid using LinUCB
SELF_METRICS=$(sh "$MESH_DIR/collect_metrics.sh")
SELF_CPU_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f3)
SELF_RAM_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f4)

# Normalize features
CPU_NORM=$(echo "$SELF_CPU_LOAD" | awk '{printf "%.4f", $1/100}')
RAM_NORM=$(echo "$SELF_RAM_LOAD" | awk '{printf "%.4f", $1/100}')
PROMPT_NORM=$(echo "$PROMPT_LENGTH" | awk '{printf "%.4f", $1/1000}')

# Get self score from LinUCB (with state file paths)
SELF_SCORE=$($LINUCB_BIN score $STATE_A $STATE_B $CPU_NORM $RAM_NORM $PROMPT_NORM 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$SELF_SCORE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Self score: $SELF_SCORE (cpu:$SELF_CPU_LOAD ram:$SELF_RAM_LOAD)" >> "$LOG_FILE"
    LOWEST_SCORE=$SELF_SCORE
    BEST_DEVICE="$DEVICE_NAME"
    BEST_BID_ID="self"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] WARNING: LinUCB solver failed for self" >> "$LOG_FILE"
    LOWEST_SCORE=999999
    BEST_DEVICE=""
    BEST_BID_ID=""
fi

# Wait for responses (TIMEOUT seconds)
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Waiting for bid responses..." >> "$LOG_FILE"
sleep $((TIMEOUT + 1))

echo "" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Processing received bids" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Parse bid responses and select lowest score
if [ -s "$BID_FILE" ]; then
    while IFS= read -r bid_line; do
        if echo "$bid_line" | grep -q "BID_RESPONSE"; then
            # Parse bid response
            DEVICE=$(echo "$bid_line" | grep -o 'device:[^|]*' | cut -d':' -f2)
            BID_ID=$(echo "$bid_line" | grep -o 'bid_id:[^|]*' | cut -d':' -f2)
            SCORE=$(echo "$bid_line" | grep -o 'score:[^|]*' | cut -d':' -f2)
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') Bid from $DEVICE:" >> "$LOG_FILE"
            echo "  - bid_id: $BID_ID" >> "$LOG_FILE"
            echo "  - score: $SCORE" >> "$LOG_FILE"
            
            # Compare scores (lower is better - more optimistic about low latency)
            SCORE_INT=$(echo "$SCORE" | awk '{printf "%d", $1 * 1000}')
            LOWEST_INT=$(echo "$LOWEST_SCORE" | awk '{printf "%d", $1 * 1000}')
            
            if [ "$SCORE_INT" -lt "$LOWEST_INT" ]; then
                LOWEST_SCORE=$SCORE
                BEST_DEVICE="$DEVICE"
                BEST_BID_ID="$BID_ID"
                echo "  ✓ Lowest score so far" >> "$LOG_FILE"
            fi
            
            echo "" >> "$LOG_FILE"
        fi
    done < "$BID_FILE"
fi

# Print final decision
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') ORCHESTRATOR DECISION" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

if [ -n "$BEST_DEVICE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Lowest score chosen: $BEST_DEVICE (score: $LOWEST_SCORE, bid_id: $BEST_BID_ID)" >> "$LOG_FILE"
    echo ""
    echo "✓ Winner: $BEST_DEVICE (score: $LOWEST_SCORE)"
    echo "BidID: $BEST_BID_ID"
    echo ""
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✗ No suitable device found" >> "$LOG_FILE"
    echo ""
    echo "✗ No suitable device found"
    echo ""
fi

echo "========================================" >> "$LOG_FILE"

# Cleanup
rm -f "$BID_FILE"

exit 0
