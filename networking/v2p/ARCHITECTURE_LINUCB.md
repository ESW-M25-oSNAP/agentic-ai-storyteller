# LinUCB Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     P2P Mesh Network                             │
│                                                                  │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │  Device A    │◄────►│  Device B    │◄────►│  Device C    │  │
│  │  (Android)   │      │  (Android)   │      │  (Android)   │  │
│  └──────────────┘      └──────────────┘      └──────────────┘  │
│         │                      │                      │          │
└─────────┼──────────────────────┼──────────────────────┼─────────┘
          │                      │                      │
          │                      │                      │
    ┌─────▼──────┐         ┌─────▼──────┐         ┌─────▼──────┐
    │ LinUCB     │         │ LinUCB     │         │ LinUCB     │
    │ Solver     │         │ Solver     │         │ Solver     │
    ├────────────┤         ├────────────┤         ├────────────┤
    │ A: [4×4]   │         │ A: [4×4]   │         │ A: [4×4]   │
    │ b: [4×1]   │         │ b: [4×1]   │         │ b: [4×1]   │
    │ α: 1.0     │         │ α: 1.0     │         │ α: 1.0     │
    └────────────┘         └────────────┘         └────────────┘
         │                      │                      │
         │                      │                      │
    Local Brain            Local Brain            Local Brain
    (Self-Aware)          (Self-Aware)          (Self-Aware)
```

## Data Flow: Checkpoint 1 (Complete)

### Initialization
```
Device Startup
     │
     ├─► Load config.json
     │   (device_name, has_npu, peers, etc.)
     │
     └─► Load LinUCB State
         ├─► /sdcard/mesh_network/linucb_A.dat
         └─► /sdcard/mesh_network/linucb_B.dat
                │
                ├─► If exists: Warm Start (experienced)
                └─► If missing: Identity Matrix (fresh)
```

### Feature Vector Construction
```
System Metrics                    Feature Vector
┌──────────────┐                 ┌──────────────┐
│ CPU: 50%     │───┐             │ x[0] = 1.0   │
│ RAM: 75%     │   ├───────────► │ x[1] = 0.50  │
│ Prompt: 120  │───┘             │ x[2] = 0.75  │
│              │                  │ x[3] = 0.12  │
└──────────────┘                 └──────────────┘
                                        │
                                        ▼
                                 LinUCB Solver
```

### Score Calculation (LCB)
```
                    LinUCB Solver
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
    Compute θ      Compute ŷ      Compute σ
   θ = A⁻¹·b     ŷ = θᵀ·x    σ = √(xᵀ·A⁻¹·x)
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                 Score = ŷ - α·σ
                         │
                         ▼
                  Optimistic Latency
                   (Lower is Better)
```

### Training Update
```
Feedback: Actual Latency = y
              │
              ▼
     ┌────────────────┐
     │  Update A      │
     │  A += x·xᵀ     │
     └────────────────┘
              │
              ▼
     ┌────────────────┐
     │  Update b      │
     │  b += x·y      │
     └────────────────┘
              │
              ▼
     ┌────────────────┐
     │  Save State    │
     │  A.dat, B.dat  │
     └────────────────┘
```

## Data Flow: Checkpoints 2 & 3 (Planned)

### Checkpoint 2: Self-Aware Bidding
```
Orchestrator                                Worker (Device)
    │                                            │
    │  BID_REQUEST                               │
    │  {prompt_length: 120}                      │
    ├───────────────────────────────────────────►│
    │                                            │
    │                                       ┌────▼────┐
    │                                       │ Collect │
    │                                       │ Metrics │
    │                                       └────┬────┘
    │                                            │
    │                                       ┌────▼────┐
    │                                       │ LinUCB  │
    │                                       │ Score   │
    │                                       └────┬────┘
    │                                            │
    │                                       ┌────▼────┐
    │                                       │Generate │
    │                                       │ BidID   │
    │                                       └────┬────┘
    │                                            │
    │  BID_RESPONSE                         ┌────▼────┐
    │  {BidID: 12345, Score: 4.82}          │  Store  │
    │◄───────────────────────────────────────┤Pending  │
    │                                       │  Bids   │
    │                                       └─────────┘
    ▼
