# Testing Instructions - LinUCB Decentralized Mesh Network

Complete step-by-step guide to test the decentralized LinUCB bidding system with feedback loop.

## System Overview

This system implements a **fully decentralized heterogeneous edge mesh** where:
- Each device maintains its own **local LinUCB learning model**
- Devices bid on tasks using **self-calculated scores** (Checkpoint 2)
- Winner executes **actual SLM** and sends **feedback** to update models (Checkpoint 3)
- Models improve over time, learning actual latency patterns

## Prerequisites

✅ 3 Android devices connected via ADB  
✅ All devices on same WiFi network  
✅ Termux installed on devices (for building LinUCB binary)  
✅ Netcat installed on devices (`pkg install netcat-openbsd`)  
✅ llama.cpp installed at `/data/local/tmp/cppllama-bundle/llama.cpp` on all devices

---

## Step 1: Initial Setup

### 1.1 Check Connected Devices
```bash
cd /home/avani/ESW/agentic-ai-storyteller/agentic-ai-storyteller/networking/v2p
adb devices
```

Expected output:
```
List of devices attached
60e0c72f        device    # DeviceA
9688d142        device    # DeviceB
RZCT90P1WAK     device    # DeviceC
```

### 1.2 Configure Device IPs
```bash
./setup_configs.sh
```

Follow prompts to enter:
- Device IPs (get from: `adb shell ip addr show wlan0 | grep inet`)
- NPU availability (true/false for each device)

---

## Step 2: Build LinUCB Binary

### 2.1 Build on One Device (in Termux)

On your laptop, connect to a device:
```bash
adb -s 60e0c72f shell
```

In the device shell (should open Termux):
```bash
cd /data/local/tmp
pkg install clang
```

Copy source to device:
```bash
# Exit device shell first (Ctrl+D)
adb -s 60e0c72f push device_scripts/linucb_solver.c /data/local/tmp/
```

Back in device shell:
```bash
cd /data/local/tmp
clang -O2 -lm -o lini linucb_solver.c
chmod +x lini
./lini init state_A.dat state_B.dat 1.0
```

Expected output:
```
LinUCB initialized: A = Identity, b = zeros, alpha = 1.0
State saved to state_A.dat, state_B.dat
```

### 2.2 Pull Binary to Laptop
```bash
# Exit device shell
adb -s 60e0c72f pull /data/local/tmp/lini device_scripts/
```

### 2.3 Verify Binary Works
```bash
adb -s 60e0c72f shell "/data/local/tmp/lini score /data/local/tmp/state_A.dat /data/local/tmp/state_B.dat 0.2 0.3 0.1"
```

Expected output (negative number = optimistic):
```
-1.000215
```

---

## Step 3: Deploy to All Devices

### 3.1 Deploy Scripts and Configs
```bash
./deploy_to_devices.sh
```

Expected output:
```
✓ Deployed to DeviceA
✓ Deployed to DeviceB
✓ Deployed to DeviceC
```

### 3.2 Deploy LinUCB Binary to All Devices

Manually deploy to each device:
```bash
# DeviceA
adb -s 60e0c72f push device_scripts/lini /data/local/tmp/
adb -s 60e0c72f shell "chmod 755 /data/local/tmp/lini"
adb -s 60e0c72f shell "cd /data/local/tmp && ./lini init state_A.dat state_B.dat 1.0"

# DeviceB
adb -s 9688d142 push device_scripts/lini /data/local/tmp/
adb -s 9688d142 shell "chmod 755 /data/local/tmp/lini"
adb -s 9688d142 shell "cd /data/local/tmp && ./lini init state_A.dat state_B.dat 1.0"

# DeviceC
adb -s RZCT90P1WAK push device_scripts/lini /data/local/tmp/
adb -s RZCT90P1WAK shell "chmod 755 /data/local/tmp/lini"
adb -s RZCT90P1WAK shell "cd /data/local/tmp && ./lini init state_A.dat state_B.dat 1.0"
```

---

## Step 4: Clean Up and Start

