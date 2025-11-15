#!/system/bin/sh
# Feedback Listener - Receives feedback and trains LinUCB model
# This runs continuously on each device to receive actual latency feedback

MESH_DIR="/sdcard/mesh_network"
LOG_FILE="$MESH_DIR/feedback_listener.log"
FEEDBACK_PORT=5003
LINUCB_BIN="/data/local/tmp/lini"
STATE_A="/data/local/tmp/state_A.dat"
STATE_B="/data/local/tmp/state_B.dat"
PENDING_BIDS_FILE="/data/local/tmp/pending_bids.txt"

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
                    
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Found features from pending bids:" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   CPU normalized: $CPU_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   RAM normalized: $RAM_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]   Prompt normalized: $PROMPT_NORM" >> "$LOG_FILE"
                    echo "" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Training LinUCB model..." >> "$LOG_FILE"
                    
                    # Train LinUCB model
                    TRAIN_OUTPUT=$($LINUCB_BIN train $STATE_A $STATE_B $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_LATENCY 2>&1)
                    
                    if [ $? -eq 0 ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ LinUCB model updated successfully" >> "$LOG_FILE"
                        echo "" >> "$LOG_FILE"
                        
                        # Remove bid from pending bids
                        grep -v "^$BID_ID," "$PENDING_BIDS_FILE" > "${PENDING_BIDS_FILE}.tmp"
                        mv "${PENDING_BIDS_FILE}.tmp" "$PENDING_BIDS_FILE"
                        
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ Cleaned up pending bid: $BID_ID" >> "$LOG_FILE"
                    else
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✗ ERROR: LinUCB training failed" >> "$LOG_FILE"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]    Error: $TRAIN_OUTPUT" >> "$LOG_FILE"
                    fi
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ⚠ WARNING: BidID $BID_ID not found in pending bids" >> "$LOG_FILE"
                fi
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✗ ERROR: Invalid feedback format" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME]    Missing bid_id or latency in packet" >> "$LOG_FILE"
            fi
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') ========================================" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        fi
    fi
    
    sleep 1
done
