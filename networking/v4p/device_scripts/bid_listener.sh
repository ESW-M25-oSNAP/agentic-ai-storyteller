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
PROMPT_EXEC_PORT=5004
NPU_FLAG_FILE="$MESH_DIR/npu_free.flag"

# Parse device name
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid listener starting on port $BID_PORT" >> "$LOG_FILE"

# Initialize pending bids file
touch "$PENDING_BIDS_FILE"
    
# Initialize NPU free flag (true if device has NPU, false otherwise)
HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')
if [ "$HAS_NPU" = "true" ]; then
    echo "true" > "$NPU_FLAG_FILE"
else
    echo "false" > "$NPU_FLAG_FILE"
fi

# Function to execute NPU prompt
execute_npu_prompt() {
    local prompt="$1"
    local orchestrator_device="$2"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Starting NPU execution..." >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Prompt: $prompt" >> "$LOG_FILE"
    
    # Set NPU as busy
    echo "false" > "$MESH_DIR/npu_free.flag"
    
    # Format prompt for Llama 3.2 chat template
    FORMATTED_PROMPT="<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n${prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    # Execute on NPU (run in background and capture output)
    (
        START_TIME=$(date +%s)
        
        cd /data/local/tmp/genie-bundle
        export LD_LIBRARY_PATH=$PWD
        export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned
        
        # Capture full output to temp file
        TEMP_OUTPUT="/data/local/tmp/npu_output_$$.txt"
        ./genie-t2t-run -c genie_config.json -p "$FORMATTED_PROMPT" > "$TEMP_OUTPUT" 2>&1
        
        # Extract response (last 20 lines, clean up)
        RESULT=$(tail -20 "$TEMP_OUTPUT" | grep -v "^$" | grep -v "Loading" | grep -v "Initializing" | head -10 | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        END_TIME=$(date +%s)
        LATENCY=$((END_TIME - START_TIME))
        
        echo "" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ========================================" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Execution complete in ${LATENCY}s" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ========================================" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU OUTPUT] ${RESULT:0:500}" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ========================================" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Log full output for debugging
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU FULL OUTPUT]:" >> "$LOG_FILE"
        cat "$TEMP_OUTPUT" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Send result back to orchestrator on port 5005
        ORCHESTRATOR_IP=$(grep -A2 "\"name\"[[:space:]]*:[[:space:]]*\"$orchestrator_device\"" "$MESH_DIR/device_config.json" | grep '"ip"' | sed 's/.*"\([^"]*\)".*/\1/')
        
        if [ -n "$ORCHESTRATOR_IP" ]; then
            RESULT_MSG="NPU_RESULT|from:$DEVICE_NAME|latency:$LATENCY|result:$RESULT"
            echo "$RESULT_MSG" | nc -w 2 "$ORCHESTRATOR_IP" 5005 >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Result sent to orchestrator" >> "$LOG_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] WARNING: Failed to send result to orchestrator" >> "$LOG_FILE"
            fi
        fi
        
        # Cleanup
        rm -f "$TEMP_OUTPUT"
        
        # Free up NPU
        echo "true" > "$MESH_DIR/npu_free.flag"
    ) &
}

