# Hub-Spoke vs P2P Mesh - Comparison

## Quick Reference

| Aspect | Hub-Spoke (Old) | P2P Mesh (New) |
|--------|-----------------|----------------|
| **Orchestrator Location** | Laptop/Server | Android Device |
| **Communication** | TCP Socket | P2P Mesh (netcat) |
| **Language** | C++ Client + Python Orchestrator | Shell Scripts + Python Orchestrator |
| **Setup Complexity** | High (C++ build required) | Low (scripts only) |
| **Device Registration** | Manual TCP connection | Automatic peer discovery |
| **Message Format** | JSON over TCP | Pipe-delimited over UDP |
| **NPU Configuration** | Runtime parameter | Persistent config file |
| **Deployment** | Build on each device | Deploy scripts once |
| **Scalability** | Limited by server | Distributed |
| **Failure Mode** | Single point of failure | Distributed resilience |
| **Network Topology** | Star | Mesh |
| **Latency** | ~50-200ms | ~100-500ms |

## Architecture Diagrams

### Hub-Spoke (Old)
```
                    ┌─────────────┐
                    │   Laptop    │
                    │ (Orchestr.) │
                    └──────┬──────┘
                           │ TCP Socket
                ┌──────────┼──────────┐
                │          │          │
                ▼          ▼          ▼
        ┌───────────┐ ┌───────────┐ ┌───────────┐
        │ Device A  │ │ Device B  │ │ Device C  │
        │ (Client)  │ │ (Client)  │ │ (Client)  │
        └───────────┘ └───────────┘ └───────────┘
```

### P2P Mesh (New)
```
        ┌─────────────┐
        │   Laptop    │
        │  (Control)  │
        └──────┬──────┘
               │ ADB Trigger
               ▼
        ┌─────────────┐
        │  Device A   │◄─────────┐
        │(Orchestr.)  │          │
        └──────┬──────┘          │
               │                 │
        P2P    │    Mesh         │ P2P
               │                 │
        ┌──────┴──────┐          │
        │             │          │
        ▼             ▼          │
   ┌─────────┐   ┌─────────┐    │
   │Device B │   │Device C │    │
   │ (Peer)  │───│ (Peer)  │────┘
   └─────────┘   └─────────┘
        P2P Mesh Network
```

## Workflow Comparison

### Hub-Spoke: Image Classification

```
1. Laptop: Start orchestrator (port 8080)
2. Devices: Connect to laptop:8080
3. Devices: Register with metrics
4. Laptop: Receive image
5. Laptop: Request bids
6. Devices: Send bids
7. Laptop: Select winner
8. Laptop: Send image to winner
9. Winner: Process image
10. Winner: Send result to laptop
11. Laptop: Display result
```

### P2P Mesh: SLM Inference

```
1. Laptop: Setup mesh network
2. Devices: Start mesh listeners
3. Laptop: Trigger orchestrator on Device_A
4. Device_A: Submit prompt
5. Device_A: Broadcast BID_REQUEST
6. All Peers: Calculate metrics
7. All Peers: Send BID_RESPONSE
8. Device_A: Evaluate (NPU-first)
9. Device_A: Send TASK to winner
10. Winner: Execute SLM
11. Winner: Send RESULT
12. Device_A: Display result
```

## Message Flow

### Hub-Spoke Messages

```json
// Registration
{
  "type": "register",
  "agent_id": "Device_A",
  "data": {
    "deviceId": "Device_A",
    "hasNpu": true,
    "capabilities": ["classify"],
    "metrics": { "cpu_load": 0.45, "battery": 85 }
  }
}

// Bid Request
{
  "type": "bid_request",
  "agent_id": "orchestrator",
  "task_id": "task_123",
  "data": { "task_type": "classification" }
}

// Task Assignment
{
  "type": "task",
  "task_id": "task_123",
  "data": { "image_base64": "..." }
}
```

### P2P Mesh Messages

```
// Bid Request
BID_REQUEST|Device_A|{"task_id":"task_123","prompt":"...","deadline":10}

// Bid Response
BID_RESPONSE|Device_B|{"device_id":"Device_B","cpu_load":0.45,"battery":85,"has_npu":true}

// Task Assignment
TASK|Device_A|{"task_id":"task_123","prompt":"...","use_npu":true}

// Result
RESULT|Device_B|{"task_id":"task_123","status":"completed","output":"..."}
```

## Selection Algorithm

### Hub-Spoke: Weighted Scoring

```python
score = (
    (40 if has_npu else 0) +
    battery_score +  # 0-25 points
    cpu_score +      # 0-10 points
    ram_score        # 0-15 points
)
winner = max(scores)
```

