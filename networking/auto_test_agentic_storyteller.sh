#!/bin/bash
# auto_test_agentic_storyteller.sh
# Usage: bash auto_test_agentic_storyteller.sh
# This script will deploy and run the agent on both Android devices, check orchestrator connectivity, and print logs.

LAPTOP_IP="10.1.101.92"
PORT=8080
DEVICE_A_SERIAL="60e0c72f"
DEVICE_B_SERIAL="9688d142"
AGENT_PATH="/home/avani/ESW/agentic-ai-storyteller/networking/build/agent"

# 1. Check orchestrator is running
if ! nc -z $LAPTOP_IP $PORT; then
  echo "[ERROR] Orchestrator is not running or not reachable at $LAPTOP_IP:$PORT"
  exit 1
else
  echo "[OK] Orchestrator is reachable at $LAPTOP_IP:$PORT"
fi

# 2. Push agent to both devices and set permissions
for SERIAL in $DEVICE_A_SERIAL $DEVICE_B_SERIAL; do
  echo "[INFO] Deploying agent to device $SERIAL..."
  adb -s $SERIAL push $AGENT_PATH /data/local/tmp/ || { echo "[ERROR] Failed to push agent to $SERIAL"; exit 1; }
  adb -s $SERIAL shell chmod +x /data/local/tmp/agent
  adb -s $SERIAL shell ls -la /data/local/tmp/agent
done

# 3. Start agent on both devices in background
adb -s $DEVICE_A_SERIAL shell "/data/local/tmp/agent A $LAPTOP_IP $PORT" > agent_A.log 2>&1 &
A_PID=$!
adb -s $DEVICE_B_SERIAL shell "/data/local/tmp/agent B $LAPTOP_IP $PORT" > agent_B.log 2>&1 &
B_PID=$!

sleep 5

echo "[INFO] Checking orchestrator logs for device registration..."
# Print orchestrator output for 10 seconds
timeout 10 tail -f /home/avani/ESW/agentic-ai-storyteller/networking/orchestrator.log &

sleep 10

echo "[INFO] Checking device logs for connection status..."
echo "--- Device A log (last 20 lines) ---"
adb -s $DEVICE_A_SERIAL logcat -d | grep DeviceClient | tail -20

echo "--- Device B log (last 20 lines) ---"
adb -s $DEVICE_B_SERIAL logcat -d | grep DeviceClient | tail -20

# Optionally, kill background agent processes (if running locally)
kill $A_PID $B_PID 2>/dev/null

echo "[INFO] Auto-test complete. Check orchestrator and device logs for details."
