# P2P Orchestrator Architecture

## Overview

This document describes the updated P2P mesh orchestrator architecture for distributing inference tasks across multiple Android devices. The orchestrator itself runs **on an Android device** in the mesh network and coordinates task execution using P2P communication.

## Architecture

### Key Components

1. **P2P Orchestrator (`orchestrator_p2p.py`)**: Runs on one Android device and coordinates the entire workflow
2. **Mesh Listener (`mesh_listener.sh`)**: Runs on each device to receive and handle messages
3. **Mesh Sender (`mesh_sender.sh`)**: Used to send messages between devices
4. **Device Configuration (`device_config.json`)**: Stores persistent device settings including NPU availability

### Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Laptop (Control)                         │
│  $ ./run_orchestrator.sh Device_A                           │
└───────────────┬─────────────────────────────────────────────┘
                │ (triggers via ADB)
                ▼
┌─────────────────────────────────────────────────────────────┐
│              Device_A (Orchestrator)                        │
│  • orchestrator_p2p.py running                              │
│  • Broadcasts BID_REQUEST to all peers                      │
└──┬──────────────────────────────────────────────────────┬───┘
   │                                                       │
   │ BID_REQUEST                                           │ BID_REQUEST
   ▼                                                       ▼
┌──────────────────────┐                        ┌──────────────────────┐
│    Device_B          │                        │    Device_C          │
│  • mesh_listener.sh  │                        │  • mesh_listener.sh  │
│  • Calculates metrics│                        │  • Calculates metrics│
│  • Sends BID_RESPONSE│                        │  • Sends BID_RESPONSE│
└──────┬───────────────┘                        └───────┬──────────────┘
       │                                                 │
       │ BID_RESPONSE (CPU, RAM, Battery, NPU)          │
       ▼                                                 ▼
┌─────────────────────────────────────────────────────────────┐
│              Device_A (Orchestrator)                        │
│  • Evaluates bids                                           │
│  • Selects winner (NPU-first, then lowest CPU)              │
│  • Sends TASK to winner                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ TASK (with prompt)
                       ▼
                ┌──────────────────────┐
                │    Winner Device     │
                │  • Executes SLM      │
                │  • Sends RESULT back │
                └──────┬───────────────┘
                       │
                       │ RESULT
                       ▼
                ┌─────────────────────────────────────────────┐
                │       Device_A (Orchestrator)               │
                │  • Displays result                          │
                └─────────────────────────────────────────────┘
```

## Setup

### 1. Configure Mesh Network

First, set up the P2P mesh network across all devices:

```bash
cd networking/p2p
./setup_mesh_direct.sh
```

This will:
- Deploy mesh scripts to all connected devices
- Configure peer lists
- Create device map file (`~/.mesh_device_map`)
- Prompt for NPU configuration for each device

### 2. Start Mesh Listeners

On each device, start the mesh listener in separate terminals:

```bash
./start_mesh_A.sh
./start_mesh_B.sh
./start_mesh_C.sh
```

### 3. Configure NPU Settings

When running the orchestrator for the first time on a device, you'll be prompted to configure NPU availability:

```bash
cd networking
./run_orchestrator.sh Device_A
```

The script will ask:
```
Does this device have NPU? (y/n):
```

This configuration is saved to `/data/local/tmp/mesh/device_config.json` and persists across runs.

## Usage

### Running the Orchestrator

From your laptop, trigger the orchestrator on any device:

```bash
./run_orchestrator.sh <device_name>
```

Example:
```bash
./run_orchestrator.sh Device_A
```

### Interactive Mode

Once started, the orchestrator enters interactive mode:

```
P2P MESH ORCHESTRATOR
================================================================================

Connected Peers: 2
  - Device_B (192.168.1.102:9999)
  - Device_C (192.168.1.103:9999)

Enter prompt for inference (or 'exit' to quit):

