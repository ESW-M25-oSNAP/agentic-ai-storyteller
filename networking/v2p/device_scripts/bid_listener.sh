#!/system/bin/sh
# Bid Listener - Listens for bid requests and responds with metrics
# This runs continuously on each device in the mesh network

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/bid_listener.log"
BID_PORT=5001

# Parse device name
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid listener starting on port $BID_PORT" >> "$LOG_FILE"

# Start listening for bid requests
while true; do
    # Listen on port 5001 for bid requests
    REQUEST=$(echo "" | nc -l -p $BID_PORT -w 5 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$REQUEST" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Received bid request: $REQUEST" >> "$LOG_FILE"
        
        # Check if it's a bid request
        if echo "$REQUEST" | grep -q "BID_REQUEST"; then
            # Extract the orchestrator's IP from the request
            ORCHESTRATOR_IP=$(echo "$REQUEST" | grep -o 'from:[0-9.]*' | cut -d':' -f2)
            
            if [ -n "$ORCHESTRATOR_IP" ]; then
                # Collect metrics
                METRICS=$(sh "$MESH_DIR/collect_metrics.sh")
                
                # Parse metrics
                HAS_NPU=$(echo "$METRICS" | cut -d',' -f1)
                FREE_NPU=$(echo "$METRICS" | cut -d',' -f2)
                CPU_LOAD=$(echo "$METRICS" | cut -d',' -f3)
                RAM_LOAD=$(echo "$METRICS" | cut -d',' -f4)
                
                # Create bid response
                BID_RESPONSE="BID_RESPONSE|device:$DEVICE_NAME|has_npu:$HAS_NPU|free_npu:$FREE_NPU|cpu_load:$CPU_LOAD|ram_load:$RAM_LOAD"
                
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Sending bid to $ORCHESTRATOR_IP: $BID_RESPONSE" >> "$LOG_FILE"
                
                # Send bid response to orchestrator on port 5002
                echo "$BID_RESPONSE" | nc -w 2 "$ORCHESTRATOR_IP" 5002 >> "$LOG_FILE" 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Bid sent successfully" >> "$LOG_FILE"
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Failed to send bid" >> "$LOG_FILE"
                fi
            fi
        fi
    fi
    
    sleep 1
done
