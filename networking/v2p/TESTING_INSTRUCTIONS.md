# Testing Instructions - LinUCB Checkpoint 2

Complete step-by-step guide to test the decentralized LinUCB bidding system.

## Prerequisites

✅ 3 Android devices connected via ADB  
✅ All devices on same WiFi network  
✅ Termux installed on devices (for building LinUCB binary)  
✅ Netcat installed on devices (`pkg install netcat-openbsd`)

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
```

---

## Step 6: Verify LinUCB Functionality

### 6.1 Check Pending Bids Are Stored
```bash
adb -s RZCT90P1WAK shell "cat /data/local/tmp/pending_bids.txt"
```

Expected output (features stored for feedback):
```
bid_1763218297896_DeviceC,0.1610,0.6600,0.0200,1731685822
```

### 6.2 Verify LinUCB Matrices Are Being Used
```bash
adb -s RZCT90P1WAK shell "cd /data/local/tmp && ./lini print state_A.dat state_B.dat"
```

Expected output:
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

(Fresh initialization - will update after feedback loop in Checkpoint 3)

### 6.3 Test Multiple Orchestrations
```bash
# Trigger from different devices
./trigger_orchestrator.sh DeviceA "Tell me about AI"
sleep 35
./trigger_orchestrator.sh DeviceC "What is machine learning?"
sleep 35
./trigger_orchestrator.sh DeviceB "Explain neural networks"
```

Watch monitor - you should see different scores based on each device's current CPU/RAM load.

---

## Step 7: Understanding the Output

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

## Step 8: Troubleshooting

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

---

## Next Steps

Once Checkpoint 2 is verified:
- **Checkpoint 3**: Implement feedback loop
  - Measure actual SLM execution latency
  - Send FEEDBACK_PACKET to winner
  - Train LinUCB model with actual latency
  - Watch matrices update over time
  - See scores converge from optimistic to realistic
