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

# Start nc in background and capture pid (more robust than the subshell+timeout race)
nc -l -p $BID_RESPONSE_PORT > "$BID_FILE" 2>/dev/null &
NC_PID=$!

# Ensure listener has started
sleep 1

# After TIMEOUT seconds, kill it if still running
( sleep $TIMEOUT; kill $NC_PID 2>/dev/null ) &

sleep 1

# Broadcast bid request to all peers with prompt_length
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Broadcasting BID_REQUEST to all peers" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

for peer_ip in $PEER_IPS; do
    if [ -n "$peer_ip" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid request to $peer_ip" >> "$LOG_FILE"
        
        # Send bid request with device name (not IP) and prompt_length on port 5001
        BID_REQUEST="BID_REQUEST|from:$DEVICE_NAME|prompt_length:$PROMPT_LENGTH"
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

# Wait for responses (up to TIMEOUT seconds) or until all peers replied
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Waiting for bid responses..." >> "$LOG_FILE"

# Determine number of peers expected (non-empty entries in PEER_IPS)
EXPECTED=$(echo "$PEER_IPS" | tr ' ' '\n' | grep -v '^$' | wc -l)

if [ "$(echo "$EXPECTED" | tr -d '[:space:]')" -eq 0 ]; then
    # No peers configured — proceed after a short pause
    sleep 1
else
    START_TS=$(date +%s)
    END_TS=$((START_TS + TIMEOUT))

    while [ "$(date +%s)" -lt "$END_TS" ]; do
        COUNT=$(grep -c "BID_RESPONSE" "$BID_FILE" 2>/dev/null || true)
        if [ "$COUNT" -ge "$EXPECTED" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received all $COUNT/$EXPECTED bids early" >> "$LOG_FILE"
            break
        fi
        sleep 1
    done
fi

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
echo "" >> "$LOG_FILE"

if [ -n "$BEST_DEVICE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Lowest score chosen: $BEST_DEVICE (score: $LOWEST_SCORE, bid_id: $BEST_BID_ID)" >> "$LOG_FILE"
    echo ""
    echo "✓ Winner: $BEST_DEVICE (score: $LOWEST_SCORE)"
    echo "BidID: $BEST_BID_ID"
    echo ""
    
    # Execute SLM and measure latency
    echo "" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SLM EXECUTION PHASE" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Executing SLM on $BEST_DEVICE..." >> "$LOG_FILE"
    echo "Executing SLM on $BEST_DEVICE..."
    
    # Get prompt from command line args (passed by trigger_orchestrator.sh)
    PROMPT="$2"
    if [ -z "$PROMPT" ]; then
        PROMPT="Hello, how are you?"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') Prompt: $PROMPT" >> "$LOG_FILE"
    
    START_TIME=$(date +%s)
    
    # Execute on CPU using llama.cpp
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CPU EXEC] Starting CPU execution..." >> "$LOG_FILE"
    
    cd /data/local/tmp/cppllama-bundle/llama.cpp
    export LD_LIBRARY_PATH=$PWD/build/bin
    
    # Run llama-cli and save full output
    TEMP_OUTPUT="/data/local/tmp/llama_output_$$.txt"
    ./build/bin/llama-cli -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p "$PROMPT" -n 1000 -no-cnv > "$TEMP_OUTPUT" 2>&1
    
    # Extract ONLY the actual response text
    # The response line starts with the prompt followed by the answer
    # Example: "what is a banana? a banana is a type of food..."
    # It appears between "generate:" and "llama_perf_sampler"
    
    RESULT=$(sed -n '/^generate:/,/^llama_perf_sampler/p' "$TEMP_OUTPUT" | \
             grep -v "^generate:" | \
             grep -v "^llama_perf" | \
             grep -v "^sampler" | \
             grep -v "^$" | \
             grep -v "^common_" | \
             grep -v "^load:" | \
             head -3 | \
             tail -1)
    
    # Remove the prompt from the beginning if present
    if echo "$RESULT" | grep -q "^$PROMPT"; then
        RESULT=$(echo "$RESULT" | sed "s/^$PROMPT *//")
    fi
    
    # Save full output to log for debugging
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] Full llama output:" >> "$LOG_FILE"
    cat "$TEMP_OUTPUT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Cleanup temp file
    rm -f "$TEMP_OUTPUT"
    
    # Final check and cleanup
    RESULT=$(echo "$RESULT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$RESULT" ] || [ ${#RESULT} -lt 5 ]; then
        RESULT="[Could not extract response - see full output in logs]"
    fi
    
    END_TIME=$(date +%s)
    ACTUAL_LATENCY=$((END_TIME - START_TIME))
    
    echo "" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ SLM execution completed in ${ACTUAL_LATENCY}s" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ FULL Generated Response:" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')    $RESULT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo ""
    echo "========================================="
    echo "✓ Execution completed in ${ACTUAL_LATENCY}s"
    echo "✓ FULL RESPONSE:"
    echo "$RESULT"
    echo "========================================="
    echo ""
    
    # Send feedback to winner device (if not self)
    echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') FEEDBACK PHASE" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
    
    if [ "$BEST_DEVICE" != "$DEVICE_NAME" ] && [ "$BEST_BID_ID" != "self" ]; then
        # Get winner device IP from peers array
        WINNER_IP=$(grep -A2 "\"name\"[[:space:]]*:[[:space:]]*\"$BEST_DEVICE\"" "$CONFIG_FILE" | grep '"ip"' | sed 's/.*"\([^"]*\)".*/\1/')
        
        if [ -n "$WINNER_IP" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Sending feedback to $BEST_DEVICE at $WINNER_IP..." >> "$LOG_FILE"
            echo "Sending feedback to $BEST_DEVICE..."
            
            FEEDBACK_PACKET="FEEDBACK|bid_id:$BEST_BID_ID|latency:$ACTUAL_LATENCY"
            echo "$FEEDBACK_PACKET" | nc -w 2 "$WINNER_IP" 5003 >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Feedback sent successfully" >> "$LOG_FILE"
                echo "✓ Feedback sent successfully"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') ✗ Failed to send feedback" >> "$LOG_FILE"
                echo "✗ Failed to send feedback"
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Could not find IP for winner $BEST_DEVICE" >> "$LOG_FILE"
            echo "⚠ WARNING: Could not find IP for winner $BEST_DEVICE"
        fi
    else
        # Self execution - train directly
        echo "$(date '+%Y-%m-%d %H:%M:%S') Self-execution, training own model..." >> "$LOG_FILE"
        echo "Self-execution, training own model..."
        
        # Lookup features from pending bids (self bid)
        # Self bids are stored with normalized features
        if [ "$BEST_BID_ID" = "self" ]; then
            # Train with current features
            TRAIN_OUTPUT=$($LINUCB_BIN train $STATE_A $STATE_B $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_LATENCY 2>&1)
            
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ LinUCB model updated (self-training)" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S')    Features: cpu=$CPU_NORM, ram=$RAM_NORM, prompt=$PROMPT_NORM" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S')    Actual latency: ${ACTUAL_LATENCY}s" >> "$LOG_FILE"
                echo "✓ Model updated with actual latency: ${ACTUAL_LATENCY}s"
                echo "   Features: cpu=$CPU_NORM, ram=$RAM_NORM, prompt=$PROMPT_NORM"
            fi
        fi
    fi
    echo "" >> "$LOG_FILE"
    echo ""
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✗ No suitable device found" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo ""
    echo "✗ No suitable device found"
    echo ""
fi

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') ORCHESTRATION COMPLETE" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Cleanup
rm -f "$BID_FILE"

exit 0
