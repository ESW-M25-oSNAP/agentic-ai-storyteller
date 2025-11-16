# Multi-LinUCB Quick Reference

## 🚀 Quick Start

### Build multilin (One-time, on Android device)
```bash
# Push source to device
adb push v4p/device_scripts/multi_linucb_solver.c /sdcard/

# In Termux on device
cd /sdcard
clang -O2 -lm -o multilin multi_linucb_solver.c
chmod +x multilin

# Pull back to laptop
adb pull /sdcard/multilin v4p/device_scripts/
```

### Deploy to All Devices
```bash
cd v4p/device_scripts
chmod +x deploy_multilin.sh
./deploy_multilin.sh
```

### Run Orchestration
```bash
cd v4p
./trigger_orchestrator.sh DeviceA "What is the capital of France?"
```

## 📝 Command Reference

### multilin CLI
```bash
# Score with prompt (uses predictor if available)
multilin score <cpu> <ram> <prompt_len> "<prompt>"

# Score with manual tokens
multilin score <cpu> <ram> <prompt_len> <tokens>

# Train model
multilin train <cpu> <ram> <prompt_len> <ttft> <speed>
```

### Examples
```bash
# With prompt
multilin score 50 60 100 "Hello world"

# With manual tokens
multilin score 50 60 100 75

# Training
multilin train 50 60 100 2.5 8.3
```

## 🔍 Testing Commands

```bash
# Test multilin on device
adb shell "/data/local/tmp/multilin score 50 60 100 75"

# Test predictor (if deployed)
adb shell "cd /data/local/tmp/cppllama-bundle/llama.cpp && export LD_LIBRARY_PATH=\$PWD/build/bin && ./predictor 'test'"

# View logs
adb shell cat /sdcard/mesh_network/orchestrator.log
adb shell cat /sdcard/mesh_network/bid_listener.log
```

## ⚡ Key Differences from lini

| Feature | lini | multilin |
|---------|------|----------|
| Binary name | `/data/local/tmp/lini` | `/data/local/tmp/multilin` |
| Token count | Manual parameter | Auto-predicted from prompt |
| Training metric | Latency | TTFT + Speed |
| Fallback | N/A | Uses DEFAULT_TOKENS=75 |
| CLI modes | Implicit | Explicit (score/train) |

## 🐛 Common Issues

### "Predictor returned invalid value"
**Cause**: Missing `libc++_shared.so`  
**Impact**: Uses default 75 tokens (system still works)  
**Fix**: Deploy libc++_shared.so or continue with default

### "multilin: not found"
**Cause**: Binary not deployed  
**Fix**: Run `./deploy_multilin.sh`

### Score returns 9999.0
**Cause**: Matrix inversion failed  
**Fix**: Check warm start data in C code

## 📊 Expected Output

### Successful Execution
```
$ adb shell "/data/local/tmp/multilin score 50 60 100 'Hello world'"
25.817228
Warning: Predictor returned invalid value, using default 75 tokens
Predicted tokens: 75
```
- Score: 25.817228 ✅
- Warning: Predictor fell back to default ⚠️
- System functional: Yes ✅

## 📁 File Locations

### On Device
- multilin: `/data/local/tmp/multilin`
- Predictor: `/data/local/tmp/cppllama-bundle/llama.cpp/predictor`
- Libraries: `/data/local/tmp/cppllama-bundle/llama.cpp/build/bin/`
- Config: `/sdcard/mesh_network/device_config.json`
- Logs: `/sdcard/mesh_network/*.log`

### On Laptop
- Source: `v4p/device_scripts/multi_linucb_solver.c`
- Binary: `v4p/device_scripts/multilin`
- Deploy script: `v4p/device_scripts/deploy_multilin.sh`
- Trigger: `v4p/trigger_orchestrator.sh`

## 🎯 Device Serials

- DeviceA (Pineapple): `60e0c72f`
- DeviceB (Kalama): `9688d142`
- DeviceC: `ZD222LPWKD`

## 📚 Full Documentation

- **Integration Guide**: `v4p/MULTILIN_INTEGRATION_GUIDE.md`
- **Migration Summary**: `v4p/MULTILIN_MIGRATION_SUMMARY.md`
- **Quick Reference**: `v4p/MULTILIN_QUICK_REFERENCE.md` (this file)
