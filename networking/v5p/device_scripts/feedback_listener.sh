#!/system/bin/sh
# Feedback Listener - Receives actual latency and updates Multi-LinUCB model
# Runs continuously on each device

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/feedback_listener.log"
FEEDBACK_PORT=5003
MULTILIN_BIN="/data/local/tmp/multilin"
STATE_A="/data/local/tmp/state_A.dat"
STATE_B="/data/local/tmp/state_B.dat"
PENDING_BIDS_FILE="$MESH_DIR/pending_bids.txt"

# Parse device name
CONFIG_FILE="$MESH_DIR/device_config.json"
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Feedback listener starting on port $FEEDBACK_PORT" >> "$LOG_FILE"

# Initialize pending bids file if doesn't exist
touch "$PENDING_BIDS_FILE"

# Start listening for feedback
while true; do
    # Listen on port 5003 for feedback packets
    FEEDBACK=$(echo "" | nc -l -p $FEEDBACK_PORT -w 5 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$FEEDBACK" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received feedback: $FEEDBACK" >> "$LOG_FILE"
        
        # Check if it's a feedback packet
        if echo "$FEEDBACK" | grep -q "FEEDBACK"; then
            echo "" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') ========================================" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] FEEDBACK RECEIVED" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') ========================================" >> "$LOG_FILE"
            
            # Extract BidID and actual latency from feedback
            BID_ID=$(echo "$FEEDBACK" | grep -o 'bid_id:[^|]*' | cut -d':' -f2)
            ACTUAL_LATENCY=$(echo "$FEEDBACK" | grep -o 'latency:[^|]*' | cut -d':' -f2)
            
            if [ -n "$BID_ID" ] && [ -n "$ACTUAL_LATENCY" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Feedback for BidID: $BID_ID" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Actual Latency: $ACTUAL_LATENCY seconds" >> "$LOG_FILE"
                echo "" >> "$LOG_FILE"
                
                # Lookup features from pending bids
                BID_ENTRY=$(grep "^$BID_ID," "$PENDING_BIDS_FILE")
                
                if [ -n "$BID_ENTRY" ]; then
                    # Extract features: BidID,cpu_norm,ram_norm,prompt_norm,timestamp
                    CPU_NORM=$(echo "$BID_ENTRY" | cut -d',' -f2)
                    RAM_NORM=$(echo "$BID_ENTRY" | cut -d',' -f3)
                    PROMPT_NORM=$(echo "$BID_ENTRY" | cut -d',' -f4)
                    
                    # Extract TTFT and Speed from feedback (assuming format: FEEDBACK|bid_id:X|ttft:Y|speed:Z)
                    ACTUAL_TTFT=$(echo "$FEEDBACK" | grep -o 'ttft:[^|]*' | cut -d':' -f2)
                    ACTUAL_SPEED=$(echo "$FEEDBACK" | grep -o 'speed:[^|]*' | cut -d':' -f2)
                    
                    # Fallback to latency if TTFT/Speed not provided (backward compatibility)
                    if [ -z "$ACTUAL_TTFT" ] || [ -z "$ACTUAL_SPEED" ]; then
                        ACTUAL_LATENCY=$(echo "$FEEDBACK" | grep -o 'latency:[^|]*' | cut -d':' -f2)
                        # Assume TTFT is 30% of latency, speed derived from rest
                        ACTUAL_TTFT=$(echo "$ACTUAL_LATENCY" | awk '{printf "%.2f", $1 * 0.3}')
                        ACTUAL_SPEED=$(echo "$ACTUAL_LATENCY" | awk '{printf "%.2f", 100 / ($1 * 0.7)}')  # tokens/sec estimate
                    fi
                    
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Found features from pending bids:" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   CPU normalized: $CPU_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   RAM normalized: $RAM_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   Prompt normalized: $PROMPT_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   TTFT: $ACTUAL_TTFT, Speed: $ACTUAL_SPEED tok/s" >> "$LOG_FILE"
                    echo "" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Training Multi-LinUCB model..." >> "$LOG_FILE"
                    
                    # Train Multi-LinUCB model with TTFT and Speed
                    TRAIN_OUTPUT=$($MULTILIN_BIN train $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_TTFT $ACTUAL_SPEED 2>&1)
                    
                    if [ $? -eq 0 ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ Multi-LinUCB model updated successfully" >> "$LOG_FILE"
                        echo "" >> "$LOG_FILE"
                        
                        # Remove bid from pending bids
                        grep -v "^$BID_ID," "$PENDING_BIDS_FILE" > "${PENDING_BIDS_FILE}.tmp"
                        mv "${PENDING_BIDS_FILE}.tmp" "$PENDING_BIDS_FILE"
                        
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ Cleaned up pending bid: $BID_ID" >> "$LOG_FILE"
                    else
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✗ ERROR: Multi-LinUCB training failed" >> "$LOG_FILE"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]    Error: $TRAIN_OUTPUT" >> "$LOG_FILE"
                    fi
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ⚠ WARNING: BidID $BID_ID not found in pending bids" >> "$LOG_FILE"
                fi
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✗ ERROR: Invalid feedback format" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]    Missing bid_id or latency/ttft/speed in packet" >> "$LOG_FILE"
            fi
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') ========================================" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        fi
    fi
    
    sleep 1
done