### P2P Mesh: NPU-First

```python
if devices_with_npu:
    winner = min(devices_with_npu, key=lambda d: d.cpu_load)
else:
    winner = min(all_devices, key=lambda d: d.cpu_load)
```

## Configuration

### Hub-Spoke
```cpp
// C++ Client - main.cpp
DeviceClient client("192.168.1.100", 8080, "Device_A");
client.has_npu = true;  // Runtime configuration
client.connect();
```

### P2P Mesh
```json
// device_config.json (persistent)
{
  "device_id": "Device_A",
  "has_npu": true
}
```

## Deployment Steps

### Hub-Spoke
```bash
# On Laptop
cd networking/hubspoke
python3 run_orchestrator.py

# On Each Device (via ADB)
cd networking/build
cmake ..
make
./agent 192.168.1.100 8080 Device_A
```

### P2P Mesh
```bash
# Setup (once)
cd networking/p2p
./setup_mesh_direct.sh

# Start Listeners (once per session)
./start_mesh_A.sh  # Terminal 1
./start_mesh_B.sh  # Terminal 2
./start_mesh_C.sh  # Terminal 3

# Run Orchestrator
cd ../networking
./run_orchestrator.sh Device_A
```

## Performance Characteristics

### Hub-Spoke
- **Latency**: 50-200ms (direct TCP)
- **Throughput**: Limited by server CPU
- **Concurrent Tasks**: Multiple (with queue)
- **Network Load**: Star topology (N connections to server)
- **Failure Recovery**: Requires server restart

### P2P Mesh
- **Latency**: 100-500ms (mesh routing)
- **Throughput**: Distributed load
- **Concurrent Tasks**: Currently single (can be enhanced)
- **Network Load**: Mesh topology (N*(N-1)/2 potential connections)
- **Failure Recovery**: Any device can be orchestrator

## Use Cases

### When to Use Hub-Spoke
- ✅ Need centralized control
- ✅ Want to handle many concurrent tasks
- ✅ Have reliable server/laptop always available
- ✅ Need minimal network latency
- ✅ Existing C++ infrastructure

### When to Use P2P Mesh
- ✅ Want distributed system
- ✅ No dedicated server available
- ✅ Devices should work independently
- ✅ Easier deployment preferred
- ✅ Resilience to single device failure important

## Migration Path

### From Hub-Spoke to P2P Mesh

1. **Keep existing hub-spoke** for production use
2. **Setup P2P mesh** on test devices
3. **Test workflows** with P2P orchestrator
4. **Compare performance** metrics
5. **Gradually migrate** tasks to P2P
6. **Maintain both** for different use cases

### Code Reuse

Both architectures share:
- Mesh network scripts (P2P foundation)
- SLM execution scripts (run_slm.sh)
- Device metric collection (similar logic)
- Peer management (adapted for each)

## Troubleshooting Decision Tree

```
Problem: Orchestrator not working
├─ Hub-Spoke
│  ├─ Check: Server running on laptop?
│  ├─ Check: Devices can reach laptop IP?
│  ├─ Check: Port 8080 open?
│  └─ Check: C++ client built correctly?
│
└─ P2P Mesh
   ├─ Check: Mesh listeners running?
   ├─ Check: Device map exists (~/.mesh_device_map)?
   ├─ Check: Peers configured (/data/local/tmp/mesh/peers.txt)?
   └─ Check: Device on mesh network?
```

## Feature Matrix

| Feature | Hub-Spoke | P2P Mesh |
|---------|-----------|----------|
| Image Classification | ✅ | ⚠️ (needs adaptation) |
| SLM Inference | ⚠️ (limited) | ✅ |
| NPU Support | ✅ | ✅ |
| CPU Fallback | ✅ | ✅ |
| Persistent Config | ❌ | ✅ |
| Multiple Orchestrators | ❌ | ✅ |
| No Build Required | ❌ | ✅ |
| Sub-100ms Latency | ✅ | ❌ |
| Concurrent Tasks | ✅ | ❌ (WIP) |
| Load Balancing | ✅ | ⚠️ (basic) |

Legend: ✅ Full Support | ⚠️ Partial/Limited | ❌ Not Supported | WIP Work In Progress

## Recommendation

**Use Hub-Spoke if:**
- You need image classification
- You have a dedicated laptop/server
- Low latency is critical
- You need many concurrent tasks

**Use P2P Mesh if:**
- You need SLM inference
- You want device independence
- You prefer simple deployment
- You want resilient architecture

**Use Both if:**
- Different tasks have different requirements
- You want to compare performance
- You're experimenting with architectures