# Function to execute CPU prompt (using llama.cpp)
execute_cpu_prompt() {
    local prompt="$1"
    local orchestrator_device="$2"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Starting CPU execution..." >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Prompt: $prompt" >> "$LOG_FILE"
    
    # Execute on CPU (run in background and capture output)
    (
        cd /data/local/tmp/cppllama-bundle/llama.cpp
        export LD_LIBRARY_PATH=$PWD/build/bin
        
        # Run llama-cli and capture full output
        FULL_OUTPUT=$(./build/bin/llama-cli -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p "$prompt" -no-cnv 2>&1)
        
        # Extract generated text by removing performance stats lines
        RESULT=$(echo "$FULL_OUTPUT" | grep -v "llama_perf" | grep -v "llama_memory" | grep -v "load time" | grep -v "eval time" | grep -v "sampling time" | grep -v "^\[" | grep -v "^$" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # If result is empty, try alternative: get everything before the first llama_perf line
        if [ -z "$RESULT" ] || [ "$RESULT" = " " ]; then
            RESULT=$(echo "$FULL_OUTPUT" | sed '/llama_perf/,$d' | grep -v "^\[" | grep -v "^$" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Execution complete" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Generated text: ${RESULT:0:200}..." >> "$LOG_FILE"
    ) &
}

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
                
                # Collect metrics (includes NPU info)
                METRICS=$(sh "$MESH_DIR/collect_metrics.sh")
                
                # Parse metrics
                HAS_NPU=$(echo "$METRICS" | cut -d',' -f1)
                FREE_NPU=$(echo "$METRICS" | cut -d',' -f2)
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
                    
                    # Create bid response with BidID, Score, and NPU info (single line)
                    BID_RESPONSE="BID_RESPONSE|device:$DEVICE_NAME|bid_id:$BID_ID|score:$SCORE|has_npu:$HAS_NPU|free_npu:$FREE_NPU"
                    
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid to $ORCHESTRATOR_IP: $BID_RESPONSE (npu:$HAS_NPU/$FREE_NPU cpu:$CPU_LOAD ram:$RAM_LOAD prompt:$PROMPT_LENGTH)" >> "$LOG_FILE"
                    
                    # Send bid response to orchestrator on port 5002 with retry
                    SEND_SUCCESS=0
                    for ATTEMPT in 1 2 3; do
                        printf "%s\n" "$BID_RESPONSE" | nc -w 3 "$ORCHESTRATOR_IP" 5002 >> "$LOG_FILE" 2>&1
                        RC=$?
                        
                        if [ "$RC" -eq 0 ]; then
                            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid sent successfully on attempt $ATTEMPT (BidID: $BID_ID, Score: $SCORE, NPU: $HAS_NPU/$FREE_NPU)" >> "$LOG_FILE"
                            SEND_SUCCESS=1
                            break
                        else
                            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] WARNING: Failed to send bid on attempt $ATTEMPT (nc rc=$RC)" >> "$LOG_FILE"
                            sleep 0.5
                        fi
                    done
                    
                    if [ "$SEND_SUCCESS" -eq 0 ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ERROR: Failed to send bid after 3 attempts to $ORCHESTRATOR_IP" >> "$LOG_FILE"
                    fi
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ERROR: LinUCB solver failed" >> "$LOG_FILE"
                fi
            fi
        fi
    fi
    
    sleep 1
done &

# Start listener for prompt execution requests on port 5004
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting prompt execution listener on port $PROMPT_EXEC_PORT" >> "$LOG_FILE"

while true; do
    # Listen on port 5004 for prompt execution requests
    EXEC_REQUEST=$(echo "" | nc -l -p $PROMPT_EXEC_PORT -w 5 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$EXEC_REQUEST" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received execution request: $EXEC_REQUEST" >> "$LOG_FILE"
        
        # Parse execution request
        if echo "$EXEC_REQUEST" | grep -q "PROMPT_EXEC"; then
            ORCHESTRATOR=$(echo "$EXEC_REQUEST" | grep -o 'from:[^|]*' | cut -d':' -f2)
            EXEC_MODE=$(echo "$EXEC_REQUEST" | grep -o 'mode:[^|]*' | cut -d':' -f2)
            PROMPT=$(echo "$EXEC_REQUEST" | grep -o 'prompt:[^|]*' | cut -d':' -f2-)
            
            if [ -n "$PROMPT" ] && [ -n "$EXEC_MODE" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Executing prompt in $EXEC_MODE mode from $ORCHESTRATOR" >> "$LOG_FILE"
                
                if [ "$EXEC_MODE" = "NPU" ]; then
                    execute_npu_prompt "$PROMPT" "$ORCHESTRATOR"
                elif [ "$EXEC_MODE" = "CPU" ]; then
                    execute_cpu_prompt "$PROMPT" "$ORCHESTRATOR"
                fi
            fi
        fi
    fi
    
    sleep 1
done &

# Wait for all background processes
wait
