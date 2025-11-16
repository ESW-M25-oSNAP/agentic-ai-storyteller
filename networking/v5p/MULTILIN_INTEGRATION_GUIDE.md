# Multi-LinUCB Integration Guide

## Overview
This guide covers the transition from `lini` (LinUCB) to `multilin` (Multi-LinUCB) with integrated token prediction support.

## Key Changes

### 1. Binary Name Change
- **Old**: `lini` (LinUCB solver)
- **New**: `multilin` (Multi-LinUCB solver with token predictor integration)

### 2. Predictor Integration
The new `multilin` binary automatically calls an external predictor to estimate the number of output tokens based on the prompt, enabling more accurate latency predictions.

**Predictor Location**: `/data/local/tmp/cppllama-bundle/llama.cpp/predictor`

### 3. Updated Formula
- **Old**: `Latency = TTFT + (Tokens / TPS)` (manual token count)
- **New**: `Latency = TTFT + (PredictedTokens / TPS)` (auto-predicted tokens)

Where:
- `TTFT` = Time to First Token
- `TPS` = Tokens Per Second
- `PredictedTokens` = Output from predictor executable

---

## Deployment Steps

### Step 1: Build multilin Binary

On an Android device with Termux:

```bash
# On laptop
adb push v4p/device_scripts/multi_linucb_solver.c /sdcard/

# On device (in Termux)
cd /sdcard
clang -O2 -lm -o multilin multi_linucb_solver.c
chmod +x multilin

# Pull back to laptop
adb pull /sdcard/multilin v4p/device_scripts/
```

### Step 2: Deploy Predictor

For each device, ensure the predictor is deployed:

```bash
# Push predictor executable
adb -s <DEVICE_SERIAL> push predictor /data/local/tmp/cppllama-bundle/llama.cpp/

# Push runtime libraries
adb -s <DEVICE_SERIAL> push runtime/* /data/local/tmp/

# Set permissions
adb -s <DEVICE_SERIAL> shell chmod +x /data/local/tmp/cppllama-bundle/llama.cpp/predictor
```

**Note**: The predictor is already on Pineapple (60e0c72f). For Kalama and other devices, use the steps above.

### Step 3: Deploy multilin to All Devices

```bash
cd v4p/device_scripts
chmod +x deploy_multilin.sh
./deploy_multilin.sh
```

This will:
1. Push `multilin` binary to `/data/local/tmp/`
2. Verify predictor existence
3. Test multilin execution

### Step 4: Verify Deployment

```bash
# Test multilin with predictor
adb shell "/data/local/tmp/multilin score 50 60 100 'Hello world'"

# Should output a latency score
```

---

## Usage Changes

### Old CLI (lini)
```bash
# Scoring
lini score <state_a> <state_b> <cpu_norm> <ram_norm> <prompt_norm>

# Training
lini train <state_a> <state_b> <cpu_norm> <ram_norm> <prompt_norm> <actual_latency>
```

### New CLI (multilin)
```bash
# Scoring with prompt (uses predictor)
multilin score <cpu_norm> <ram_norm> <prompt_norm> "<prompt>"

# Scoring with manual tokens
multilin score <cpu_norm> <ram_norm> <prompt_norm> <predicted_tokens>

# Training (now uses TTFT and Speed instead of latency)
multilin train <cpu_norm> <ram_norm> <prompt_norm> <actual_ttft> <actual_speed>
```

**Examples**:
```bash
# Auto token prediction
multilin score 0.45 0.60 0.150 "What is the capital of France?"

# Manual token count
multilin score 0.45 0.60 0.150 75

# Training
multilin train 0.45 0.60 0.150 2.5 8.3
```

---

## File Changes Summary

### Modified Files

#### C Code
- **`v4p/device_scripts/multi_linucb_solver.c`**
  - Added `predict_tokens()` function to call external predictor
  - Updated CLI to accept prompts or manual token counts
  - Changed training to use TTFT and Speed instead of latency

#### Shell Scripts
- **`v4p/device_scripts/orchestrator.sh`**
  - Updated `LINUCB_BIN` → `MULTILIN_BIN`
  - Now passes full prompt to bid requests
  - Training uses TTFT and Speed

- **`v4p/device_scripts/bid_listener.sh`**
  - Updated to use `multilin`
  - Extracts prompt from bid requests
  - Passes prompt to multilin for token prediction

- **`v4p/device_scripts/feedback_listener.sh`**
  - Updated to use `multilin`
  - Expects TTFT and Speed in feedback (backward compatible with latency)

- **`v4p/trigger_orchestrator.sh`**
  - Updated messaging to reflect Multi-LinUCB

### New Files