### 4.1 Nuclear Cleanup (Kill Old Processes)
```bash
./nuclear_cleanup.sh
```

Expected output:
```
✓ Cleanup complete on all devices
```

### 4.2 Start LinUCB Bid Listeners
```bash
./start_mesh.sh
```

Expected output:
```
✓ LinUCB bid listener started on Device 1
✓ LinUCB bid listener started on Device 2
✓ LinUCB bid listener started on Device 3
```

### 4.3 Verify Bid Listeners Are Running
```bash
adb -s 60e0c72f shell "pgrep -f bid_listener"
adb -s 9688d142 shell "pgrep -f bid_listener"
adb -s RZCT90P1WAK shell "pgrep -f bid_listener"
```

Each should return a process ID number.

---

## Step 5: Monitor and Test

### 5.1 Start Monitoring (Terminal 1)
```bash
./monitor_live.sh
```

You should see:
- **Recent Mesh Network Activity**: Hello messages, connections
- **Recent Bid Listener Activity**: "Bid listener starting on port 5001"
- **Recent Orchestrator Activity**: (empty initially)
- **NOW MONITORING LIVE UPDATES...**

### 5.2 Trigger Orchestrator (Terminal 2)
```bash
./trigger_orchestrator.sh DeviceB "What is a banana?"
```

Expected flow in monitor:
```
[DeviceB-ORCH] 2025-11-15 15:00:00 Orchestrator Starting (prompt_length: 20)
[DeviceB-ORCH] 2025-11-15 15:00:00 [DeviceB] Running on IP: 10.97.68.226
[DeviceB-ORCH] 2025-11-15 15:00:00 [DeviceB] Broadcasting BID_REQUEST to all peers
[DeviceB-ORCH] 2025-11-15 15:00:01 [DeviceB] Self score: -1.000015 (cpu:27.88 ram:47.25)

[DeviceA-BID] 2025-11-15 09:30:01 [DeviceA] Received bid request: BID_REQUEST|from:10.97.68.226|prompt_length:20
[DeviceA-BID] 2025-11-15 09:30:01 [DeviceA] Sending bid: BID_RESPONSE|device:DeviceA|bid_id:bid_1763218297123_DeviceA|score:6.034516

[DeviceC-BID] 2025-11-15 14:30:01 [DeviceC] Received bid request: BID_REQUEST|from:10.97.68.226|prompt_length:20
[DeviceC-BID] 2025-11-15 14:30:01 [DeviceC] Sending bid: BID_RESPONSE|device:DeviceC|bid_id:bid_1763218297896_DeviceC|score:-1.000215

[DeviceB-ORCH] 2025-11-15 15:00:31 Bid from DeviceA:
[DeviceB-ORCH]   - bid_id: bid_1763218297123_DeviceA
[DeviceB-ORCH]   - score: 6.034516

[DeviceB-ORCH] 2025-11-15 15:00:31 Bid from DeviceC:
[DeviceB-ORCH]   - bid_id: bid_1763218297896_DeviceC
[DeviceB-ORCH]   - score: -1.000215
[DeviceB-ORCH]   ✓ Lowest score so far

[DeviceB-ORCH] ========================================
[DeviceB-ORCH] ORCHESTRATOR DECISION
[DeviceB-ORCH] ========================================
[DeviceB-ORCH] ✓ Lowest score chosen: DeviceC (score: -1.000215, bid_id: bid_1763218297896_DeviceC)
[DeviceB-ORCH] Executing SLM on DeviceC...
[DeviceB-ORCH] Prompt: What is a banana?
[DeviceB-ORCH] [CPU EXEC] Starting CPU execution...
[DeviceB-ORCH] 
[DeviceB-ORCH] ✓ Execution completed in 8s
[DeviceB-ORCH] ✓ Result: A banana is a long, curved fruit that grows on plants...
[DeviceB-ORCH] 
[DeviceC-FDBK] Received feedback packet: FEEDBACK|bid_id:bid_1763218297896_DeviceC|latency:8
[DeviceC-FDBK] ✓ Parsed: bid_id=bid_1763218297896_DeviceC, latency=8
[DeviceC-FDBK] ✓ Found features: 0.1610,0.6600,0.0200
[DeviceC-FDBK] Training LinUCB model with actual latency...
[DeviceC-FDBK] ✓ LinUCB model updated successfully
```

