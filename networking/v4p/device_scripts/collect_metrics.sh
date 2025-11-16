#!/system/bin/sh
# Collect system metrics on Android device
# Returns: has_npu,free_npu,cpu_load,ram_percent

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"
NPU_FLAG_FILE="$MESH_DIR/npu_free.flag"

# Read NPU info from config
HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')

# Check npu_free flag file first (set during execution), then fall back to config
if [ -f "$NPU_FLAG_FILE" ]; then
    FREE_NPU=$(cat "$NPU_FLAG_FILE")
else
    FREE_NPU=$(grep -o '"free_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')
fi

# Default to false if not found
if [ -z "$HAS_NPU" ]; then
    HAS_NPU="false"
fi
if [ -z "$FREE_NPU" ]; then
    FREE_NPU="false"
fi

# Get CPU load (from /proc/loadavg)
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
NUM_CPUS=$(grep -c ^processor /proc/cpuinfo)
CPU_LOAD=$(awk "BEGIN {printf \"%.2f\", ($LOAD_AVG / $NUM_CPUS) * 100}")

# Get RAM usage
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
RAM_USED=$((MEM_TOTAL - MEM_AVAILABLE))
RAM_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($RAM_USED * 100.0) / $MEM_TOTAL}")

# Output format: has_npu,free_npu,cpu_load,ram_percent
echo "${HAS_NPU},${FREE_NPU},${CPU_LOAD},${RAM_PERCENT}"
