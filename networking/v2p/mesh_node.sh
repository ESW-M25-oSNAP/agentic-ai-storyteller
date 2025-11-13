#!/system/bin/sh
# Simple Mesh Network Node for Android
# Uses Android's toybox netcat

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
LOG_FILE="$MESH_DIR/mesh.log"

cd "$MESH_DIR" || exit 1

# Parse config
DEVICE_NAME=$(grep -o '"device_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
LISTEN_PORT=$(grep -o '"listen_port"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | sed 's/.*: *\([0-9]*\)/\1/')

# Parse NPU configuration
HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')
FREE_NPU=$(grep -o '"free_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')

# Default to false if not found
if [ -z "$HAS_NPU" ]; then
    HAS_NPU="false"
fi
if [ -z "$FREE_NPU" ]; then
    FREE_NPU="false"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting mesh node on port $LISTEN_PORT" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] NPU Status - Has NPU: $HAS_NPU, Free NPU: $FREE_NPU" >> "$LOG_FILE"

# Extract peer info (simplified - get all IPs and ports)
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PEER_PORTS=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -v listen_port | sed 's/.*: *\([0-9]*\)/\1/')
PEER_NAMES=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Start server to listen for connections
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting server on port $LISTEN_PORT" >> "$LOG_FILE"

# Kill any existing nc processes on this port
pkill -f "nc -L -p $LISTEN_PORT" 2>/dev/null
sleep 1

# Use toybox nc server mode (-L for persistent listening)
# The -L flag makes nc stay alive and fork for each connection
nc -L -p "$LISTEN_PORT" >> "$LOG_FILE" 2>&1 &

SERVER_PID=$!
echo "$SERVER_PID" > "$MESH_DIR/server.pid"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Server started with PID $SERVER_PID" >> "$LOG_FILE"

sleep 2

# Verify server is listening
if ps -p "$SERVER_PID" > /dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Server confirmed listening on port $LISTEN_PORT" >> "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] ERROR: Server failed to start!" >> "$LOG_FILE"
    exit 1
fi

# Connect to peers
echo "$PEER_IPS" | while read -r peer_ip; do
    if [ -n "$peer_ip" ]; then
        (while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Attempting connection to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
            if echo "{\"type\":\"hello\",\"from\":\"$DEVICE_NAME\",\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}" | nc -w 3 "$peer_ip" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Successfully connected to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Failed to connect to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
            fi
            sleep 10
        done) &
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Mesh node running, PID $$" >> "$LOG_FILE"

# Keep running
wait