**What just happened:**
1. DeviceB broadcast BID_REQUEST
2. DeviceC calculated score -1.000215 and won
3. DeviceB executed SLM using llama.cpp (took 8 seconds)
4. DeviceB sent FEEDBACK packet to DeviceC
5. DeviceC received feedback, trained its model with actual latency
6. DeviceC's LinUCB matrices updated (A and b changed)

---

## Step 6: Verify Feedback Loop (Checkpoint 3)

### 6.1 Check SLM Execution Output
After triggering orchestrator, you should see actual SLM responses in the output:
```bash
./trigger_orchestrator.sh DeviceB "What is a banana?"
```

Expected output includes:
```
✓ Execution completed in 8s
✓ Result: A banana is a long, curved fruit that grows on plants...
```

### 6.2 Check Feedback Listener Logs
```bash
adb -s RZCT90P1WAK shell "cat /sdcard/mesh_network/feedback_listener.log"
```

Expected output:
```
2025-11-15 15:00:45 Received feedback packet: FEEDBACK|bid_id:bid_1763218297896_DeviceC|latency:8
2025-11-15 15:00:45 ✓ Parsed: bid_id=bid_1763218297896_DeviceC, latency=8
2025-11-15 15:00:45 ✓ Found features: 0.1610,0.6600,0.0200
2025-11-15 15:00:45 Training LinUCB model with actual latency...
2025-11-15 15:00:45 ✓ LinUCB model updated successfully
```

### 6.3 Verify Pending Bids Are Stored and Cleaned
Before feedback:
```bash
adb -s RZCT90P1WAK shell "cat /data/local/tmp/pending_bids.txt"
```

Expected:
```
bid_1763218297896_DeviceC,0.1610,0.6600,0.0200,1731685822
```

After feedback, the bid should be removed:
```bash
adb -s RZCT90P1WAK shell "cat /data/local/tmp/pending_bids.txt"
```

Expected: (empty or other bids only)

### 6.4 Verify LinUCB Matrices Updated
```bash
adb -s RZCT90P1WAK shell "cd /data/local/tmp && ./lini print state_A.dat state_B.dat"
```

Expected output (matrices now updated with real data):
```
Matrix A (4x4):
  1.025921  0.004146  0.017002  0.003220
  0.004146  1.107556  0.110682  0.013200
  0.017002  0.110682  1.436000  0.013200
  0.003220  0.013200  0.013200  1.000400

Vector b (4x1):
  0.206873
  1.381680
  2.318400
  0.160000
```

(Non-zero values indicate learning has occurred!)

### 6.5 Test Learning: Run Multiple Orchestrations
```bash
# First run - device has no experience
./trigger_orchestrator.sh DeviceB "Test prompt 1"
sleep 40

# Check DeviceC's score (should be negative/optimistic)
# Then run again with similar conditions

./trigger_orchestrator.sh DeviceB "Test prompt 2"
sleep 40

# Check DeviceC's score again (should be more realistic now)
```

Monitor the scores - they should change as devices learn!

---

## Step 7: Advanced Testing Scenarios

### 7.1 Test Self-Execution (Orchestrator Wins Own Bid)
```bash
adb -s RZCT90P1WAK shell "cat /sdcard/mesh_network/pending_bids.txt"
```

Expected output (features stored for feedback):
```
bid_1763218297896_DeviceC,0.1610,0.6600,0.0200,1731685822
```

If orchestrator device wins, it should train its own model directly (no feedback packet sent over network).

### 7.2 Verify LinUCB Matrices Are Initialized
```bash
adb -s RZCT90P1WAK shell "cd /data/local/tmp && ./lini print state_A.dat state_B.dat"
```

