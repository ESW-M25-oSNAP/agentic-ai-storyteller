#!/system/bin/sh
# Simple Mesh Network Node for Android
# Uses Android's toybox netcat

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/mesh.log"
MODE_FLAG="$MESH_DIR/mode.flag"
ORCH_LOG="$MESH_DIR/orchestrator.log"
ORCH_CMD="$MESH_DIR/orchestrator.cmd"

cd "$MESH_DIR" || exit 1

# Parse config
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
LISTEN_PORT=$(grep -o '"listen_port"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | sed 's/.*: *\([0-9]*\)/\1/')
HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')

# Initialize NPU_free flag (true initially if device has NPU)
if [ "$HAS_NPU" = "true" ]; then
    NPU_FREE="true"
else
    NPU_FREE="false"
fi
echo "$NPU_FREE" > "$MESH_DIR/npu_free.flag"

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting mesh node on port $LISTEN_PORT (has_npu=$HAS_NPU, npu_free=$NPU_FREE)" >> "$LOG_FILE"

# Extract peer info (simplified - get all IPs and ports)
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PEER_PORTS=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -v listen_port | sed 's/.*: *\([0-9]*\)/\1/')
PEER_NAMES=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Helper function to get system metrics
get_cpu_load() {
    # Get CPU load (simplified - use uptime or /proc/loadavg)
    if [ -f /proc/loadavg ]; then
        awk '{print $1}' /proc/loadavg
    else
        echo "0.5"
    fi
}

get_ram_load() {
    # Get RAM usage percentage (simplified)
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2} END {print int((total-avail)*100/total)}' /proc/meminfo
    else
        echo "50"
    fi
}

get_npu_free() {
    # Read current NPU_free status
    if [ -f "$MESH_DIR/npu_free.flag" ]; then
        cat "$MESH_DIR/npu_free.flag"
    else
        echo "$NPU_FREE"
    fi
}

# Function to create bid message
create_bid() {
    local cpu_load=$(get_cpu_load)
    local ram_load=$(get_ram_load)
    local npu_free=$(get_npu_free)
    echo "{\"type\":\"bid\",\"from\":\"$DEVICE_NAME\",\"has_npu\":$HAS_NPU,\"cpu_load\":$cpu_load,\"ram_load\":$ram_load,\"npu_free\":$npu_free}"
}

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
        cd /data/local/tmp/genie-bundle
        export LD_LIBRARY_PATH=$PWD
        export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned
        RESULT=$(./genie-t2t-run -c genie_config.json -p "$FORMATTED_PROMPT" 2>&1 | tail -20)
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [NPU EXEC] Execution complete" >> "$LOG_FILE"
        
        # Send result back to orchestrator
        send_result_to_orchestrator "$orchestrator_device" "NPU" "$RESULT"
        
        # Free up NPU
        echo "true" > "$MESH_DIR/npu_free.flag"
    ) &
}

# Function to execute CPU prompt (using host_harness.py output capture pattern)
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
        # Note: Removed -n 5 limit to allow full response generation
        FULL_OUTPUT=$(./build/bin/llama-cli -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p "$prompt" -no-cnv 2>&1)
        
        # Extract generated text by removing performance stats lines
        # Filter out lines containing: llama_perf, llama_memory, load time, eval time, sampling time, etc.
        RESULT=$(echo "$FULL_OUTPUT" | grep -v "llama_perf" | grep -v "llama_memory" | grep -v "load time" | grep -v "eval time" | grep -v "sampling time" | grep -v "^\[" | grep -v "^$" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # If result is empty, try alternative: get everything before the first llama_perf line
        if [ -z "$RESULT" ] || [ "$RESULT" = " " ]; then
            RESULT=$(echo "$FULL_OUTPUT" | sed '/llama_perf/,$d' | grep -v "^\[" | grep -v "^$" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Execution complete" >> "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Generated text: ${RESULT:0:200}..." >> "$LOG_FILE"
        
        # Send result back to orchestrator
        send_result_to_orchestrator "$orchestrator_device" "CPU" "$RESULT"
    ) &
}

