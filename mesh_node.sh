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

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting mesh node on port $LISTEN_PORT" >> "$LOG_FILE"

# Extract peer info (simplified - get all IPs and ports)
PEER_IPS=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PEER_PORTS=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -v listen_port | sed 's/.*: *\([0-9]*\)/\1/')
PEER_NAMES=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Start server to listen for connections
echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Starting server on port $LISTEN_PORT" >> "$LOG_FILE"

# Use toybox nc server mode (-L for persistent listening)
(while true; do
    nc -L -p "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
    sleep 0.1
done) &

SERVER_PID=$!
echo "$SERVER_PID" > "$MESH_DIR/server.pid"

sleep 2

# Connect to peers
echo "$PEER_IPS" | while read -r peer_ip; do
    if [ -n "$peer_ip" ]; then
        (while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Connecting to $peer_ip:$LISTEN_PORT" >> "$LOG_FILE"
            echo "{\"type\":\"hello\",\"from\":\"$DEVICE_NAME\"}" | nc -w 2 "$peer_ip" "$LISTEN_PORT" >> "$LOG_FILE" 2>&1
            sleep 5
        done) &
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] Mesh node running, PID $$" >> "$LOG_FILE"

# Keep running
wait