Select Lowest Score
```

### Checkpoint 3: Feedback Loop
```
Orchestrator                                Worker (Selected)
    │                                            │
    │  TASK_EXECUTE                              │
    │  {BidID: 12345, prompt: "..."}             │
    ├───────────────────────────────────────────►│
    │                                            │
    │                                       ┌────▼────┐
    │                                       │ Execute │
    │                                       │   SLM   │
    │                                       └────┬────┘
    │                                            │
    │  RESULT + Timing                      ┌────▼────┐
    │  {result: "...", latency: 6.8}        │ Measure │
    │◄───────────────────────────────────────┤ Latency │
    │                                       └─────────┘
    │
    │  FEEDBACK_PACKET
    │  {BidID: 12345, ActualLatency: 6.8}
    ├───────────────────────────────────────────►│
    │                                            │
    │                                       ┌────▼────┐
    │                                       │ Lookup  │
    │                                       │Features │
    │                                       └────┬────┘
    │                                            │
    │                                       ┌────▼────┐
    │                                       │ LinUCB  │
    │                                       │  Train  │
    │                                       └────┬────┘
    │                                            │
    │                                       ┌────▼────┐
    │                                       │  Save   │
    │                                       │  State  │
    │                                       └─────────┘
```

## Matrix State Evolution

### Initial State (Identity + Zeros)
```
A = │ 1  0  0  0 │        b = │ 0 │
    │ 0  1  0  0 │            │ 0 │
    │ 0  0  1  0 │            │ 0 │
    │ 0  0  0  1 │            │ 0 │

→ High Uncertainty
→ Very Optimistic Scores (negative)
```

### After 5 Training Examples
```
A = │ 6.00  2.50  3.30  0.75 │    b = │ 44.00 │
    │ 2.50  2.51  1.90  0.45 │        │ 26.81 │
    │ 3.30  1.90  3.44  0.56 │        │ 33.27 │
    │ 0.75  0.45  0.56  1.14 │        │  8.20 │

→ Lower Uncertainty
→ Realistic Scores (4-9 range)
```

### After 2915 Training Examples (Dataset)
```
A = │ 2913  1424  1426  553 │    b = │ 225 │
    │ 1424   948   696  273 │        │  88 │
    │ 1426   696   953  271 │        │ 110 │
    │  553   273   271  142 │        │  60 │

→ Very Low Uncertainty
→ Accurate Predictions (0-15 range)
```

## Protocol Changes

### Old Protocol (Checkpoints 0-4 from working.txt)
```
BID_REQUEST
     ↓
BID_RESPONSE: {has_npu, cpu_load, ram_load, npu_free}
     ↓
Orchestrator decides using:
  - If has_NPU and npu_free: Choose NPU
  - Else: 0.174*cpu + 0.002*ram
     ↓
Execute (no feedback)
```

### New Protocol (Checkpoints 1-3 from refactor.txt)
```
BID_REQUEST: {prompt_length}
     ↓
BID_RESPONSE: {BidID, Score}
     ↓
Orchestrator decides using:
  - Select min(Score)
     ↓
TASK_EXECUTE: {BidID, prompt}
     ↓
FEEDBACK_PACKET: {BidID, ActualLatency}
     ↓
Worker trains LinUCB model
```

## Port Allocation

```
Port 5000: Mesh Network (peer-to-peer communication)
Port 5001: Bid Listener (receives BID_REQUEST)
Port 5002: Bid Response (sends BID_RESPONSE)
Port 5003: Feedback Listener (receives FEEDBACK_PACKET) [NEW]
```

## File Structure on Android Devices

```
/sdcard/mesh_network/
├── device_config.json          # Device configuration
├── linucb_solver               # Binary (25KB)
├── linucb_A.dat                # A matrix state (4×4)
├── linucb_B.dat                # b vector state (4×1)
├── pending_bids.txt            # BidID → Features mapping
├── bid_listener.log            # Bid listener logs
├── orchestrator.log            # Orchestrator logs
└── feedback_listener.log       # Feedback listener logs [NEW]
```

## Comparison Table

| Aspect | Old (Static) | New (LinUCB) |
|--------|-------------|--------------|
| **Decision Maker** | Orchestrator | Each Worker |
| **Decision Logic** | Hardcoded formula | Learned model |
| **Metrics Sent** | Raw CPU/RAM/NPU | Score (prediction) |
| **Learning** | None | Continuous |
| **Adaptation** | Manual tuning | Automatic |
| **NPU Priority** | Hardcoded | Part of learned model |
| **State** | Stateless | Stateful (A, b) |
| **Warm Start** | N/A | Supported |
| **Feedback** | None | Per execution |

## Key Advantages

1. **Decentralized**: Each device makes its own predictions
2. **Self-Aware**: Devices know their own performance
3. **Adaptive**: Learns from actual execution
4. **Heterogeneous**: Different devices learn different models
5. **Warm-Start**: Pre-training accelerates initial performance
6. **Exploration**: Balances trying new devices vs. exploiting known good ones

---

**Checkpoint 1 Status**: ✅ COMPLETE  
**Next**: Checkpoint 2 - Self-Aware Bidding
