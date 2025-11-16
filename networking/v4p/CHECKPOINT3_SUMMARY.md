# Checkpoint 3: Feedback Loop - Implementation Summary

## Overview
Checkpoint 3 completes the decentralized LinUCB system by implementing a **closed-loop learning cycle** where devices learn from actual SLM execution latency and continuously improve their bidding accuracy.

## What Changed

### 1. orchestrator.sh - Added SLM Execution & Feedback Sending

**Location**: After winner selection (lines 143-210)

**Key Changes**:
- **Real SLM Execution** using llama.cpp (replaced mock `sleep 2`)
- **Latency Measurement** using `date +%s` before/after execution
- **Result Extraction** from llama-cli output (filters out perf stats)
- **Feedback Packet Sending** to winner on port 5003
- **Self-Training** for local execution (no network needed)

**Code Flow**:
```bash
# 1. Execute SLM with llama.cpp
cd /data/local/tmp/cppllama-bundle/llama.cpp
START_TIME=$(date +%s)
FULL_OUTPUT=$(./build/bin/llama-cli -m models/llama-3.2-3b-instruct-q4_k_m.gguf \
  -p "$PROMPT" -n 50 -no-cnv 2>&1)
END_TIME=$(date +%s)
ACTUAL_LATENCY=$((END_TIME - START_TIME))

# 2. Extract clean result (remove perf stats)
RESULT=$(echo "$FULL_OUTPUT" | grep -v "llama_perf" | ...)

# 3. Send feedback to winner
if [ "$BEST_DEVICE" != "$DEVICE_NAME" ]; then
    echo "FEEDBACK|bid_id:$BEST_BID_ID|latency:$ACTUAL_LATENCY" | \
      nc -w 2 "$WINNER_IP" 5003
else
    # Self-training
    lini train $STATE_A $STATE_B $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_LATENCY
fi
```

### 2. feedback_listener.sh - Created New Script

**Location**: `/networking/v2p/device_scripts/feedback_listener.sh`

**Purpose**: Listen for feedback packets on port 5003, train LinUCB models

**Key Features**:
- Listens on port 5003 using netcat
- Parses `FEEDBACK|bid_id:<id>|latency:<seconds>` format
- Looks up features from `pending_bids.txt`
- Calls `lini train` with actual latency
- Removes processed bid from pending file
- Comprehensive logging

**Code Flow**:
```bash
# Listen on port 5003
while true; do
    nc -L -p 5003 | while read -r PACKET; do
        # Parse feedback
        BID_ID=$(echo "$PACKET" | sed 's/.*bid_id:\([^|]*\).*/\1/')
        ACTUAL_LATENCY=$(echo "$PACKET" | sed 's/.*latency:\([0-9]*\).*/\1/')
        
        # Lookup features
        FEATURES=$(grep "^$BID_ID," "$PENDING_BIDS_FILE")
        CPU_NORM=$(echo "$FEATURES" | cut -d',' -f2)
        RAM_NORM=$(echo "$FEATURES" | cut -d',' -f3)
        PROMPT_NORM=$(echo "$FEATURES" | cut -d',' -f4)
        
        # Train model
        $LINUCB_BIN train $STATE_A $STATE_B \
          $CPU_NORM $RAM_NORM $PROMPT_NORM $ACTUAL_LATENCY
        
        # Cleanup
        grep -v "^$BID_ID," "$PENDING_BIDS_FILE" > temp && mv temp "$PENDING_BIDS_FILE"
    done
done
```

### 3. trigger_orchestrator.sh - Pass Prompt Text

**Change**: Now passes both `PROMPT_LENGTH` and `PROMPT` text to orchestrator

**Before**:
```bash
adb -s "$SERIAL" shell "cd $DEVICE_DIR && sh orchestrator.sh $PROMPT_LENGTH"
```

**After**:
```bash
adb -s "$SERIAL" shell "cd $DEVICE_DIR && sh orchestrator.sh $PROMPT_LENGTH '$PROMPT'"
```

### 4. start_mesh.sh - Start Feedback Listeners

**Change**: Now starts both `bid_listener.sh` AND `feedback_listener.sh`