> Describe a beautiful sunset over the ocean
```

## Workflow Details

### 1. Bid Request Phase

When you submit a prompt, the orchestrator:
1. Generates a unique `task_id`
2. Broadcasts a `BID_REQUEST` message to all connected peers
3. Waits for bid responses (default: 10 seconds)

Message format:
```
BID_REQUEST|Device_A|{"task_id": "task_123", "task_type": "slm_inference", "prompt": "...", "deadline": 10}
```

### 2. Bid Response Phase

Each device receives the bid request and:
1. Reads its `device_config.json` for NPU status
2. Calculates current metrics:
   - CPU load (from `/proc/stat`)
   - RAM usage (from `/proc/meminfo`)
   - Battery level (from `/sys/class/power_supply/battery/capacity`)
3. Sends a `BID_RESPONSE` back to orchestrator

Response format:
```
BID_RESPONSE|Device_B|{"device_id": "Device_B", "cpu_load": 0.45, "ram_load": 0.60, "battery": 85, "has_npu": true}
```

### 3. Bid Evaluation Phase

The orchestrator evaluates bids using **NPU-first strategy**:

1. **Check for NPU devices**: If any device has NPU, select the one with lowest CPU load
2. **Fallback to CPU**: If no NPU devices, select device with lowest CPU load

Example output:
```
================================================================================
🎯 EVALUATING BIDS (NPU-First Strategy)
================================================================================

Device: Device_B
  NPU: ✓ YES
  CPU Load: 45.20%
  Battery: 85%

Device: Device_C
  NPU: ✗ NO
  CPU Load: 32.10%
  Battery: 92%

🏆 WINNER (NPU Priority): Device_B

📊 Winner Details:
   Device: Device_B
   Type: NPU
   CPU Load: 45.20%
   Battery: 85%
================================================================================
```

### 4. Task Execution Phase

The orchestrator sends the task to the winner:

1. Selects appropriate prompt:
   - `npu_prompt` if winner has NPU
   - `cpu_prompt` if CPU-only device
2. Sends `TASK` message with prompt and execution mode

Message format:
```
TASK|Device_A|{"task_id": "task_123", "prompt": "[NPU Optimized] Describe...", "use_npu": true, "prompt_type": "npu_prompt"}
```

The winning device:
1. Receives the task
2. Creates a prompt file
3. Executes `run_slm.sh` with the prompt
4. Captures output
5. Sends `RESULT` back to orchestrator

### 5. Result Collection Phase

The orchestrator:
1. Waits for result (timeout: 300 seconds)
2. Displays the output
3. Cleans up temporary files

Result format:
```
RESULT|Device_B|{"task_id": "task_123", "device_id": "Device_B", "status": "completed", "output": "..."}
```

## Device Configuration

### Configuration File Location
`/data/local/tmp/mesh/device_config.json`

### Format
```json
{
  "device_id": "Device_A",
  "has_npu": true
}
```

### Updating NPU Configuration

To change NPU configuration for a device:

1. Connect to device via ADB:
```bash
adb shell
```

2. Edit configuration:
```bash
cd /data/local/tmp/mesh
echo '{"device_id": "Device_A", "has_npu": true}' > device_config.json
```

3. Restart mesh listener:
```bash
# Kill existing listener
pkill -f mesh_listener.sh