Fresh initialization shows:
```
Matrix A (4x4):
  1.000000  0.000000  0.000000  0.000000
  0.000000  1.000000  0.000000  0.000000
  0.000000  0.000000  1.000000  0.000000
  0.000000  0.000000  0.000000  1.000000

Vector b (4x1):
  0.000000
  0.000000
  0.000000
  0.000000
```

### 7.3 Test Multiple Orchestrations
```bash
# Trigger from different devices
./trigger_orchestrator.sh DeviceA "Tell me about AI"
sleep 40
./trigger_orchestrator.sh DeviceC "What is machine learning?"
sleep 40
./trigger_orchestrator.sh DeviceB "Explain neural networks"
```

Watch monitor - you should see:
- Different scores based on each device's current CPU/RAM load
- Actual SLM execution and responses
- Feedback packets being sent and received
- Models updating after each execution

---

## Step 8: Understanding the Output

### Score Interpretation
- **Negative scores** (e.g., -1.000215): Optimistic, high uncertainty, device bids aggressively
- **Positive scores** (e.g., 6.034516): Realistic/pessimistic based on learned experience
- **Lower score wins**: Most optimistic about achieving low latency

### BidID Format
- `bid_<timestamp>_<DeviceName>`
- Example: `bid_1763218297896_DeviceC`
- Used to track bids for feedback loop (Checkpoint 3)

### Features Stored
Format: `BidID,cpu_norm,ram_norm,prompt_norm,timestamp`
- `cpu_norm`: CPU load / 100 (e.g., 0.1610 = 16.1% CPU)
- `ram_norm`: RAM load / 100 (e.g., 0.6600 = 66% RAM)
- `prompt_norm`: Prompt length / 1000 (e.g., 0.0200 = 20 tokens)

---

## Step 9: Troubleshooting

### No Bids Received
```bash
# Check if bid listeners are running
adb shell "ps -A | grep bid_listener"

# Check if port 5001 is listening
adb -s 60e0c72f shell "netstat -tuln | grep 5001"

# Check logs
adb -s 60e0c72f shell "cat /sdcard/mesh_network/bid_listener.log"
```

### LinUCB Solver Fails
```bash
# Verify binary exists and is executable
adb shell "ls -la /data/local/tmp/lini"

# Test manually
adb shell "/data/local/tmp/lini score /data/local/tmp/state_A.dat /data/local/tmp/state_B.dat 0.2 0.3 0.1"

# Reinitialize state if corrupted
adb shell "cd /data/local/tmp && ./lini init state_A.dat state_B.dat 1.0"
```

### Monitor Shows No Output
- Ensure `monitor_live.sh` is started BEFORE triggering orchestrator
- Check that log files exist on devices
- Try restarting bid listeners: `./stop_mesh.sh && ./start_mesh.sh`

---

## Step 9: Cleanup

### Stop Everything
```bash
./stop_mesh.sh
```

### Clear Logs (Optional)
```bash
adb shell "rm /sdcard/mesh_network/*.log"
adb shell "rm /data/local/tmp/pending_bids.txt"
```

---

## Success Criteria

✅ All 3 bid listeners start successfully  
✅ Monitor shows recent mesh activity (hellos, connections)  
✅ BID_REQUEST broadcast reaches all devices  
✅ Each device calculates LinUCB score  
✅ Responses sent back to orchestrator  
✅ Orchestrator selects device with lowest score  
✅ BidID and features stored in pending_bids.txt  
✅ Winner announced with score and BidID  
✅ Actual SLM execution with llama.cpp  
✅ Feedback packets sent to winner  
✅ LinUCB models trained with real latency  
✅ Matrices update over time (A and b change)  

---

## Complete Feedback Loop Architecture

### Port Assignments
- **5001**: BID_REQUEST (broadcast from orchestrator)
- **5002**: BID_RESPONSE (devices send scores back)
- **5003**: FEEDBACK (orchestrator sends actual latency to winner)