# Function to send results back to orchestrator
send_result_to_orchestrator() {
    local orch_device="$1"
    local exec_mode="$2"
    local result="$3"
    
    # Log result in orchestrator log and mesh log
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Received result from $DEVICE_NAME ($exec_mode)" >> "$ORCH_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Received result from $DEVICE_NAME ($exec_mode)" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Result: $result" >> "$ORCH_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Result: $result" >> "$LOG_FILE"
    
    # Get orchestrator IP from peers
    ORCH_IP=""
    i=1
    for peer_name in $PEER_NAMES; do
        if [ "$peer_name" = "$orch_device" ]; then
            ORCH_IP=$(echo "$PEER_IPS" | sed -n "${i}p")
            break
        fi
        i=$((i+1))
    done
    
    # Only send via netcat if orchestrator is not self
    if [ "$orch_device" != "$DEVICE_NAME" ] && [ -n "$ORCH_IP" ]; then
        # Escape result for JSON (replace quotes and newlines)
        ESCAPED_RESULT=$(echo "$result" | sed 's/"/\\"/g' | tr '\n' ' ')
        RESULT_MSG="{\"type\":\"prompt_result\",\"from\":\"$DEVICE_NAME\",\"exec_mode\":\"$exec_mode\",\"result\":\"$ESCAPED_RESULT\"}"
        echo "$RESULT_MSG" | nc -w 2 "$ORCH_IP" "$LISTEN_PORT" 2>&1 &
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sent result back to $orch_device" >> "$LOG_FILE"
    fi
}


# Start server to listen for connections
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting server on port $LISTEN_PORT" >> "$LOG_FILE"

# Use toybox nc server mode (-L for persistent listening) - logs directly to file
(while true; do
    nc -L -p "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
    sleep 0.1
done) &

SERVER_PID=$!
echo "$SERVER_PID" > "$MESH_DIR/server.pid"