# Restart from laptop
./start_mesh_A.sh
```

## Message Types

### BID_REQUEST
Sent by orchestrator to request bids from all devices.

**Format**: `BID_REQUEST|<orchestrator_id>|<json_data>`

**JSON Data**:
```json
{
  "task_id": "task_123",
  "task_type": "slm_inference",
  "prompt": "original prompt",
  "deadline": 10
}
```

### BID_RESPONSE
Sent by devices in response to bid requests.

**Format**: `BID_RESPONSE|<device_id>|<json_data>`

**JSON Data**:
```json
{
  "device_id": "Device_B",
  "cpu_load": 0.45,
  "ram_load": 0.60,
  "battery": 85,
  "has_npu": true
}
```

### TASK
Sent by orchestrator to winning device.

**Format**: `TASK|<orchestrator_id>|<json_data>`

**JSON Data**:
```json
{
  "task_id": "task_123",
  "prompt": "Execute this prompt",
  "use_npu": true,
  "prompt_type": "npu_prompt"
}
```

### RESULT
Sent by device after completing task.

**Format**: `RESULT|<device_id>|<json_data>`

**JSON Data**:
```json
{
  "task_id": "task_123",
  "device_id": "Device_B",
  "status": "completed",
  "output": "Generated text..."
}
```

## File Structure

```
networking/
├── run_orchestrator.sh          # Launcher script (run from laptop)
├── src/
│   ├── orchestrator_p2p.py      # P2P orchestrator implementation
│   ├── orchestrator.py          # Original hub-spoke orchestrator
│   └── DeviceClient.cpp         # C++ client (deprecated for P2P)
├── p2p/
│   ├── setup_mesh_direct.sh     # Mesh network setup
│   ├── start_mesh_A.sh          # Start listener on Device A
│   ├── start_mesh_B.sh          # Start listener on Device B
│   ├── start_mesh_C.sh          # Start listener on Device C
│   └── termux/
│       ├── mesh_listener.sh     # Enhanced with bid/task support
│       ├── mesh_sender.sh       # Enhanced with new message types
│       └── run_slm.sh          # SLM execution script
└── build/                       # C++ build artifacts (not used for P2P)
```

## Troubleshooting

### Orchestrator won't start

**Check device map exists**:
```bash
cat ~/.mesh_device_map
```

If missing, run `./setup_mesh_direct.sh` again.

**Check device is connected**:
```bash
adb devices
```

### No bids received

**Check mesh listeners are running**:
```bash
./check_mesh_status.sh
```

**Check peer configuration**:
```bash
adb shell cat /data/local/tmp/mesh/peers.txt
```

### Device not responding

**Check device logs**:
```bash
adb shell cat /data/local/tmp/mesh/mesh_Device_A.log
```

**Restart mesh listener**:
```bash
# From laptop
./start_mesh_A.sh
```

### NPU not being used

**Check device configuration**:
```bash
adb shell cat /data/local/tmp/mesh/device_config.json
```

**Update NPU setting**:
```bash
adb shell 'echo "{\"device_id\": \"Device_A\", \"has_npu\": true}" > /data/local/tmp/mesh/device_config.json'
```

## Advanced Configuration

### Adjusting Bid Timeout

Edit `orchestrator_p2p.py`:
```python
self.bid_timeout = 10  # Change to desired seconds
```

### Adjusting Result Timeout

Edit `orchestrator_p2p.py`:
```python
def wait_for_result(self, task_id, timeout=300):  # Change timeout value
```

### Custom Prompts

You can specify different prompts for NPU and CPU devices:

```python
result = orchestrator.run_inference_task(
    prompt="Base prompt",
    use_npu_prompt="[Optimized for NPU] Enhanced prompt",
    use_cpu_prompt="[CPU Mode] Simplified prompt"
)
```

## Differences from Hub-Spoke Architecture

| Feature | Hub-Spoke (Old) | P2P Mesh (New) |
|---------|----------------|----------------|
| Orchestrator Location | Laptop/Server | Android Device |
| Communication | TCP Socket (Client-Server) | P2P Mesh Network |
| Device Discovery | Manual Registration | Peer List |
| Message Transport | JSON over TCP | Pipe-delimited over netcat |
| NPU Configuration | At runtime | Persistent config file |
| Scalability | Limited by server | Distributed |
| Deployment | Requires C++ build | Shell scripts only |

## Performance Considerations

- **Bid timeout**: 10 seconds is usually sufficient for 3-5 devices
- **Result timeout**: 300 seconds (5 minutes) for complex SLM tasks
- **Network latency**: P2P adds ~100-500ms overhead vs hub-spoke
- **CPU metrics**: Calculated over 500ms window for accuracy

## Security Notes

- All communication is unencrypted (local network only)
- No authentication between devices
- SLM execution runs with device user permissions
- File paths are hardcoded to `/data/local/tmp/mesh/`

## Future Enhancements

- [ ] Support for multiple concurrent tasks
- [ ] Load balancing across multiple NPU devices
- [ ] Historical performance tracking
- [ ] Automatic NPU detection
- [ ] Encrypted P2P communication
- [ ] Web UI for orchestrator control
- [ ] Task priority queues
- [ ] Device health monitoring