**Before**:
```bash
adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && \
  nohup sh bid_listener.sh > bid_listener_startup.log 2>&1 &"
```

**After**:
```bash
# Start bid listener
adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && \
  nohup sh bid_listener.sh > bid_listener_startup.log 2>&1 &"

# Start feedback listener
adb -s "$DEVICE_SERIAL" shell "cd $DEVICE_DIR && \
  nohup sh feedback_listener.sh > feedback_listener_startup.log 2>&1 &"
```

### 5. deploy_to_devices.sh - Deploy Feedback Script

**Change**: Added `feedback_listener.sh` to deployment

```bash
adb -s "$DEVICE_SERIAL" push \
  "$SCRIPT_DIR/device_scripts/feedback_listener.sh" \
  "$DEVICE_DIR/feedback_listener.sh"
adb -s "$DEVICE_SERIAL" shell "chmod +x $DEVICE_DIR/feedback_listener.sh"
```

### 6. stop_mesh.sh - Kill Feedback Listeners

**Change**: Kill both listeners

```bash
adb -s "$DEVICE_SERIAL" shell \
  "pkill -f bid_listener.sh; pkill -f feedback_listener.sh"
```

### 7. monitor_live.sh - Monitor Feedback Logs

**Change**: Added feedback listener monitoring

- Shows last 30 lines of `feedback_listener.log` in history
- Live tails with `[DeviceX-FDBK]` tags

### 8. TESTING_INSTRUCTIONS.md - Updated Documentation

**Changes**:
- Updated overview to mention feedback loop
- Added Checkpoint 3 testing section
- Added expected output with SLM results
- Added feedback listener log examples
- Added learning convergence explanation
- Updated success criteria

## Network Architecture

### Port Assignments
- **5001**: BID_REQUEST (orchestrator → workers)
- **5002**: BID_RESPONSE (workers → orchestrator)
- **5003**: FEEDBACK (orchestrator → winner) ← **NEW**

### Message Formats
- **BID_REQUEST**: `BID_REQUEST|from:<device>|prompt_length:<tokens>`
- **BID_RESPONSE**: `<bid_id>|<score>` (e.g., `bid_1763221432_DeviceA|-1.000215`)
- **FEEDBACK**: `FEEDBACK|bid_id:<id>|latency:<seconds>` ← **NEW**

## Data Persistence

### pending_bids.txt
**Format**: `bid_id,cpu_norm,ram_norm,prompt_norm,timestamp`

**Purpose**: Store features for each bid so feedback can train model later

**Lifecycle**:
1. Created by `bid_listener.sh` when sending bid
2. Read by `feedback_listener.sh` when feedback arrives
3. Removed by `feedback_listener.sh` after training

### State Files (state_A.dat, state_B.dat)
**Updated by**: `lini train` command in `feedback_listener.sh`

**Learning Process**:
- Initial: Identity matrix (A) and zero vector (b)
- After each feedback: Updated using LinUCB update rule
- Effect: Scores become more accurate over time

## SLM Execution Details

### llama.cpp Integration
**Binary**: `/data/local/tmp/cppllama-bundle/llama.cpp/build/bin/llama-cli`

**Model**: `models/llama-3.2-3b-instruct-q4_k_m.gguf`

**Command**:
```bash
./build/bin/llama-cli \
  -m models/llama-3.2-3b-instruct-q4_k_m.gguf \
  -p "$PROMPT" \
  -n 50 \          # Generate up to 50 tokens
  -no-cnv          # No conversation mode
```

### Output Parsing
**Challenge**: llama-cli outputs performance stats mixed with generated text

**Solution**: Filter out lines containing:
- `llama_perf`
- `llama_memory`
- `load time`
- `eval time`
- `sampling time`
- Lines starting with `[`

**Result**: Clean text response extracted

## Testing Flow

### Step-by-Step Execution

1. **Deploy**:
   ```bash
   ./deploy_to_devices.sh
   cd device_scripts && ./deploy_lini.sh
   ```

2. **Start Mesh**:
   ```bash
   ./start_mesh.sh
   ```
   - Starts `bid_listener.sh` on all devices (port 5001)
   - Starts `feedback_listener.sh` on all devices (port 5003)

