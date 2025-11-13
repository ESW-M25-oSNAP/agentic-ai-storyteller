# P2P Orchestrator Implementation - Summary of Changes

## Overview
Modified the networking architecture from a centralized hub-spoke model to a distributed P2P mesh model where the orchestrator runs on Android devices and coordinates task execution across the mesh network.

## Key Changes

### 1. New Files Created

#### `run_orchestrator.sh`
- **Location**: `networking/run_orchestrator.sh`
- **Purpose**: Launcher script that runs from laptop to trigger orchestrator on a specific Android device
- **Features**:
  - Device mapping from `~/.mesh_device_map`
  - NPU configuration prompt on first run
  - Deploys orchestrator script to device
  - Starts orchestrator via ADB shell

#### `orchestrator_p2p.py`
- **Location**: `networking/src/orchestrator_p2p.py`
- **Purpose**: Main P2P orchestrator implementation
- **Key Features**:
  - Runs on Android devices (not laptop)
  - Uses P2P mesh networking for communication
  - Implements bidding workflow:
    1. Broadcast bid requests
    2. Collect bids from peers
    3. Evaluate bids (NPU-first strategy)
    4. Send task to winner
    5. Collect and display results
  - Persistent device configuration (NPU status)
  - Support for separate NPU and CPU prompts

#### `P2P_ORCHESTRATOR_ARCHITECTURE.md`
- **Location**: `networking/P2P_ORCHESTRATOR_ARCHITECTURE.md`
- **Purpose**: Comprehensive documentation of the P2P architecture
- **Contents**:
  - Architecture overview with diagrams
  - Setup instructions
  - Workflow details for each phase
  - Message format specifications
  - Troubleshooting guide
  - Performance considerations

#### `QUICK_START.sh`
- **Location**: `networking/QUICK_START.sh`
- **Purpose**: Quick reference guide for getting started
- **Contents**:
  - Step-by-step setup instructions
  - Common commands
  - Troubleshooting tips
  - File locations

### 2. Modified Files

#### `mesh_listener.sh`
- **Location**: `networking/p2p/termux/mesh_listener.sh`
- **Changes**:
  - Added system metrics collection functions:
    - `get_cpu_load()` - Calculate CPU usage from `/proc/stat`
    - `get_ram_load()` - Calculate RAM usage from `/proc/meminfo`
    - `get_battery_level()` - Read battery from sysfs
  - Added device configuration handling:
    - `load_device_config()` - Load/create device config
    - `get_has_npu()` - Read NPU status from config
  - New message handlers:
    - `handle_bid_request()` - Respond to bid requests with metrics
    - `handle_task()` - Execute assigned tasks
    - `handle_result()` - Store results from other devices
  - Enhanced message routing:
    - `send_to_peer_by_id()` - Send to peer by device ID
  - Updated message dispatcher to handle new message types

#### `mesh_sender.sh`
- **Location**: `networking/p2p/termux/mesh_sender.sh`
- **Changes**:
  - Added new send commands:
    - `bid_request` - Send/broadcast bid requests
    - `task` - Send task to specific device
    - `raw` - Send raw message (for orchestrator use)
  - Enhanced command help with new options
  - Support for JSON payload transmission

#### `setup_mesh_direct.sh`
- **Location**: `networking/p2p/setup_mesh_direct.sh`
- **Changes**:
  - Creates device map file at `~/.mesh_device_map`
  - Maps device IDs to serial numbers and IP addresses
  - Updated completion message with orchestrator instructions
  - Added device configuration note

## Architecture Changes

### Old Architecture (Hub-Spoke)
```
Laptop (Orchestrator)
   ↓
   TCP Socket
   ↓
Android Devices (Clients)
```

- Orchestrator runs on laptop/server
- Devices connect as clients via TCP
- C++ DeviceClient required
- Centralized coordination

### New Architecture (P2P Mesh)
```
Laptop (Control)
   ↓
   ADB Trigger
   ↓
Android Device (Orchestrator)
   ↓
   P2P Mesh Network (netcat)
   ↓
Android Devices (Peers)
```

- Orchestrator runs on Android device
- P2P communication via mesh network
- Shell scripts only (no C++ build needed)
- Distributed coordination

## Workflow Comparison

### Old Workflow
1. Start orchestrator on laptop
2. Devices register to orchestrator
3. Send image/task from laptop
4. Orchestrator evaluates metrics
5. Task sent to selected device
6. Result returned to orchestrator

### New Workflow
1. Setup mesh network on all devices
2. Start mesh listeners on all devices
3. Launch orchestrator on one device (from laptop)
4. Submit prompt to orchestrator
5. Orchestrator broadcasts bid request
6. Devices respond with bids
7. Orchestrator selects winner (NPU-first)
8. Task sent with appropriate prompt
9. Winner executes SLM
10. Result returned and displayed

## Bidding Logic

### NPU-First Strategy

```python
if devices_with_npu:
    winner = device_with_npu_and_lowest_cpu
else:
    winner = device_with_lowest_cpu
```

### Metrics Considered
- **has_npu**: Boolean (from device_config.json)
- **cpu_load**: Float 0.0-1.0 (from /proc/stat)
- **ram_load**: Float 0.0-1.0 (from /proc/meminfo)
- **battery**: Integer 0-100 (from sysfs)

### Selection Priority
1. **Primary**: NPU availability
2. **Secondary**: Lowest CPU load

## Message Protocol

### Message Format
```
TYPE|FROM_DEVICE|PAYLOAD
```

### New Message Types

#### BID_REQUEST
```
BID_REQUEST|Device_A|{"task_id": "...", "task_type": "...", "prompt": "...", "deadline": 10}
```

