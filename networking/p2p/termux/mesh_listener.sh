#!/system/bin/sh
# Standalone P2P Mesh Network Listener (No Termux Required)
# Runs directly in ADB shell using /data/local/tmp/

# Configuration
DEVICE_ID="${1:-unknown}"
LISTEN_PORT="${2:-9999}"
MESH_DIR="/data/local/tmp/mesh"
LOG_FILE="$MESH_DIR/mesh_${DEVICE_ID}.log"
PEERS_FILE="$MESH_DIR/peers.txt"
OUTPUT_DIR="$MESH_DIR/outputs"
SLM_SCRIPT="$MESH_DIR/run_slm.sh"

# Initialize
mkdir -p "$MESH_DIR" "$OUTPUT_DIR" 2>/dev/null
touch "$PEERS_FILE" 2>/dev/null

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

# Get device IP address
get_device_ip() {
    # Try multiple methods to determine an IPv4 address on-device.
    local ip=""

    # 1) Prefer wlan0 if present
    ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)

    # 2) Android getprop DHCP property (common on many builds)
    if [ -z "$ip" ]; then
        ip=$(getprop dhcp.wlan0.ipaddress 2>/dev/null | tr -d '\r')
    fi

    if [ -z "$ip" ]; then
        ip=$(ip -4 addr show wlan1 2>/dev/null | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
    fi

    if [ -z "$ip" ]; then
        ip=$(ip -4 addr show swlan0 2>/dev/null | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
    fi

    # 3) Any global IPv4 address (first non-loopback)
    if [ -z "$ip" ]; then
        ip=$(ip -4 addr show scope global 2>/dev/null | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v '^127\.' | head -n1)
    fi

    # 4) As a last resort, try parsing dumpsys wifi for an IP
    if [ -z "$ip" ]; then
        ip=$(dumpsys wifi 2>/dev/null | grep -m1 -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
    fi

    if [ -z "$ip" ]; then
        ip="0.0.0.0"
    fi

    echo "$ip"
}

# Helper: try several nc/listen invocation styles (returns data on stdout)
nc_listen_once() {
    # Try common nc variants. Each is tried silently; the first that returns
    # data is echoed back to the caller.
    local out

    # Standard: nc -l -p PORT
    out=$(nc -l -p "$LISTEN_PORT" 2>/dev/null) && { echo "$out"; return 0; } 2>/dev/null || true
    # Toybox-style: nc -l PORT
    out=$(nc -l "$LISTEN_PORT" 2>/dev/null) && { echo "$out"; return 0; } 2>/dev/null || true
    # Busybox variants
    out=$(busybox nc -l -p "$LISTEN_PORT" 2>/dev/null) && { echo "$out"; return 0; } 2>/dev/null || true
    out=$(busybox nc -l "$LISTEN_PORT" 2>/dev/null) && { echo "$out"; return 0; } 2>/dev/null || true

    # Nothing worked
    return 1
}

# Get system metrics for bidding
get_cpu_load() {
    # Get CPU load from /proc/stat
    local cpu1=$(cat /proc/stat | grep "^cpu " | awk '{u=$2+$4; t=$2+$4+$5; print u" "t}')
    sleep 0.5
    local cpu2=$(cat /proc/stat | grep "^cpu " | awk '{u=$2+$4; t=$2+$4+$5; print u" "t}')
    
    local u1=$(echo "$cpu1" | awk '{print $1}')
    local t1=$(echo "$cpu1" | awk '{print $2}')
    local u2=$(echo "$cpu2" | awk '{print $1}')
    local t2=$(echo "$cpu2" | awk '{print $2}')
    
    local cpu_load=$(awk -v u1="$u1" -v t1="$t1" -v u2="$u2" -v t2="$t2" 'BEGIN {
        if (t2 - t1 > 0) {
            print (u2 - u1) / (t2 - t1)
        } else {
            print 0.5
        }
    }')
    
    echo "$cpu_load"
}

get_ram_load() {
    # Get RAM usage from /proc/meminfo
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$mem_available" ]; then
        mem_available=$(grep MemFree /proc/meminfo | awk '{print $2}')
    fi
    
    local ram_load=$(awk -v total="$mem_total" -v avail="$mem_available" 'BEGIN {
        if (total > 0) {
            print (total - avail) / total
        } else {
            print 0.5
        }
    }')
    
    echo "$ram_load"
}

get_battery_level() {
    # Get battery level
    local battery=-1
    if [ -f "/sys/class/power_supply/battery/capacity" ]; then
        battery=$(cat /sys/class/power_supply/battery/capacity)
    fi
    echo "$battery"
}

# Load device configuration
load_device_config() {
    local config_file="$MESH_DIR/device_config.json"
    if [ -f "$config_file" ]; then
        echo "$config_file"
    else
        # Create default config
        echo '{"device_id": "'"$DEVICE_ID"'", "has_npu": false}' > "$config_file"
        echo "$config_file"
    fi
}

get_has_npu() {
    local config_file=$(load_device_config)
    local has_npu=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$config_file" | grep -o '[a-z]*$')
    if [ "$has_npu" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Message handlers
handle_text_message() {
    local from_device="$1"
    local message="$2"
    log "MSG" "Message from $from_device: $message"
}

handle_bid_request() {
    local from_device="$1"
    local payload="$2"
    
    log "BID" "Received bid request from $from_device"
    
    # Extract task_id from JSON payload (basic parsing)
    local task_id=$(echo "$payload" | grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    
    # Get system metrics
    local cpu_load=$(get_cpu_load)
    local ram_load=$(get_ram_load)
    local battery=$(get_battery_level)
    local has_npu=$(get_has_npu)
    
    log "BID" "Metrics: CPU=$cpu_load, RAM=$ram_load, Battery=$battery%, NPU=$has_npu"
    
    # Create bid response
    local bid_response="{\"device_id\": \"$DEVICE_ID\", \"cpu_load\": $cpu_load, \"ram_load\": $ram_load, \"battery\": $battery, \"has_npu\": $has_npu}"
    
    # Save bid to file for orchestrator to collect
    local bid_file="$MESH_DIR/bids_${task_id}.json"
    
    # Append to bids file (create if doesn't exist)
    if [ ! -f "$bid_file" ]; then
        echo "{}" > "$bid_file"
    fi
    
    # Add our bid to the file (simple JSON merge)
    # Note: This is a simplified version; in production use proper JSON tools
    echo "$bid_response" > "$MESH_DIR/bid_${DEVICE_ID}_${task_id}.tmp"
    
    # Send bid response back to orchestrator
    log "BID" "Sending bid response to $from_device"
    send_to_peer_by_id "$from_device" "BID_RESPONSE|$DEVICE_ID|$bid_response"
}

handle_task() {
    local from_device="$1"
    local payload="$2"
    
    log "TASK" "Received task from $from_device"
    log "TASK" "Payload: $payload"
    
    # Extract task data from JSON
    local task_id=$(echo "$payload" | grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    local prompt=$(echo "$payload" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    local use_npu=$(echo "$payload" | grep -o '"use_npu"[[:space:]]*:[[:space:]]*[a-z]*' | grep -o '[a-z]*$')
    
    log "TASK" "Task ID: $task_id"
    log "TASK" "Prompt: $prompt"
    log "TASK" "Use NPU: $use_npu"
    
    # Execute SLM with the prompt
    if [ -x "$SLM_SCRIPT" ]; then
        log "TASK" "Starting SLM execution..."
        
        # Create prompt file
        local prompt_file="$OUTPUT_DIR/prompt_${task_id}.txt"
        echo "$prompt" > "$prompt_file"
        
        # Run SLM
        local output_file="$OUTPUT_DIR/output_${task_id}.txt"
        "$SLM_SCRIPT" "$prompt_file" > "$output_file" 2>&1
        local exit_code=$?
        
        # Read result
        local result=$(cat "$output_file" 2>/dev/null || echo "Error: No output")
        
        # Send result back to orchestrator
        log "TASK" "Sending result back to $from_device"
        local result_json="{\"task_id\": \"$task_id\", \"device_id\": \"$DEVICE_ID\", \"status\": \"completed\", \"output\": \"$result\"}"
        
        # Save result to file
        echo "$result_json" > "$MESH_DIR/result_${task_id}.json"
        
        # Send via mesh
        send_to_peer_by_id "$from_device" "RESULT|$DEVICE_ID|$result_json"
        
        log "TASK" "Task completed"
    else
        log "ERROR" "SLM script not found or not executable: $SLM_SCRIPT"
        local error_json="{\"task_id\": \"$task_id\", \"device_id\": \"$DEVICE_ID\", \"status\": \"error\", \"output\": \"SLM not available\"}"
        send_to_peer_by_id "$from_device" "RESULT|$DEVICE_ID|$error_json"
    fi
}

handle_result() {
    local from_device="$1"
    local payload="$2"
    
    log "RESULT" "Received result from $from_device"
    log "RESULT" "Payload: $payload"
    
    # Save result for orchestrator to read
    local task_id=$(echo "$payload" | grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    echo "$payload" > "$MESH_DIR/result_${task_id}.json"
}

handle_slm_prompt() {
    local from_device="$1"
    local prompt="$2"
    
    log "SLM" "Received SLM prompt from $from_device"
    log "SLM" "Prompt: $prompt"
    
    if [ -x "$SLM_SCRIPT" ]; then
        log "SLM" "Starting SLM execution..."

         # Create a temporary prompt file
        local prompt_file="$OUTPUT_DIR/prompt_$(date +%s).txt"
        echo "$prompt" > "$prompt_file"
        
        # Run SLM with the prompt file
        local output_file="$OUTPUT_DIR/slm_output_$(date +%s).txt"
        sh "$SLM_SCRIPT" "$prompt_file" > "$output_file" 2>&1
        
        local result=$(cat "$output_file")
        log "SLM" "SLM execution completed"
        
        # Send result back
        send_slm_result "$from_device" "$result"
    else
        log "ERROR" "SLM script not found or not executable: $SLM_SCRIPT"
    fi
}

handle_slm_result() {
    local from_device="$1"
    local result="$2"
    
    log "RESULT" "SLM result from $from_device:"
    echo "$result" | tee -a "$LOG_FILE"
}

handle_hello() {
    local from_device="$1"
    local from_ip="$2"
    local from_port="$3"
    
    log "HELLO" "Received HELLO from $from_device ($from_ip:$from_port)"
    
    # Add to peers if not already there
    if ! grep -q "$from_device:$from_ip:$from_port" "$PEERS_FILE" 2>/dev/null; then
        echo "$from_device:$from_ip:$from_port" >> "$PEERS_FILE"
        log "PEER" "Added peer: $from_device:$from_ip:$from_port"
    fi
}

handle_discover() {
    local from_device="$1"
    local from_ip="$2"
    local from_port="$3"
    
    log "DISCOVER" "Discovery request from $from_device"
    
    # Add to peers
    handle_hello "$from_device" "$from_ip" "$from_port"
    
    # Send our info back
    local my_ip=$(get_device_ip)
    send_to_peer "$from_ip" "$from_port" "HELLO|$DEVICE_ID|$my_ip:$LISTEN_PORT"
}

# Send functions
send_to_peer() {
    local peer_ip="$1"
    local peer_port="$2"
    local message="$3"
    log "SEND" "Attempting to send to $peer_ip:$peer_port"

    # Try common nc invocation styles, logging the method that worked.
    printf "%s" "$message" | nc -w 2 "$peer_ip" "$peer_port" 2>/dev/null && { log "SEND" "Sent via nc -w 2 to $peer_ip:$peer_port"; return 0; } || true
    printf "%s" "$message" | nc "$peer_ip" "$peer_port" 2>/dev/null && { log "SEND" "Sent via nc to $peer_ip:$peer_port"; return 0; } || true
    printf "%s" "$message" | busybox nc -w 2 "$peer_ip" "$peer_port" 2>/dev/null && { log "SEND" "Sent via busybox nc -w 2 to $peer_ip:$peer_port"; return 0; } || true
    printf "%s" "$message" | busybox nc "$peer_ip" "$peer_port" 2>/dev/null && { log "SEND" "Sent via busybox nc to $peer_ip:$peer_port"; return 0; } || true
    # Try closing connection with -N if supported
    printf "%s" "$message" | nc -N "$peer_ip" "$peer_port" 2>/dev/null && { log "SEND" "Sent via nc -N to $peer_ip:$peer_port"; return 0; } || true

    log "ERROR" "Failed to send to $peer_ip:$peer_port (no usable nc or connection refused)"
    return 1
}

send_slm_result() {
    local target_device="$1"
    local result="$2"
    
    # Find target device in peers
    local peer_line=$(grep "^$target_device:" "$PEERS_FILE" 2>/dev/null | head -1)
    if [ -n "$peer_line" ]; then
        local peer_ip=$(echo "$peer_line" | cut -d: -f2)
        local peer_port=$(echo "$peer_line" | cut -d: -f3)
        
        log "SEND" "Sending SLM_RESULT to $target_device ($peer_ip:$peer_port)"
        send_to_peer "$peer_ip" "$peer_port" "SLM_RESULT|$DEVICE_ID|$result"
    fi
}

send_to_peer_by_id() {
    local target_device="$1"
    local message="$2"
    
    # Find target device in peers
    local peer_line=$(grep "^$target_device:" "$PEERS_FILE" 2>/dev/null | head -1)
    if [ -n "$peer_line" ]; then
        local peer_ip=$(echo "$peer_line" | cut -d: -f2)
        local peer_port=$(echo "$peer_line" | cut -d: -f3)
        
        log "SEND" "Sending to $target_device ($peer_ip:$peer_port)"
        send_to_peer "$peer_ip" "$peer_port" "$message"
    else
        log "ERROR" "Peer not found: $target_device"
        return 1
    fi
}

# Main message handler
handle_message() {
    local message="$1"
    
    # Parse message: TYPE|FROM_DEVICE|PAYLOAD
    local msg_type=$(echo "$message" | cut -d'|' -f1)
    local from_device=$(echo "$message" | cut -d'|' -f2)
    local payload=$(echo "$message" | cut -d'|' -f3-)
    
    case "$msg_type" in
        TEXT)
            handle_text_message "$from_device" "$payload"
            ;;
        BID_REQUEST)
            handle_bid_request "$from_device" "$payload"
            ;;
        BID_RESPONSE)
            log "BID" "Bid response from $from_device: $payload"
            # Orchestrator will collect these
            ;;
        TASK)
            handle_task "$from_device" "$payload"
            ;;
        RESULT)
            handle_result "$from_device" "$payload"
            ;;
        SLM_PROMPT)
            handle_slm_prompt "$from_device" "$payload"
            ;;
        SLM_RESULT)
            handle_slm_result "$from_device" "$payload"
            ;;
        HELLO)
            local peer_info=$(echo "$payload" | cut -d: -f1,2)
            local peer_ip=$(echo "$peer_info" | cut -d: -f1)
            local peer_port=$(echo "$peer_info" | cut -d: -f2)
            handle_hello "$from_device" "$peer_ip" "$peer_port"
            ;;
        DISCOVER)
            local peer_ip=$(echo "$payload" | cut -d: -f1)
            local peer_port=$(echo "$payload" | cut -d: -f2)
            handle_discover "$from_device" "$peer_ip" "$peer_port"
            ;;
        *)
            log "WARN" "Unknown message type: $msg_type"
            ;;
    esac
}

