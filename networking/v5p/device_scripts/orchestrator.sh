#!/system/bin/sh
# Orchestrator Script - Requests bids and selects device with lowest Multi-LinUCB score
# Usage: sh orchestrator.sh [prompt_length] ["<prompt>"]

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/orchestrator.log"
BID_RESPONSE_PORT=5002
TIMEOUT=30
MULTILIN_BIN="/data/local/tmp/multilin"
STATE_A="/data/local/tmp/state_A.dat"
STATE_B="/data/local/tmp/state_B.dat"

# Get prompt length and prompt from arguments
PROMPT_LENGTH=${1:-100}
PROMPT=${2:-"Hello, how are you?"}

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') Orchestrator Starting" >> "$LOG_FILE"
echo "  Prompt Length: $PROMPT_LENGTH" >> "$LOG_FILE"
echo "  Prompt: $PROMPT" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Parse device info
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
DEVICE_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
if [ -z "$DEVICE_IP" ]; then
    DEVICE_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
if [ -z "$DEVICE_IP" ]; then
    DEVICE_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
fi
if [ -z "$DEVICE_IP" ]; then
    DEVICE_IP=""
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Running on IP: $DEVICE_IP" >> "$LOG_FILE"

# Get list of peer IPs
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Collect self metrics first to check for NPU
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Collecting self metrics..." >> "$LOG_FILE"
SELF_METRICS=$(sh "$MESH_DIR/collect_metrics.sh" 2>/dev/null)
SELF_HAS_NPU=$(echo "$SELF_METRICS" | cut -d',' -f1)
SELF_FREE_NPU=$(echo "$SELF_METRICS" | cut -d',' -f2)
SELF_CPU_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f3)
SELF_RAM_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f4)

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Self metrics: has_npu=$SELF_HAS_NPU free_npu=$SELF_FREE_NPU cpu=$SELF_CPU_LOAD ram=$SELF_RAM_LOAD" >> "$LOG_FILE"

# Check if self has free NPU - if so, execute locally without orchestration
if [ "$SELF_HAS_NPU" = "true" ] && [ "$SELF_FREE_NPU" = "true" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ Self device has FREE NPU - executing locally" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Skipping bid collection, executing on self NPU" >> "$LOG_FILE"
    echo ""
    echo "✓ Winner: $DEVICE_NAME (NPU - Local)"
    echo ""
    
    # Get prompt
    PROMPT="$2"
    if [ -z "$PROMPT" ]; then
        PROMPT="Hello, how are you?"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Prompt: $PROMPT" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Starting NPU execution locally..." >> "$LOG_FILE"
    
    # Set NPU as busy
    echo "false" > "$MESH_DIR/npu_free.flag"
    
    # Format prompt for Llama 3.2 chat template
    FORMATTED_PROMPT="<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n${PROMPT}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    START_TIME=$(date +%s)
    
    # Execute on NPU (run in background and capture output)
    (
        cd /data/local/tmp/genie-bundle 2>/dev/null
        export LD_LIBRARY_PATH=$PWD
        export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned
        
        RESULT=$(./genie-t2t-run -c genie_config.json -p "$FORMATTED_PROMPT" 2>&1 | tail -20)
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Execution complete" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Result: $RESULT" >> "$LOG_FILE"
        
        # Free up NPU
        echo "true" > "$MESH_DIR/npu_free.flag"
    ) &
    
    END_TIME=$(date +%s)
    ACTUAL_LATENCY=$((END_TIME - START_TIME))
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ✓ NPU execution initiated locally (latency: ${ACTUAL_LATENCY}s)" >> "$LOG_FILE"
    echo ""
    echo "========================================="
    echo "✓ NPU execution initiated on self"
    echo "========================================="
    echo ""
    
    # Cleanup and exit
    rm -f "$BID_FILE" 2>/dev/null
    exit 0
fi

# If self doesn't have free NPU, proceed with orchestration - collect bids from peers
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] No free NPU on self - proceeding with orchestration" >> "$LOG_FILE"

# Create temporary file for bid responses
BID_FILE="$MESH_DIR/bids_temp.txt"
> "$BID_FILE"

# Start persistent bid response listener in background using a loop
# This accepts multiple connections on port 5002 until TIMEOUT
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting persistent bid response listener on port $BID_RESPONSE_PORT" >> "$LOG_FILE"

