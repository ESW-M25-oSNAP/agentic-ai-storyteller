#!/system/bin/sh
# Collect system metrics on Android device
# Returns: has_npu,free_npu,cpu_load,ram_percent

MESH_DIR="/sdcard/mesh_network"
CONFIG_FILE="$MESH_DIR/device_config.json"

# Read NPU info from config
HAS_NPU=$(grep -o '"has_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')
FREE_NPU=$(grep -o '"free_npu"[[:space:]]*:[[:space:]]*[a-z]*' "$CONFIG_FILE" | sed 's/.*: *\([a-z]*\)/\1/')

# Default to false if not found
if [ -z "$HAS_NPU" ]; then
    HAS_NPU="false"
fi
if [ -z "$FREE_NPU" ]; then
    FREE_NPU="false"
fi

# Get CPU load (from /proc/loadavg)
# Format: 1min 5min 15min running/total lastPID
# We'll use 1-minute load average divided by number of CPUs
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
NUM_CPUS=$(grep -c ^processor /proc/cpuinfo)

# Calculate CPU load percentage (load_avg / num_cpus)
# Use awk for floating point math
CPU_LOAD=$(awk "BEGIN {printf \"%.2f\", ($LOAD_AVG / $NUM_CPUS) * 100}")

# Get RAM usage
# Parse /proc/meminfo for MemTotal and MemAvailable
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# Calculate RAM usage percentage
RAM_USED=$((MEM_TOTAL - MEM_AVAILABLE))
RAM_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($RAM_USED * 100.0) / $MEM_TOTAL}")

# Output format: has_npu,free_npu,cpu_load,ram_percent
echo "${HAS_NPU},${FREE_NPU},${CPU_LOAD},${RAM_PERCENT}"