- **`v4p/device_scripts/deploy_multilin.sh`**
  - Deployment script for multilin and predictor
  - Verifies predictor dependencies
  - Tests deployment

- **`v4p/device_scripts/Makefile`**
  - Build instructions for multilin

- **`v4p/MULTILIN_INTEGRATION_GUIDE.md`** (this file)

---

## Runtime Requirements

### Per Device
1. **multilin binary**: `/data/local/tmp/multilin`
2. **Predictor**: `/data/local/tmp/cppllama-bundle/llama.cpp/predictor`
3. **Runtime libraries**: `/data/local/tmp/cppllama-bundle/llama.cpp/build/bin/*`

### Environment Variables (for predictor)
```bash
export LD_LIBRARY_PATH=/data/local/tmp/cppllama-bundle/llama.cpp/build/bin
```

**Note**: multilin handles this automatically in the `predict_tokens()` function.

---

## Testing

### 1. Test Predictor Standalone
```bash
adb shell
cd /data/local/tmp/cppllama-bundle/llama.cpp
export LD_LIBRARY_PATH=$PWD/build/bin
./predictor "What is the capital of France?"
# Should output a number (e.g., 15)
```

### 2. Test multilin with Predictor
```bash
adb shell "/data/local/tmp/multilin score 0.5 0.6 0.1 'Hello world'"
# Should output a score (e.g., 5.234567)
```

### 3. Full Orchestration Test
```bash
cd v4p
./trigger_orchestrator.sh DeviceA "What is the capital of France?"
```

Check logs:
```bash
adb -s 60e0c72f shell cat /sdcard/mesh_network/orchestrator.log
```

---

## Troubleshooting

### Predictor Not Found
```
Warning: Failed to run predictor, using default 75 tokens
```
**Solution**: Ensure predictor is deployed:
```bash
adb shell ls -la /data/local/tmp/cppllama-bundle/llama.cpp/predictor
```

### Predictor Returns Invalid Value
```
Warning: Predictor returned invalid value, using default 75 tokens
```
**Solution**: The predictor is missing `libc++_shared.so`. Two options:

**Option 1: Deploy libc++_shared.so**
```bash
# Find libc++_shared.so on your system or from NDK
adb push libc++_shared.so /data/local/tmp/cppllama-bundle/llama.cpp/build/bin/
```

**Option 2: Use a statically linked predictor** (recommended)
Rebuild the predictor with static linking or ensure all dependencies are bundled in runtime.zip.

**Temporary Workaround**: multilin will use DEFAULT_TOKENS=75 and continue functioning. For better accuracy, either:
1. Fix the predictor dependencies
2. Manually specify token counts in scripts
3. Use a different token prediction method

### Library Not Found
```
error: only position independent executables (PIE) are supported
```
**Solution**: Ensure runtime libraries are deployed:
```bash
adb shell ls -la /data/local/tmp/cppllama-bundle/llama.cpp/build/bin/
```

### Multilin Score Returns 9999.0
This indicates matrix inversion failed (singular matrix). This can happen if:
1. No training data yet
2. Warm start data not loaded
3. Numerical instability

**Solution**: Ensure warm start data is present in `multi_linucb_solver.c`

---

## Migration Checklist

- [ ] Build multilin binary in Termux
- [ ] Deploy predictor to all devices
- [ ] Deploy runtime libraries to all devices
- [ ] Run `deploy_multilin.sh`
- [ ] Test predictor on each device
- [ ] Test multilin scoring with prompts
- [ ] Run full orchestration test
- [ ] Verify logs show token predictions
- [ ] Update any custom scripts that used `lini`

---

## Performance Notes

### Token Prediction Overhead
- **Predictor execution time**: ~50-200ms per call
- **Impact on bid time**: Minimal (runs in parallel across devices)
- **Accuracy improvement**: Significant (real prediction vs. fixed estimate)

### Fallback Behavior
If predictor fails, multilin uses `DEFAULT_TOKENS = 75` and continues execution.

---

## Future Improvements

1. **Cache predictions**: Store prompt→token mappings to avoid re-prediction
2. **Fine-tune predictor**: Use device-specific models for better accuracy
3. **Asynchronous prediction**: Pre-predict for common prompts
4. **Confidence intervals**: Return prediction uncertainty for better UCB

---

## Questions?

Check logs for detailed execution traces:
- Orchestrator: `/sdcard/mesh_network/orchestrator.log`
- Bid Listener: `/sdcard/mesh_network/bid_listener.log`
- Feedback Listener: `/sdcard/mesh_network/feedback_listener.log`

For issues, verify:
1. Predictor is executable and returns valid numbers
2. Runtime libraries are present
3. multilin can be executed and returns scores
4. Prompts are properly quoted in shell commands