# Monitor log file for bid_request messages and switch mode
(tail -f "$LOG_FILE" 2>/dev/null | while IFS= read -r LINE; do
    if echo "$LINE" | grep -q '"type":"bid_request"'; then
        FROM_DEV=$(echo "$LINE" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$FROM_DEV" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid request from $FROM_DEV, switching to BID MODE" >> "$LOG_FILE"
            echo "bid_mode" > "$MESH_DIR/client_mode.flag"
            echo "$FROM_DEV" > "$MESH_DIR/orchestrator_device.flag"
            date +%s > "$MESH_DIR/bid_mode_start"
        fi
    elif echo "$LINE" | grep -q '"type":"prompt_execute"'; then
        # Handle prompt execution request
        FROM_DEV=$(echo "$LINE" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
        EXEC_MODE=$(echo "$LINE" | grep -o '"exec_mode":"[^"]*"' | cut -d'"' -f4)
        PROMPT=$(echo "$LINE" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$FROM_DEV" ] && [ -n "$EXEC_MODE" ] && [ -n "$PROMPT" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received prompt_execute from $FROM_DEV (mode: $EXEC_MODE)" >> "$LOG_FILE"
            
            if [ "$EXEC_MODE" = "NPU" ]; then
                execute_npu_prompt "$PROMPT" "$FROM_DEV"
            elif [ "$EXEC_MODE" = "CPU" ]; then
                execute_cpu_prompt "$PROMPT" "$FROM_DEV"
            fi
        fi
    elif echo "$LINE" | grep -q '"type":"prompt_result"'; then
        # Handle prompt result (orchestrator receiving results)
        FROM_DEV=$(echo "$LINE" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
        EXEC_MODE=$(echo "$LINE" | grep -o '"exec_mode":"[^"]*"' | cut -d'"' -f4)
        RESULT=$(echo "$LINE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$FROM_DEV" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Received result from $FROM_DEV ($EXEC_MODE)" >> "$ORCH_LOG"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Received result from $FROM_DEV ($EXEC_MODE)" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Result: $RESULT" >> "$ORCH_LOG"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Result: $RESULT" >> "$LOG_FILE"
        fi
    fi
done) &

sleep 2

# Connect to peers
echo "$PEER_IPS" | while read -r peer_ip; do
    if [ -n "$peer_ip" ]; then
        (while true; do
            # Check if orchestrator mode is enabled (this device is orchestrator)
            if [ -f "$MODE_FLAG" ] && [ "$(cat $MODE_FLAG)" = "orchestrator" ]; then
                # In orchestrator mode, send bid requests
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Requesting bids from $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
                echo "{\"type\":\"bid_request\",\"from\":\"$DEVICE_NAME\"}" | nc -w 2 "$peer_ip" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
            # Check if we're in bid mode (responding to an orchestrator)
            elif [ -f "$MESH_DIR/client_mode.flag" ] && [ "$(cat $MESH_DIR/client_mode.flag)" = "bid_mode" ]; then
                # In bid mode, send bids instead of hello
                BID=$(create_bid)
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [BID MODE] Sending bid to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
                echo "$BID" | nc -w 2 "$peer_ip" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
            else
                # Normal mode: send hello messages
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Connecting to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
                echo "{\"type\":\"hello\",\"from\":\"$DEVICE_NAME\"}" | nc -w 2 "$peer_ip" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
            fi
            sleep 5
        done) &
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Mesh node running, PID $$" >> "$LOG_FILE"

# Orchestrator monitoring loop (runs in background)
(while true; do
    if [ -f "$MODE_FLAG" ] && [ "$(cat $MODE_FLAG)" = "orchestrator" ]; then
        # Orchestrator mode is active - collect and evaluate bids
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Active - collecting bids..." >> "$ORCH_LOG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Active - collecting bids..." >> "$LOG_FILE"
        
        # Wait for bids to arrive (give peers time to respond)
        sleep 8
        
        # Parse recent bid messages from log (not bid_request, actual bids)
        BIDS=$(grep '"type":"bid"' "$LOG_FILE" | tail -10)
        
        if [ -n "$BIDS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Evaluating bids..." >> "$ORCH_LOG"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Evaluating bids..." >> "$LOG_FILE"
            echo "$BIDS" >> "$ORCH_LOG"
            echo "$BIDS" >> "$LOG_FILE"
            
            # Evaluation logic:
            # 1. Check for devices with NPU and npu_free=true
            # 2. If found, choose one with NPU
            # 3. Otherwise, choose device with lowest CPU load
            
            # Save bids to temp file to avoid subshell issues
            BIDS_FILE="$MESH_DIR/bids_temp.txt"
            echo "$BIDS" > "$BIDS_FILE"
            
            NPU_DEVICE=""
            NPU_FOUND=0

            # Initialize with this node's own bid using collect_metrics.sh
            SELF_METRICS=$(sh "$MESH_DIR/collect_metrics.sh")
            SELF_HAS_NPU=$(echo "$SELF_METRICS" | cut -d',' -f1)
            SELF_FREE_NPU=$(echo "$SELF_METRICS" | cut -d',' -f2)
            SELF_CPU_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f3)
            SELF_RAM_LOAD=$(echo "$SELF_METRICS" | cut -d',' -f4)

            # Compute bid_value = 0.174*cpu_load + 0.002*ram_load (integer)
            SELF_BID=$(echo "$SELF_CPU_LOAD" "$SELF_RAM_LOAD" | awk '{printf "%d", 0.174*$1 + 0.002*$2}')
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Self bid: bid_value=$SELF_BID (cpu:$SELF_CPU_LOAD ram:$SELF_RAM_LOAD)" >> "$ORCH_LOG"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Self bid: bid_value=$SELF_BID (cpu:$SELF_CPU_LOAD ram:$SELF_RAM_LOAD)" >> "$LOG_FILE"

            # Use self bid as initial lowest bid and record values for reporting
            LOWEST_BID=$SELF_BID
            LOWEST_DEVICE="$DEVICE_NAME"
            BEST_DEVICE_BID=$SELF_BID
            BEST_DEVICE_CPU=$SELF_CPU_LOAD
            BEST_DEVICE_RAM=$SELF_RAM_LOAD

            # Check if device has NPU from config - if so, override and choose immediately
            CONFIG_HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')
            if [ "$CONFIG_HAS_NPU" = "true" ]; then
                NPU_FOUND=1
                NPU_DEVICE="$DEVICE_NAME"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $DEVICE_NAME (has NPU from config)" >> "$ORCH_LOG"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $DEVICE_NAME (has NPU from config)" >> "$LOG_FILE"
                echo "CHOSEN: $DEVICE_NAME (NPU)" > "$MESH_DIR/chosen_device.txt"
            # If this node has a free NPU from metrics, consider it as initial NPU candidate
            elif [ "$SELF_HAS_NPU" = "true" ] && [ "$SELF_FREE_NPU" = "true" ]; then
                NPU_FOUND=1
                NPU_DEVICE="$DEVICE_NAME"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $DEVICE_NAME" >> "$ORCH_LOG"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $DEVICE_NAME" >> "$LOG_FILE"
                echo "CHOSEN: $DEVICE_NAME (NPU)" > "$MESH_DIR/chosen_device.txt"
            fi
            
            # Parse all bids (use file redirection instead of pipe to avoid subshell)
            while IFS= read -r bid; do
                has_npu=$(echo "$bid" | grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' | sed 's/.*: *\([a-z]*\)/\1/')
                npu_free=$(echo "$bid" | grep -o '"npu_free"[[:space:]]*:[[:space:]]*[a-z]*' | sed 's/.*: *\([a-z]*\)/\1/')
                from_dev=$(echo "$bid" | grep -o '"from"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
                cpu_load=$(echo "$bid" | grep -o '"cpu_load"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*: *\([0-9.]*\)/\1/')
                ram_load=$(echo "$bid" | grep -o '"ram_load"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*: *\([0-9.]*\)/\1/')
                
                # Check for NPU availability first
                if [ "$has_npu" = "true" ] && [ "$npu_free" = "true" ] && [ "$NPU_FOUND" -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $from_dev" >> "$ORCH_LOG"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ NPU chosen: $from_dev" >> "$LOG_FILE"
                    echo "CHOSEN: $from_dev (NPU)" > "$MESH_DIR/chosen_device.txt"
                    NPU_FOUND=1
                    NPU_DEVICE="$from_dev"
                fi
                
                # Compare bids using formula (only if no NPU found yet)
                if [ -n "$cpu_load" ] && [ "$NPU_FOUND" -eq 0 ]; then
                    # Compute bid value from CPU and RAM and convert to integer
                    BID_INT=$(echo "$cpu_load" "$ram_load" | awk '{printf "%d", (174*$1 + 2*$2)}')

                    if [ "$BID_INT" -lt "$LOWEST_BID" ]; then
                        LOWEST_BID="$BID_INT"
                        LOWEST_DEVICE="$from_dev"
                        BEST_DEVICE_BID=$BID_INT
                        BEST_DEVICE_CPU=$cpu_load
                        BEST_DEVICE_RAM=$ram_load
                    fi
                fi
            done < "$BIDS_FILE"
            
            # If no NPU found, use lowest bid
            if [ "$NPU_FOUND" -eq 0 ] && [ -n "$LOWEST_DEVICE" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Lowest bid chosen: $LOWEST_DEVICE (bid: ${BEST_DEVICE_BID}, cpu: ${BEST_DEVICE_CPU}%, ram: ${BEST_DEVICE_RAM}%)" >> "$ORCH_LOG"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] ✓ Lowest bid chosen: $LOWEST_DEVICE (bid: ${BEST_DEVICE_BID}, cpu: ${BEST_DEVICE_CPU}%, ram: ${BEST_DEVICE_RAM}%)" >> "$LOG_FILE"
                echo "CHOSEN: $LOWEST_DEVICE (CPU)" > "$MESH_DIR/chosen_device.txt"
            fi
            
            # Send prompt to chosen device if prompt file exists
            if [ -f "$MESH_DIR/orchestrator_prompt.txt" ]; then
                PROMPT=$(cat "$MESH_DIR/orchestrator_prompt.txt")
                CHOSEN_DEVICE=""
                EXEC_MODE=""
                
                if [ "$NPU_FOUND" -eq 1 ] && [ -n "$NPU_DEVICE" ]; then
                    CHOSEN_DEVICE="$NPU_DEVICE"
                    EXEC_MODE="NPU"
                elif [ -n "$LOWEST_DEVICE" ]; then
                    CHOSEN_DEVICE="$LOWEST_DEVICE"
                    EXEC_MODE="CPU"
                fi
                
                if [ -n "$CHOSEN_DEVICE" ] && [ -n "$PROMPT" ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Sending prompt to $CHOSEN_DEVICE for $EXEC_MODE execution..." >> "$ORCH_LOG"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Sending prompt to $CHOSEN_DEVICE for $EXEC_MODE execution..." >> "$LOG_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Prompt: $PROMPT" >> "$ORCH_LOG"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Prompt: $PROMPT" >> "$LOG_FILE"
                    
                    # If chosen device is this device, execute directly
                    if [ "$CHOSEN_DEVICE" = "$DEVICE_NAME" ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Chosen device is self, executing directly..." >> "$ORCH_LOG"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Chosen device is self, executing directly..." >> "$LOG_FILE"
                        if [ "$EXEC_MODE" = "NPU" ]; then
                            execute_npu_prompt "$PROMPT" "$DEVICE_NAME"
                        elif [ "$EXEC_MODE" = "CPU" ]; then
                            execute_cpu_prompt "$PROMPT" "$DEVICE_NAME"
                        fi
                    else
                        # Get chosen device IP for remote execution
                        CHOSEN_IP=""
                        i=1
                        for peer_name in $PEER_NAMES; do
                            if [ "$peer_name" = "$CHOSEN_DEVICE" ]; then
                                CHOSEN_IP=$(echo "$PEER_IPS" | sed -n "${i}p")
                                break
                            fi
                            i=$((i+1))
                        done
                        
                        if [ -n "$CHOSEN_IP" ]; then
                            # Send prompt_execute message to remote device
                            PROMPT_MSG="{\"type\":\"prompt_execute\",\"from\":\"$DEVICE_NAME\",\"exec_mode\":\"$EXEC_MODE\",\"prompt\":\"$PROMPT\"}"
                            echo "$PROMPT_MSG" | nc -w 2 "$CHOSEN_IP" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
                            
                            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Waiting for response from $CHOSEN_DEVICE..." >> "$LOG_FILE"
                        fi
                    fi
                fi
                
                # Clean up prompt file after sending
                rm -f "$MESH_DIR/orchestrator_prompt.txt"
            fi
            
            rm -f "$BIDS_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] No bids received yet, waiting..." >> "$ORCH_LOG"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] No bids received yet, waiting..." >> "$LOG_FILE"
        fi
        
        # Clear orchestrator mode after one round
        rm -f "$MODE_FLAG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Bid evaluation complete" >> "$ORCH_LOG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [ORCHESTRATOR] Bid evaluation complete" >> "$LOG_FILE"
    fi
    
    # Also clear bid mode on non-orchestrator devices after some time
    if [ -f "$MESH_DIR/client_mode.flag" ]; then
        # Check if bid mode has been active for more than 15 seconds
        if [ -f "$MESH_DIR/bid_mode_start" ]; then
            START_TIME=$(cat "$MESH_DIR/bid_mode_start")
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - START_TIME))
            if [ "$ELAPSED" -gt 15 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Clearing bid mode, returning to normal" >> "$LOG_FILE"
                rm -f "$MESH_DIR/client_mode.flag"
                rm -f "$MESH_DIR/orchestrator_device.flag"
                rm -f "$MESH_DIR/bid_mode_start"
            fi
        else
            date +%s > "$MESH_DIR/bid_mode_start"
        fi
    fi
    
    sleep 3
done) &

# Keep running
wait