#### BID_RESPONSE
```
BID_RESPONSE|Device_B|{"device_id": "...", "cpu_load": 0.45, "ram_load": 0.60, "battery": 85, "has_npu": true}
```

#### TASK
```
TASK|Device_A|{"task_id": "...", "prompt": "...", "use_npu": true, "prompt_type": "npu_prompt"}
```

#### RESULT
```
RESULT|Device_B|{"task_id": "...", "device_id": "...", "status": "completed", "output": "..."}
```

## Configuration Files

### Device Map (`~/.mesh_device_map`)
Created by setup script, used by orchestrator launcher
```
# Device Map for Mesh Network
# Format: DeviceID:Serial:IP
Device_A:abc123:192.168.1.101
Device_B:def456:192.168.1.102
Device_C:ghi789:192.168.1.103
```

### Device Config (`/data/local/tmp/mesh/device_config.json`)
Stored on each device, persists NPU configuration
```json
{
  "device_id": "Device_A",
  "has_npu": true
}
```

## NPU Configuration

### First-Time Setup
When running orchestrator for first time on a device:
```bash
$ ./run_orchestrator.sh Device_A
Does this device have NPU? (y/n): y
✓ Configuration saved
```

### Manual Configuration
```bash
$ adb shell
# echo '{"device_id": "Device_A", "has_npu": true}' > /data/local/tmp/mesh/device_config.json
```

### Configuration Persistence
- Stored per-device in `/data/local/tmp/mesh/device_config.json`
- Survives app restarts
- Used for all future bid responses
- Can be updated anytime

## Prompt Handling

### Dual Prompt System
The orchestrator supports different prompts for NPU vs CPU:

```python
orchestrator.run_inference_task(
    prompt="Base prompt",
    use_npu_prompt="[NPU Optimized] Enhanced prompt",
    use_cpu_prompt="[CPU Mode] Simplified prompt"
)
```

### Selection Logic
- If winner has NPU → use `npu_prompt`
- If winner is CPU-only → use `cpu_prompt`
- If specific prompt not provided → use base `prompt`

## Deployment Differences

### Old Approach (Hub-Spoke)
1. Build C++ client on each device
2. Start orchestrator on laptop
3. Run agent binary on each device
4. Devices connect to orchestrator

### New Approach (P2P Mesh)
1. Run setup script once from laptop
2. Start mesh listeners on devices
3. Launch orchestrator on any device
4. All communication via mesh

## Benefits of P2P Architecture

1. **No central point of failure**: Orchestrator can run on any device
2. **Simpler deployment**: Shell scripts instead of C++ binaries
3. **Better scalability**: Distributed coordination
4. **Device autonomy**: Devices calculate their own metrics
5. **Flexible topology**: Easy to add/remove devices
6. **Persistent configuration**: NPU settings saved per-device

## Usage Examples

### Basic Usage
```bash
# Setup
cd networking/p2p
./setup_mesh_direct.sh

# Start listeners
./start_mesh_A.sh  # Terminal 1
./start_mesh_B.sh  # Terminal 2

# Run orchestrator
cd ../networking
./run_orchestrator.sh Device_A

# Submit task
> Describe a beautiful sunset
```

### Check Status
```bash
# View device map
cat ~/.mesh_device_map

# Check mesh status
cd networking/p2p
./check_mesh_status.sh

# View logs
adb shell cat /data/local/tmp/mesh/mesh_Device_A.log
```

### Update NPU Config
```bash
adb shell 'echo "{\"device_id\": \"Device_A\", \"has_npu\": true}" > /data/local/tmp/mesh/device_config.json'
```

## Testing Checklist

- [ ] Setup mesh network with 3+ devices
- [ ] Start mesh listeners on all devices
- [ ] Launch orchestrator on Device_A
- [ ] Configure NPU settings
- [ ] Submit inference task
- [ ] Verify bid collection
- [ ] Verify NPU device selected (if available)
- [ ] Verify task execution
- [ ] Verify result display
- [ ] Test with CPU-only devices
- [ ] Test configuration persistence
- [ ] Test error handling

## Known Limitations

1. **No concurrent tasks**: Orchestrator handles one task at a time
2. **No authentication**: All communication is unauthenticated
3. **Basic JSON parsing**: Uses grep/cut instead of proper JSON parser
4. **Fixed timeouts**: Hardcoded bid/result timeouts
5. **Network assumptions**: Assumes reliable local network
6. **No load balancing**: Single winner per task

## Future Enhancements

1. Support for multiple concurrent tasks
2. Load balancing across multiple NPU devices
3. Historical performance tracking for better selection
4. Automatic NPU detection (no manual config)
5. Encrypted mesh communication
6. Web UI for orchestrator control
7. Task priority queues
8. Real-time device health monitoring

## Files Summary

### Created (4 files)
- `networking/run_orchestrator.sh` - Orchestrator launcher
- `networking/src/orchestrator_p2p.py` - P2P orchestrator
- `networking/P2P_ORCHESTRATOR_ARCHITECTURE.md` - Documentation
- `networking/QUICK_START.sh` - Quick reference

### Modified (3 files)
- `networking/p2p/termux/mesh_listener.sh` - Enhanced message handling
- `networking/p2p/termux/mesh_sender.sh` - Added new message types
- `networking/p2p/setup_mesh_direct.sh` - Device map creation

### Total Changes
- ~1,200 lines added/modified
- 4 new files created
- 3 files enhanced
- Complete architecture transformation

## Backward Compatibility

The original hub-spoke architecture remains intact:
- `networking/src/orchestrator.py` - Original orchestrator
- `networking/src/DeviceClient.cpp` - Original C++ client
- `networking/hubspoke/` - Hub-spoke scripts

Users can choose which architecture to use based on their needs.
