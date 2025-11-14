# Orchestrator Usage Guide

## Overview
The orchestrator allows one device to collect "bids" from all other devices in the mesh network and select the best device for task execution based on NPU availability and CPU load.

## Setup

### 1. Configure devices with NPU information
Run the setup script and answer whether each device has an NPU:
```bash
./setup_configs.sh
```

### 2. Deploy to devices
Deploy the updated mesh_node.sh and configs to all devices:
```bash
./deploy_to_devices.sh
```

### 3. Start the mesh network
Start the mesh network on all connected devices:
```bash
./start_mesh.sh
```

## Using the Orchestrator

### Trigger orchestrator on a specific device
```bash
./trigger_orchestrator.sh <device_name>
```

Example:
```bash
./trigger_orchestrator.sh DeviceA
```

This will:
1. Enable orchestrator mode on the specified device
2. The device broadcasts "bid_request" messages to all peers
3. All peer devices respond with their bid containing:
   - `has_npu`: whether the device has an NPU
   - `cpu_load`: current CPU load
   - `ram_load`: current RAM usage percentage
   - `npu_free`: whether the NPU is available (true initially)
4. The orchestrator evaluates all bids and selects the best device

### Selection Criteria

**Priority 1: NPU with availability**
- If any device has `has_npu=true` AND `npu_free=true`
- Orchestrator prints: "✓ NPU chosen: <device_name>"

**Priority 2: Lowest CPU load**
- If no NPU is available (either no device has NPU or all NPUs are busy)
- Orchestrator prints: "✓ Lowest CPU load chosen: <device_name> (CPU: <load>)"

## Viewing Results

### Check orchestrator logs
```bash
adb -s <device_serial> shell cat /sdcard/mesh_network/orchestrator.log
```

### Check mesh logs
```bash
adb -s <device_serial> shell tail -f /sdcard/mesh_network/mesh.log
```

### Device serials
- DeviceA: 60e0c72f
- DeviceB: 9688d142
- DeviceC: RZCT90P1WAK

## Message Flow

1. **Normal mode**: Devices send "hello" messages to peers every 5 seconds
2. **Orchestrator triggered**: Selected device switches to "bid_request" mode
3. **Peers respond**: All peers send "bid" messages back with their metrics
4. **Evaluation**: Orchestrator evaluates bids and selects best device
5. **Return to normal**: After evaluation, orchestrator mode is cleared

## Bid Message Format

```json
{
  "type": "bid",
  "from": "DeviceA",
  "has_npu": true,
  "cpu_load": 0.45,
  "ram_load": 52,
  "npu_free": true
}
```

## Notes

- The `npu_free` flag is initialized to `true` for devices with NPU
- In future checkpoints, this flag will be set to `false` when NPU is in use
- CPU and RAM metrics are read from `/proc/loadavg` and `/proc/meminfo`
- The orchestrator automatically exits orchestrator mode after one evaluation round