# Peer discovery
announce_to_peers() {
    local my_ip=$(get_device_ip)
    
    if [ -f "$PEERS_FILE" ]; then
        while IFS=: read -r peer_id peer_ip peer_port; do
            if [ -n "$peer_ip" ] && [ -n "$peer_port" ]; then
                log "ANNOUNCE" "Sending HELLO to $peer_id ($peer_ip:$peer_port)"
                # Retry a few times to tolerate peers starting later
                for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
                    send_to_peer "$peer_ip" "$peer_port" "HELLO|$DEVICE_ID|$my_ip:$LISTEN_PORT" && break
                    log "ANNOUNCE" "Attempt $attempt failed for $peer_id, retrying..."
                    sleep 1
                done
            fi
        done < "$PEERS_FILE"
    fi
}

# Main listener loop
listen_for_connections() {
    local my_ip=$(get_device_ip)
    
    log "START" "================================"
    log "START" "Mesh Network Listener Starting"
    log "START" "================================"
    log "INIT" "Device ID: $DEVICE_ID, IP: $my_ip, Port: $LISTEN_PORT"
    log "INIT" "Working directory: $MESH_DIR"
    log "INIT" "Log file: $LOG_FILE"
    
    # Announce to known peers
    announce_to_peers
    
    log "READY" "Mesh listener is ready!"
    log "READY" "Listening on port $LISTEN_PORT..."

    # Log listening sockets for debugging (ss/netstat may vary by device)
    if command -v ss >/dev/null 2>&1; then
        log "DEBUG" "Listening sockets (ss -ltn):"
        ss -ltn 2>/dev/null | sed 's/^/    /' | while read -r l; do log "DEBUG" "$l"; done
    elif command -v netstat >/dev/null 2>&1; then
        log "DEBUG" "Listening sockets (netstat -ltn):"
        netstat -ltn 2>/dev/null | sed 's/^/    /' | while read -r l; do log "DEBUG" "$l"; done
    else
        log "DEBUG" "ss/netstat not available on device"
    fi
    
    # Start netcat listener (use helper that tries multiple nc variants)
    while true; do
        # Listen for one connection, handle it, then loop
        MESSAGE=""
        if MESSAGE=$(nc_listen_once); then
            if [ -n "$MESSAGE" ]; then
                handle_message "$MESSAGE"
            fi
        else
            # If no nc variant is available, log and sleep to avoid busy loop
            log "ERROR" "No working 'nc' found on device. Install busybox or ensure toybox nc is available. Retrying..."
            sleep 2
        fi

        # Small delay to prevent busy loop
        sleep 0.1
    done
}

# Handle signals
trap 'log "STOP" "Mesh listener stopped"; exit 0' INT TERM

# Start listener
listen_for_connections