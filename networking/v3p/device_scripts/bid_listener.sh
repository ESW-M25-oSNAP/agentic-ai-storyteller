#!/system/bin/sh
# Bid Listener - Listens for bid requests and responds with LinUCB score
# This runs continuously on each device in the mesh network

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/bid_listener.log"
BID_PORT=5001
LINUCB_BIN="/data/local/tmp/lini"
STATE_A="/data/local/tmp/state_A.dat"
STATE_B="/data/local/tmp/state_B.dat"
PENDING_BIDS_FILE="/data/local/tmp/pending_bids.txt"

# Parse device name
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid listener starting on port $BID_PORT" >> "$LOG_FILE"

# Initialize pending bids file
touch "$PENDING_BIDS_FILE"

# Start listening for bid requests
while true; do
    # Listen on port 5001 for bid requests
    REQUEST=$(echo "" | nc -l -p $BID_PORT -w 5 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$REQUEST" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received bid request: $REQUEST" >> "$LOG_FILE"
        
        # Check if it's a bid request
        if echo "$REQUEST" | grep -q "BID_REQUEST"; then
            # Extract orchestrator device name and prompt length from request
            ORCHESTRATOR_NAME=$(echo "$REQUEST" | grep -o 'from:[^|]*' | cut -d':' -f2)
            PROMPT_LENGTH=$(echo "$REQUEST" | grep -o 'prompt_length:[0-9]*' | cut -d':' -f2)
            
            # Default to 100 if not provided
            if [ -z "$PROMPT_LENGTH" ]; then
                PROMPT_LENGTH=100
            fi
            
            if [ -n "$ORCHESTRATOR_NAME" ]; then
                # Look up orchestrator IP from peers array in config file
                # Search for the peer with matching name and extract its IP
                ORCHESTRATOR_IP=$(grep -A2 "\"name\"[[:space:]]*:[[:space:]]*\"$ORCHESTRATOR_NAME\"" "$CONFIG_FILE" | grep '"ip"' | sed 's/.*"\([^"]*\)".*/\1/')
                
                # If not in peers, check if it's this device's own name (get IP from system)
                if [ -z "$ORCHESTRATOR_IP" ] && [ "$ORCHESTRATOR_NAME" = "$DEVICE_NAME" ]; then
                    ORCHESTRATOR_IP=$(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
                fi
                
                if [ -z "$ORCHESTRATOR_IP" ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] WARNING: Could not find IP for orchestrator $ORCHESTRATOR_NAME" >> "$LOG_FILE"
                    continue
                fi
                
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Orchestrator $ORCHESTRATOR_NAME IP: $ORCHESTRATOR_IP" >> "$LOG_FILE"
                
                # Collect metrics
                METRICS=$(sh "$MESH_DIR/collect_metrics.sh")
                
                # Parse metrics
                CPU_LOAD=$(echo "$METRICS" | cut -d',' -f3)
                RAM_LOAD=$(echo "$METRICS" | cut -d',' -f4)
                
                # Generate BidID (timestamp-based)
                BID_ID="bid_$(date +%s%N | cut -b1-13)_${DEVICE_NAME}"
                
                # Normalize features and build feature vector
                # Features: [1.0, cpu_load/100, ram_load/100, prompt_length/1000]
                CPU_NORM=$(echo "$CPU_LOAD" | awk '{printf "%.4f", $1/100}')
                RAM_NORM=$(echo "$RAM_LOAD" | awk '{printf "%.4f", $1/100}')
                PROMPT_NORM=$(echo "$PROMPT_LENGTH" | awk '{printf "%.4f", $1/1000}')
                
                # Call LinUCB solver to get score (with state file paths)
                SCORE=$($LINUCB_BIN score $STATE_A $STATE_B $CPU_NORM $RAM_NORM $PROMPT_NORM 2>/dev/null)
                
                if [ $? -eq 0 ] && [ -n "$SCORE" ]; then
                    # Store features in pending bids for later feedback
                    echo "$BID_ID,$CPU_NORM,$RAM_NORM,$PROMPT_NORM,$(date +%s)" >> "$PENDING_BIDS_FILE"
                    
                    # Create bid response with BidID and Score
                    BID_RESPONSE="BID_RESPONSE|device:$DEVICE_NAME|bid_id:$BID_ID|score:$SCORE"
                    
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid to $ORCHESTRATOR_IP: $BID_RESPONSE (cpu:$CPU_LOAD ram:$RAM_LOAD prompt:$PROMPT_LENGTH)" >> "$LOG_FILE"
                    
                    # Send bid response to orchestrator on port 5002
                    echo "$BID_RESPONSE" | nc -w 2 "$ORCHESTRATOR_IP" 5002 >> "$LOG_FILE" 2>&1
                    
                    if [ $? -eq 0 ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid sent successfully (BidID: $BID_ID, Score: $SCORE)" >> "$LOG_FILE"
                    else
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Failed to send bid" >> "$LOG_FILE"
                    fi
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ERROR: LinUCB solver failed" >> "$LOG_FILE"
                fi
            fi
        fi
    fi
    
    sleep 1
done