3. **Monitor**:
   ```bash
   ./monitor_live.sh
   ```
   - Shows BID, ORCH, FDBK logs in real-time

4. **Trigger**:
   ```bash
   ./trigger_orchestrator.sh DeviceB "What is a banana?"
   ```

5. **Expected Flow**:
   ```
   [DeviceB-ORCH] Broadcasting BID_REQUEST
   [DeviceA-BID] Calculated score: 6.034475
   [DeviceC-BID] Calculated score: -1.000215
   [DeviceB-ORCH] Self score: -1.000015
   [DeviceB-ORCH] Winner: DeviceB (self)
   [DeviceB-ORCH] Executing SLM...
   [DeviceB-ORCH] Result: A banana is a long, curved fruit...
   [DeviceB-ORCH] Completed in 8s
   [DeviceB-FDBK] Received feedback: bid_id=self, latency=8
   [DeviceB-FDBK] Training model...
   [DeviceB-FDBK] Model updated
   ```

6. **Verify Learning**:
   ```bash
   adb -s 9688d142 shell "cd /data/local/tmp && ./lini print state_A.dat state_B.dat"
   ```
   - Check matrices are no longer identity/zero
   - Non-zero values = learning occurred

## Key Improvements Over Checkpoint 2

| Aspect | Checkpoint 2 | Checkpoint 3 |
|--------|--------------|--------------|
| SLM Execution | ❌ Not implemented (mock) | ✅ Real llama.cpp execution |
| Latency | ❌ Not measured | ✅ Measured with timestamps |
| Feedback | ❌ No feedback loop | ✅ FEEDBACK packets sent |
| Model Training | ❌ Models static | ✅ Models trained with actual data |
| Learning | ❌ No learning | ✅ Continuous learning |
| Score Accuracy | ❌ Always optimistic | ✅ Converges to realistic |

## Expected Learning Behavior

### Initial State (No Experience)
- **Matrix A**: 4×4 Identity matrix
- **Vector b**: 4×1 Zero vector
- **Scores**: Very negative (e.g., -1.000215) - optimistic due to high uncertainty

### After 5-10 Runs
- **Matrix A**: Filled with positive values (covariance)
- **Vector b**: Non-zero (accumulated rewards)
- **Scores**: More realistic (e.g., 2.5-8.0) based on actual latency

### Long-Term Convergence
- **Scores stabilize** as uncertainty decreases
- **Device differentiation** emerges (fast devices → low scores, slow → high)
- **Variance reduction** - scores become more predictable

## Files Modified

1. ✅ `device_scripts/orchestrator.sh` - Added SLM execution & feedback
2. ✅ `device_scripts/feedback_listener.sh` - **NEW FILE** created
3. ✅ `trigger_orchestrator.sh` - Pass prompt text
4. ✅ `start_mesh.sh` - Start feedback listeners
5. ✅ `deploy_to_devices.sh` - Deploy feedback script
6. ✅ `stop_mesh.sh` - Kill feedback listeners
7. ✅ `monitor_live.sh` - Monitor feedback logs
8. ✅ `TESTING_INSTRUCTIONS.md` - Updated documentation

## Next Steps for You

1. **Deploy the updated scripts**:
   ```bash
   ./deploy_to_devices.sh
   ```

2. **Stop old mesh** (if running):
   ```bash
   ./stop_mesh.sh
   ```

3. **Start new mesh** (with feedback listeners):
   ```bash
   ./start_mesh.sh
   ```

4. **Monitor in one terminal**:
   ```bash
   ./monitor_live.sh
   ```

5. **Test in another terminal**:
   ```bash
   ./trigger_orchestrator.sh DeviceB "What is a banana?"
   ```

6. **Verify SLM execution** - You should see actual text responses!

7. **Check feedback** - Look for `[DeviceX-FDBK]` messages

8. **Verify learning** - Print matrices before/after multiple runs

## Success Criteria

✅ You've successfully implemented Checkpoint 3 when:
- SLM executes and produces text responses
- Feedback packets sent to winning device
- LinUCB matrices update (non-zero values)
- Scores change over time (learning occurs)
- System works end-to-end without manual intervention

**🎉 Congratulations! You now have a fully decentralized, self-learning edge mesh network!**
