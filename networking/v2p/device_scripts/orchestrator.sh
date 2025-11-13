#!/system/bin/sh
# Orchestrator Script - Runs on a device to request bids and select best device
# Usage: sh orchestrator.sh

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/orchestrator.log"
BID_RESPONSE_PORT=5002
TIMEOUT=30

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') Orchestrator Starting" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Parse device info
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
DEVICE_IP=$(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Running on IP: $DEVICE_IP" >> "$LOG_FILE"

# Get list of peer IPs
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PEER_NAMES=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

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

# Broadcast bid request to all peers
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Broadcasting BID_REQUEST to all peers" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

for peer_ip in $PEER_IPS; do
    if [ -n "$peer_ip" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid request to $peer_ip" >> "$LOG_FILE"
        
        # Send bid request on port 5001
        BID_REQUEST="BID_REQUEST|from:$DEVICE_IP"
        echo "$BID_REQUEST" | nc -w 2 "$peer_ip" 5001 >> "$LOG_FILE" 2>&1 &
    fi
done

# Wait for responses (TIMEOUT seconds)
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Waiting for bid responses..." >> "$LOG_FILE"
sleep $((TIMEOUT + 1))

echo "" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Processing received bids" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Parse bid responses
if [ ! -s "$BID_FILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ERROR: No bids received!" >> "$LOG_FILE"
    echo "No devices responded to bid request"
    exit 1
fi

# Variables for tracking best bid
BEST_DEVICE=""
BEST_CHOICE="none"
LOWEST_CPU=999999
NPU_FOUND="false"

# Process each bid
while IFS= read -r bid_line; do
    if echo "$bid_line" | grep -q "BID_RESPONSE"; then
        # Parse bid response
        DEVICE=$(echo "$bid_line" | grep -o 'device:[^|]*' | cut -d':' -f2)
        HAS_NPU=$(echo "$bid_line" | grep -o 'has_npu:[^|]*' | cut -d':' -f2)
        FREE_NPU=$(echo "$bid_line" | grep -o 'free_npu:[^|]*' | cut -d':' -f2)
        CPU_LOAD=$(echo "$bid_line" | grep -o 'cpu_load:[^|]*' | cut -d':' -f2)
        RAM_LOAD=$(echo "$bid_line" | grep -o 'ram_load:[^|]*' | cut -d':' -f2)
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') Bid from $DEVICE:" >> "$LOG_FILE"
        echo "  - has_npu: $HAS_NPU" >> "$LOG_FILE"
        echo "  - free_npu: $FREE_NPU" >> "$LOG_FILE"
        echo "  - cpu_load: $CPU_LOAD%" >> "$LOG_FILE"
        echo "  - ram_load: $RAM_LOAD%" >> "$LOG_FILE"
        
        # Evaluation logic from working.txt:
        # If has_NPU is true and npu_free is true, choose device with NPU
        # Otherwise, choose device with lowest CPU load
        
        if [ "$HAS_NPU" = "true" ] && [ "$FREE_NPU" = "true" ]; then
            # Prefer NPU device
            if [ "$NPU_FOUND" = "false" ]; then
                BEST_DEVICE="$DEVICE"
                BEST_CHOICE="npu"
                NPU_FOUND="true"
                echo "  ✓ NPU CANDIDATE" >> "$LOG_FILE"
            fi
        else
            # Compare CPU load (only if no NPU found yet)
            if [ "$NPU_FOUND" = "false" ]; then
                # Convert CPU_LOAD to integer for comparison (remove decimal)
                CPU_INT=$(echo "$CPU_LOAD" | awk '{printf "%d", $1}')
                
                if [ "$CPU_INT" -lt "$LOWEST_CPU" ]; then
                    LOWEST_CPU="$CPU_INT"
                    BEST_DEVICE="$DEVICE"
                    BEST_CHOICE="cpu"
                    echo "  ✓ LOWEST CPU SO FAR" >> "$LOG_FILE"
                fi
            fi
        fi
        
        echo "" >> "$LOG_FILE"
    fi
done < "$BID_FILE"

# Print final decision
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') ORCHESTRATOR DECISION" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

if [ "$BEST_CHOICE" = "npu" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ NPU chosen: $BEST_DEVICE" >> "$LOG_FILE"
    echo ""
    echo "✓ NPU chosen: $BEST_DEVICE"
    echo ""
elif [ "$BEST_CHOICE" = "cpu" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Lowest CPU load chosen: $BEST_DEVICE (CPU: ${LOWEST_CPU}%)" >> "$LOG_FILE"
    echo ""
    echo "✓ Lowest CPU load chosen: $BEST_DEVICE (CPU: ${LOWEST_CPU}%)"
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