### Data Flow (End-to-End)
```
1. Orchestrator (DeviceB) broadcasts:
   BID_REQUEST|from:DeviceB|prompt_length:20

2. Workers calculate scores and respond:
   DeviceA → score: 6.034475
   DeviceC → score: -1.000215
   DeviceB (self) → score: -1.000015

3. Orchestrator selects winner (lowest score):
   Winner: DeviceB (self-execution)

4. Orchestrator executes SLM:
   cd /data/local/tmp/cppllama-bundle/llama.cpp
   ./build/bin/llama-cli -m models/llama-3.2-3b-instruct-q4_k_m.gguf \
     -p "What is a banana?" -n 50 -no-cnv
   
   Result: "A banana is a long, curved fruit..."
   Latency: 8 seconds

5. Orchestrator sends feedback:
   echo "FEEDBACK|bid_id:self|latency:8" | nc -w 2 localhost 5003

6. Feedback listener (DeviceB) receives:
   - Parses bid_id and latency
   - Looks up features from pending_bids.txt
   - Trains model: lini train state_A.dat state_B.dat 0.275 0.4718 0.02 8

7. LinUCB model updates:
   Matrix A and vector b now reflect actual experience
   Next score will be more accurate!
```

### Learning Convergence
After multiple runs, you should observe:
- **Initial scores**: Very negative (e.g., -1.000215) - optimistic due to uncertainty
- **After 5-10 runs**: Scores become more realistic (e.g., 2.5-8.0)
- **Variance reduction**: Scores stabilize as model gains confidence
- **Device differentiation**: Different devices have different score ranges based on actual performance

---

## Checkpoint Summary

### ✅ Checkpoint 1: Local Brain (LinUCB Solver)
- Binary: `lini` compiled and deployed to all devices
- Commands: `init`, `score`, `train`, `print`
- State files: `state_A.dat` (matrix A), `state_B.dat` (vector b)

### ✅ Checkpoint 2: Self-Aware Bidding
- `bid_listener.sh`: Listens on port 5001, calculates scores, stores features
- `orchestrator.sh`: Broadcasts requests, collects scores, selects winner
- Self-bidding: Orchestrator competes in its own auction
- Score-based selection: Lowest LinUCB score wins

### ✅ Checkpoint 3: Feedback Loop
- **SLM Execution**: Real llama.cpp execution with latency measurement
- **Feedback Packet**: Sent on port 5003 with `bid_id` and `latency`
- **Model Training**: `lini train` updates A and b with actual latency
- **Continuous Learning**: Models improve over time, scores converge

---

## Quick Reference Commands

### Deploy Everything
```bash
./deploy_to_devices.sh
cd device_scripts && ./deploy_lini.sh
```

### Start/Stop Mesh
```bash
./start_mesh.sh        # Start bid + feedback listeners
./stop_mesh.sh         # Stop all listeners
```

### Monitor & Test
```bash
./monitor_live.sh                              # Live monitoring (all logs)
./trigger_orchestrator.sh DeviceB "prompt"     # Trigger orchestration
```

### Check Status
```bash
# Check processes
adb shell "ps -A | grep 'bid_listener\|feedback_listener'"

# View logs
adb -s <serial> shell "cat /sdcard/mesh_network/bid_listener.log"
adb -s <serial> shell "cat /sdcard/mesh_network/feedback_listener.log"
adb -s <serial> shell "cat /sdcard/mesh_network/orchestrator.log"

# Check LinUCB state
adb -s <serial> shell "cd /data/local/tmp && ./lini print state_A.dat state_B.dat"
```

---

## Success Criteria

You know the system is working when:
1. ✅ All devices calculate their own LinUCB scores
2. ✅ Orchestrator selects lowest score (most optimistic)
3. ✅ SLM executes and produces text response
4. ✅ Feedback packet sent to winner
5. ✅ LinUCB matrices update (non-zero values in A and b)
6. ✅ Scores change over time (learning occurs)
7. ✅ No centralized regression server needed
8. ✅ Each device maintains independent local model

**🎉 Fully decentralized, self-learning edge mesh achieved!**

```
