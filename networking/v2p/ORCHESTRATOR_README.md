# Orchestrator System - Checkpoint 2

This implements the orchestrator system where devices bid for tasks based on their capabilities.

## Overview

The orchestrator system consists of:
1. **Bid Listeners** - Run continuously on each device to respond to bid requests
2. **Orchestrator** - Runs on a selected device to request bids and choose the best device
3. **Trigger Script** - Runs on laptop to start the orchestrator on any device

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Laptop                             │
│  ./trigger_orchestrator.sh DeviceA                      │
└──────────────────────┬──────────────────────────────────┘
                       │ (via ADB)
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   DeviceA (Orchestrator)                │
│  1. Broadcasts BID_REQUEST to all peers                 │
│  2. Collects bid responses                              │
│  3. Evaluates bids                                      │
│  4. Selects best device                                 │
└──────────────────────┬──────────────────────────────────┘
                       │ BID_REQUEST
         ┌─────────────┴─────────────┐
         ▼                           ▼
┌──────────────────┐        ┌──────────────────┐
│    DeviceB       │        │    DeviceC       │
│  (Bid Listener)  │        │  (Bid Listener)  │
│                  │        │                  │
│ 1. Collects      │        │ 1. Collects      │
│    metrics       │        │    metrics       │
│ 2. Sends bid     │        │ 2. Sends bid     │
└──────────────────┘        └──────────────────┘
```

## Bid Evaluation Logic

As specified in working.txt Checkpoint 2:

1. **If `has_npu == true` AND `free_npu == true`**:
   - Choose device with available NPU
   - Print: "✓ NPU chosen: DeviceX"

2. **If `has_npu == false` OR `free_npu == false`**:
   - Choose device with lowest CPU load
   - Print: "✓ Lowest CPU load chosen: DeviceX (CPU: Y%)"

## Components

### Device Scripts (in `/sdcard/mesh_network/`)

1. **collect_metrics.sh**
   - Collects system metrics from the device
   - Reads NPU configuration from device_config.json
   - Calculates CPU load and RAM usage
   - Returns: `has_npu,free_npu,cpu_load,ram_percent`

2. **bid_listener.sh**
   - Runs continuously on port 5001
   - Listens for BID_REQUEST messages
   - Responds with device metrics on port 5002
   - Logs all activity to bid_listener.log

3. **orchestrator.sh**
   - Broadcasts bid requests to all peers
   - Collects responses for 10 seconds
   - Evaluates bids based on the logic above
   - Prints the chosen device
   - Logs detailed decision process

### Laptop Scripts (in `networking/v2p/`)

1. **deploy_orchestrator.sh**
   - Deploys all orchestrator scripts to devices
   - Sets proper permissions
   - Usage: `./deploy_orchestrator.sh`

2. **start_bid_listeners.sh**
   - Starts bid listeners on all connected devices
   - Usage: `./start_bid_listeners.sh`

3. **stop_bid_listeners.sh**
   - Stops bid listeners on all devices
   - Usage: `./stop_bid_listeners.sh`

4. **trigger_orchestrator.sh**
   - Triggers orchestrator on a specific device
   - Usage: `./trigger_orchestrator.sh <DeviceA|DeviceB|DeviceC>`

## Setup Instructions

### 1. Configure NPU Settings

First, ensure your device configs have NPU information:

```bash
# Option A: Update existing configs
./update_npu_configs.sh

# Option B: Create new configs from scratch
./setup_configs.sh
```

### 2. Deploy Orchestrator Scripts

Deploy the orchestrator components to all devices:

```bash
./deploy_orchestrator.sh
```

### 3. Start Bid Listeners

Start bid listeners on all devices (they listen for bid requests):

```bash
./start_bid_listeners.sh
```

Verify they're running:
```bash
adb shell ps -A | grep bid_listener
```

### 4. Trigger Orchestrator

Run the orchestrator on any device to start the bidding process:

```bash
./trigger_orchestrator.sh DeviceA
```

Output example:
```
=========================================
Triggering Orchestrator on DeviceA
=========================================

✓ Found DeviceA on device 60e0c72f

Starting orchestrator on DeviceA...
=========================================

✓ NPU chosen: DeviceB

=========================================
Orchestrator completed on DeviceA
=========================================
```

## Bid Message Format

### BID_REQUEST
```
BID_REQUEST|from:<orchestrator_ip>
```

### BID_RESPONSE
```
BID_RESPONSE|device:<name>|has_npu:<bool>|free_npu:<bool>|cpu_load:<float>|ram_load:<float>
```

## Ports Used

- **Port 5000**: Mesh network communication (existing)
- **Port 5001**: Bid request listener
- **Port 5002**: Bid response receiver

## Troubleshooting

### No bids received
```bash
# Check if bid listeners are running
adb shell ps -A | grep bid_listener

# Restart bid listeners
./stop_bid_listeners.sh
./start_bid_listeners.sh
```

### View logs on a specific device
```bash
# Bid listener log
adb -s <device_serial> shell cat /sdcard/mesh_network/bid_listener.log

# Orchestrator log
adb -s <device_serial> shell cat /sdcard/mesh_network/orchestrator.log
```

### Check device metrics manually
```bash
adb -s <device_serial> shell "cd /sdcard/mesh_network && sh collect_metrics.sh"
```

### Port already in use
```bash
# Kill processes on specific port
adb shell "lsof -i :5001"
adb shell "kill -9 <pid>"
```

## Testing the System

### Test 1: NPU Available
```bash
# Configure DeviceB with has_npu=true, free_npu=true
./trigger_orchestrator.sh DeviceA
# Expected: "✓ NPU chosen: DeviceB"
```

### Test 2: No NPU Available
```bash
# Configure all devices with has_npu=false or free_npu=false
./trigger_orchestrator.sh DeviceA
# Expected: "✓ Lowest CPU load chosen: DeviceX (CPU: Y%)"
```

### Test 3: Different Orchestrators
```bash
# Try triggering from different devices
./trigger_orchestrator.sh DeviceA
./trigger_orchestrator.sh DeviceB
./trigger_orchestrator.sh DeviceC
```

## Next Steps (Checkpoint 3 & 4)

The current implementation handles bid collection and device selection. Future work:

- **Checkpoint 3**: Send NPU_prompt to chosen NPU device, execute, return results
- **Checkpoint 4**: Send CPU_prompt to chosen CPU device, execute, return results
- Implement `free_npu` state management (set to false when in use)
- Add prompt execution capabilities
- Add result forwarding back to orchestrator

## File Structure

```
networking/v2p/
├── device_scripts/           # Scripts that run on Android devices
│   ├── collect_metrics.sh   # Collect system metrics
│   ├── bid_listener.sh      # Listen for bid requests
│   └── orchestrator.sh      # Run orchestrator logic
├── deploy_orchestrator.sh   # Deploy scripts to devices
├── start_bid_listeners.sh   # Start listeners on all devices
├── stop_bid_listeners.sh    # Stop listeners on all devices
├── trigger_orchestrator.sh  # Trigger orchestrator on a device
└── ORCHESTRATOR_README.md   # This file
```