(
    LISTENER_START=$(date +%s)
    LISTENER_END=$((LISTENER_START + TIMEOUT))
    
    while [ "$(date +%s)" -lt "$LISTENER_END" ]; do
        # Use timeout wrapper to prevent infinite hangs on single connection
        timeout 5 nc -l -p $BID_RESPONSE_PORT 2>/dev/null >> "$BID_FILE"
        LISTEN_RC=$?
        
        # Exit code 124 = timeout (no data received)
        # Exit code 0 = received data
        # Exit code 1 = connection refused (retry)
        # Continue in all cases to keep accepting connections
        
        if [ "$LISTEN_RC" -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received bid response" >> "$LOG_FILE"
        fi
        
        # Short pause between accepts to avoid busy loop
        sleep 0.2
    done
) &

LISTENER_PID=$!

# Ensure listener has started
sleep 1

# Broadcast bid request to all peers with prompt_length and prompt
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Broadcasting BID_REQUEST to all peers" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

for peer_ip in $PEER_IPS; do
    if [ -n "$peer_ip" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid request to $peer_ip:5001" >> "$LOG_FILE"
        
        # Send bid request with retries for robustness
        # Include prompt for token prediction
        BID_REQUEST="BID_REQUEST|from:$DEVICE_NAME|prompt_length:$PROMPT_LENGTH|prompt:$PROMPT"
        RETRY_COUNT=0
        MAX_RETRIES=2
        
        while [ "$RETRY_COUNT" -le "$MAX_RETRIES" ]; do
            (
                printf "%s\n" "$BID_REQUEST" | nc -w 3 -q 1 "$peer_ip" 5001 >> "$LOG_FILE" 2>&1
                RC=$?
                if [ "$RC" -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid request sent to $peer_ip (attempt $((RETRY_COUNT+1)))" >> "$LOG_FILE"
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] WARNING: failed to send bid to $peer_ip (nc rc=$RC, attempt $((RETRY_COUNT+1))/$((MAX_RETRIES+1)))" >> "$LOG_FILE"
                fi
            ) &
            
            RETRY_COUNT=$((RETRY_COUNT + 1))
        done
    fi
done

# Normalize self features for Multi-LinUCB
CPU_NORM=$(echo "$SELF_CPU_LOAD" | awk '{printf "%.4f", $1/100}')
RAM_NORM=$(echo "$SELF_RAM_LOAD" | awk '{printf "%.4f", $1/100}')
PROMPT_NORM=$(echo "$PROMPT_LENGTH" | awk '{printf "%.4f", $1/1000}')

# Get self score from Multi-LinUCB (passes prompt for token prediction)
# Capture both stdout (score) and stderr (predicted tokens info)
MULTILIN_SELF_OUTPUT=$($MULTILIN_BIN score $CPU_NORM $RAM_NORM $PROMPT_NORM "$PROMPT" 2>&1)
SELF_SCORE=$(echo "$MULTILIN_SELF_OUTPUT" | tail -1)
SELF_PRED_TOKENS=$(echo "$MULTILIN_SELF_OUTPUT" | grep "Predicted tokens:" | awk '{print $3}')

# If no predicted tokens found, set to 0
if [ -z "$SELF_PRED_TOKENS" ]; then
    SELF_PRED_TOKENS=0
fi

if [ $? -eq 0 ] && [ -n "$SELF_SCORE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Self score: $SELF_SCORE (cpu:$SELF_CPU_LOAD ram:$SELF_RAM_LOAD pred_tokens:$SELF_PRED_TOKENS)" >> "$LOG_FILE"
    LOWEST_SCORE=$SELF_SCORE
    BEST_DEVICE="$DEVICE_NAME"
    BEST_BID_ID="self"
    BEST_PRED_TOKENS=$SELF_PRED_TOKENS
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] WARNING: Multi-LinUCB solver failed for self" >> "$LOG_FILE"
    LOWEST_SCORE=999999
    BEST_DEVICE=""
    BEST_BID_ID=""
    BEST_PRED_TOKENS=0
fi

# Wait for responses (up to TIMEOUT seconds) or until all peers replied
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Waiting for bid responses..." >> "$LOG_FILE"

# Determine number of peers expected (non-empty entries in PEER_IPS)
EXPECTED=$(echo "$PEER_IPS" | tr ' ' '\n' | grep -v '^$' | wc -l)

if [ "$(echo "$EXPECTED" | tr -d '[:space:]')" -eq 0 ]; then
    # No peers configured — proceed after a short pause
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] No peers configured, using self" >> "$LOG_FILE"
    sleep 1
else
    START_TS=$(date +%s)
    END_TS=$((START_TS + TIMEOUT))
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Waiting for $EXPECTED peer bids (timeout: ${TIMEOUT}s)" >> "$LOG_FILE"

    while [ "$(date +%s)" -lt "$END_TS" ]; do
        COUNT=$(grep -c "BID_RESPONSE" "$BID_FILE" 2>/dev/null || true)
        ELAPSED=$(($(date +%s) - START_TS))
        
        if [ "$COUNT" -ge "$EXPECTED" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received all $COUNT/$EXPECTED bids (after ${ELAPSED}s)" >> "$LOG_FILE"
            break
        fi
        
        sleep 1
    done
    
    FINAL_COUNT=$(grep -c "BID_RESPONSE" "$BID_FILE" 2>/dev/null || true)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid collection complete: received $FINAL_COUNT/$EXPECTED bids" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Processing received bids" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Parse bid responses and select lowest score
# First pass: check for NPU devices with free NPU
NPU_DEVICE=""
NPU_BID_ID=""
SEND_TO_NPU="no"

if [ -s "$BID_FILE" ]; then
    while IFS= read -r bid_line; do
        if echo "$bid_line" | grep -q "BID_RESPONSE"; then
            DEVICE=$(echo "$bid_line" | grep -o 'device:[^|]*' | cut -d':' -f2)
            BID_ID=$(echo "$bid_line" | grep -o 'bid_id:[^|]*' | cut -d':' -f2)
            HAS_NPU=$(echo "$bid_line" | grep -o 'has_npu:[^|]*' | cut -d':' -f2)
            FREE_NPU=$(echo "$bid_line" | grep -o 'free_npu:[^|]*' | cut -d':' -f2)
            PRED_TOKENS=$(echo "$bid_line" | grep -o 'pred_tokens:[^|]*' | cut -d':' -f2)
            
            # If no predicted tokens in bid, set to 0
            if [ -z "$PRED_TOKENS" ]; then
                PRED_TOKENS=0
            fi
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') Bid from $DEVICE:" >> "$LOG_FILE"
            echo "  - bid_id: $BID_ID" >> "$LOG_FILE"
            echo "  - has_npu: $HAS_NPU, free_npu: $FREE_NPU" >> "$LOG_FILE"
            echo "  - predicted_tokens: $PRED_TOKENS" >> "$LOG_FILE"
            
            # Check for NPU availability
            if [ "$HAS_NPU" = "true" ] && [ "$FREE_NPU" = "true" ]; then
                echo "  ✓ NPU DEVICE FOUND" >> "$LOG_FILE"
                NPU_DEVICE="$DEVICE"
                NPU_BID_ID="$BID_ID"
                NPU_PRED_TOKENS="$PRED_TOKENS"
                SEND_TO_NPU="yes"
                break
            fi
            
            echo "" >> "$LOG_FILE"
        fi
    done < "$BID_FILE"
fi

# If no NPU device, proceed with Multi-LinUCB score selection
if [ "$SEND_TO_NPU" = "no" ] && [ -s "$BID_FILE" ]; then
    while IFS= read -r bid_line; do
        if echo "$bid_line" | grep -q "BID_RESPONSE"; then
            DEVICE=$(echo "$bid_line" | grep -o 'device:[^|]*' | cut -d':' -f2)
            BID_ID=$(echo "$bid_line" | grep -o 'bid_id:[^|]*' | cut -d':' -f2)
            SCORE=$(echo "$bid_line" | grep -o 'score:[^|]*' | cut -d':' -f2)
            PRED_TOKENS=$(echo "$bid_line" | grep -o 'pred_tokens:[^|]*' | cut -d':' -f2)
            
            # If no predicted tokens in bid, set to 0
            if [ -z "$PRED_TOKENS" ]; then
                PRED_TOKENS=0
            fi
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') Bid from $DEVICE:" >> "$LOG_FILE"
            echo "  - bid_id: $BID_ID" >> "$LOG_FILE"
            echo "  - score: $SCORE" >> "$LOG_FILE"
            echo "  - predicted_tokens: $PRED_TOKENS" >> "$LOG_FILE"
            
            # Compare scores (lower is better)
            SCORE_INT=$(echo "$SCORE" | awk '{printf "%d", $1 * 1000}')
            LOWEST_INT=$(echo "$LOWEST_SCORE" | awk '{printf "%d", $1 * 1000}')
            
            if [ "$SCORE_INT" -lt "$LOWEST_INT" ]; then
                LOWEST_SCORE=$SCORE
                BEST_DEVICE="$DEVICE"
                BEST_BID_ID="$BID_ID"
                BEST_PRED_TOKENS="$PRED_TOKENS"
                echo "  ✓ Lowest score so far" >> "$LOG_FILE"
            fi
            
            echo "" >> "$LOG_FILE"
        fi
    done < "$BID_FILE"
fi

# If NPU device found, use it
if [ "$SEND_TO_NPU" = "yes" ]; then
    BEST_DEVICE="$NPU_DEVICE"
    BEST_BID_ID="$NPU_BID_ID"
    BEST_PRED_TOKENS="$NPU_PRED_TOKENS"
fi

# Print final decision
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') ORCHESTRATOR DECISION" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

if [ -n "$BEST_DEVICE" ]; then
    if [ "$SEND_TO_NPU" = "yes" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ NPU device chosen: $BEST_DEVICE (bid_id: $BEST_BID_ID, predicted_tokens: $BEST_PRED_TOKENS)" >> "$LOG_FILE"
        echo ""
        echo "✓ Winner: $BEST_DEVICE (NPU)"
        echo "BidID: $BEST_BID_ID"
        echo "Predicted Tokens: $BEST_PRED_TOKENS"
        echo ""
        
        # NPU path: send prompt_exec and do not wait for feedback
        PROMPT="$2"
        if [ -z "$PROMPT" ]; then
            PROMPT="Hello, how are you?"
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [NPU EXEC] Sending prompt to NPU device $BEST_DEVICE (no feedback required)..." >> "$LOG_FILE"
        
        # Get target device IP from peers
        TARGET_IP=$(grep -A2 "\"name\"[[:space:]]*:[[:space:]]*\"$BEST_DEVICE\"" "$CONFIG_FILE" | grep '"ip"' | sed 's/.*"\([^"]*\)".*/\1/')
        
        if [ -n "$TARGET_IP" ]; then
            EXEC_MSG="PROMPT_EXEC|from:$DEVICE_NAME|mode:NPU|prompt:$PROMPT"
            echo "$EXEC_MSG" | nc -w 2 "$TARGET_IP" 5004 >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Prompt sent to NPU device, continuing..." >> "$LOG_FILE"
                echo "✓ Prompt sent to NPU device"
                echo ""
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') ✗ Failed to send prompt to NPU device" >> "$LOG_FILE"
                echo "✗ Failed to send prompt to NPU device"
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Could not find IP for NPU device $BEST_DEVICE" >> "$LOG_FILE"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Lowest score chosen: $BEST_DEVICE (score: $LOWEST_SCORE, bid_id: $BEST_BID_ID, predicted_tokens: $BEST_PRED_TOKENS)" >> "$LOG_FILE"
        echo ""
        echo "✓ Winner: $BEST_DEVICE (score: $LOWEST_SCORE)"
        echo "BidID: $BEST_BID_ID"
        echo "Predicted Tokens: $BEST_PRED_TOKENS"
        echo ""
        
        # Execute SLM and measure latency
        echo "" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') SLM EXECUTION PHASE" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') ----------------------------------------" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') Executing SLM on $BEST_DEVICE..." >> "$LOG_FILE"
        echo "Executing SLM on $BEST_DEVICE..."
        
        # Get prompt from command line args
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
            if [ "$BEST_BID_ID" = "self" ]; then
                # Train with current features
                TRAIN_OUTPUT=$($MULTILIN_BIN train $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_TTFT $ACTUAL_SPEED 2>&1)
                
                if [ $? -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') ✓ Multi-LinUCB model updated (self-training)" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S')    Features: cpu=$CPU_NORM, ram=$RAM_NORM, prompt=$PROMPT_NORM" >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S')    Actual TTFT: ${ACTUAL_TTFT}s, Speed: ${ACTUAL_SPEED} tok/s" >> "$LOG_FILE"
                    echo "✓ Model updated with actual metrics"
                    echo "   TTFT: ${ACTUAL_TTFT}s, Speed: ${ACTUAL_SPEED} tok/s"
                    echo "   Features: cpu=$CPU_NORM, ram=$RAM_NORM, prompt=$PROMPT_NORM"
                fi
            fi
        fi
        echo "" >> "$LOG_FILE"
        echo ""
    fi
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

# Cleanup - kill listener and temp file
kill $LISTENER_PID 2>/dev/null || true
sleep 0.5
rm -f "$BID_FILE"

exit 0
