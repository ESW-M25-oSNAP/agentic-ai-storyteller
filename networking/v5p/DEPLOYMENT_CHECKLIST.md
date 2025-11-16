# ✅ Multi-LinUCB Deployment Checklist

Use this checklist when deploying Multi-LinUCB to new devices or setting up the system.

## Pre-Deployment

- [ ] All devices connected via ADB (`adb devices`)
- [ ] Termux installed on at least one device (for compilation)
- [ ] Device IPs configured in `device_*_config.json`

## Build Multi-LinUCB Binary

- [ ] Push source to device: `adb push device_scripts/multi_linucb_solver.c /sdcard/`
- [ ] Compile in Termux: `cd /sdcard && clang -O2 -lm -o multilin multi_linucb_solver.c`
- [ ] Pull binary back: `adb pull /sdcard/multilin device_scripts/`
- [ ] Verify binary: `ls -lh device_scripts/multilin`

## Deploy Token Predictor

### Device: Pineapple (60e0c72f)
- [ ] Predictor exists: `adb -s 60e0c72f shell "test -f /data/local/tmp/cppllama-bundle/llama.cpp/predictor && echo YES"`
- [ ] Libraries exist: `adb -s 60e0c72f shell "ls /data/local/tmp/cppllama-bundle/llama.cpp/build/bin"`
- [ ] Test predictor: `adb -s 60e0c72f shell "cd /data/local/tmp/cppllama-bundle/llama.cpp && export LD_LIBRARY_PATH=\$PWD/build/bin && ./predictor 'Hello'"`

### Device: Kalama (9688d142)
- [ ] Push predictor: `adb -s 9688d142 push predictor /data/local/tmp/cppllama-bundle/llama.cpp/`
- [ ] Push runtime: `adb -s 9688d142 push runtime/* /data/local/tmp/cppllama-bundle/llama.cpp/`
- [ ] Set permissions: `adb -s 9688d142 shell "chmod +x /data/local/tmp/cppllama-bundle/llama.cpp/predictor"`
- [ ] Test predictor: `adb -s 9688d142 shell "cd /data/local/tmp/cppllama-bundle/llama.cpp && export LD_LIBRARY_PATH=\$PWD/build/bin && ./predictor 'Hello'"`

### Device: DeviceC (ZD222LPWKD)
- [ ] Push predictor: `adb -s ZD222LPWKD push predictor /data/local/tmp/cppllama-bundle/llama.cpp/`
- [ ] Push runtime: `adb -s ZD222LPWKD push runtime/* /data/local/tmp/cppllama-bundle/llama.cpp/`
- [ ] Set permissions: `adb -s ZD222LPWKD shell "chmod +x /data/local/tmp/cppllama-bundle/llama.cpp/predictor"`
- [ ] Test predictor: `adb -s ZD222LPWKD shell "cd /data/local/tmp/cppllama-bundle/llama.cpp && export LD_LIBRARY_PATH=\$PWD/build/bin && ./predictor 'Hello'"`

## Deploy Multi-LinUCB

- [ ] Run deployment: `cd device_scripts && ./deploy_multilin.sh`
- [ ] Verify multilin on DeviceA: `adb -s 60e0c72f shell "ls -la /data/local/tmp/multilin"`
- [ ] Verify multilin on DeviceB: `adb -s 9688d142 shell "ls -la /data/local/tmp/multilin"`
- [ ] Verify multilin on DeviceC: `adb -s ZD222LPWKD shell "ls -la /data/local/tmp/multilin"`

## Test Multi-LinUCB

- [ ] Test score (DeviceA): `adb -s 60e0c72f shell "/data/local/tmp/multilin score 50 60 100 'Hello world'"`
- [ ] Test score (DeviceB): `adb -s 9688d142 shell "/data/local/tmp/multilin score 50 60 100 'Hello world'"`
- [ ] Test score (DeviceC): `adb -s ZD222LPWKD shell "/data/local/tmp/multilin score 50 60 100 'Hello world'"`
- [ ] Verify token prediction appears in output
- [ ] Check for "Predicted tokens: X" message

## Deploy Configuration

- [ ] Push configs: `./deploy_to_devices.sh`
- [ ] Verify DeviceA config: `adb -s 60e0c72f shell "cat /sdcard/mesh_network/device_config.json"`
- [ ] Verify DeviceB config: `adb -s 9688d142 shell "cat /sdcard/mesh_network/device_config.json"`
- [ ] Verify DeviceC config: `adb -s ZD222LPWKD shell "cat /sdcard/mesh_network/device_config.json"`

## Start Mesh Network

- [ ] Cleanup old processes: `./nuclear_cleanup.sh`
- [ ] Start mesh: `./start_mesh.sh`
- [ ] Verify listeners (DeviceA): `adb -s 60e0c72f shell "pgrep -f bid_listener"`
- [ ] Verify listeners (DeviceB): `adb -s 9688d142 shell "pgrep -f bid_listener"`
- [ ] Verify listeners (DeviceC): `adb -s ZD222LPWKD shell "pgrep -f bid_listener"`

## Test Orchestration

- [ ] Start monitoring: `./monitor_live.sh` (in separate terminal)
- [ ] Trigger orchestrator: `./trigger_orchestrator.sh DeviceA "What is a banana?"`
- [ ] Verify bid requests sent
- [ ] Verify bid responses received
- [ ] Verify winner selected
- [ ] Check for token prediction in logs

## Verify Logs

- [ ] Orchestrator log: `adb shell "cat /sdcard/mesh_network/orchestrator.log | tail -50"`
- [ ] Bid listener log: `adb shell "cat /sdcard/mesh_network/bid_listener.log | tail -50"`
- [ ] Look for: "Predicted tokens:" messages
- [ ] Look for: Multi-LinUCB scores
- [ ] Look for: Winner selection

## Common Issues

### Issue: "Predictor returned invalid value"
- [ ] Check predictor exists: `adb shell "ls -la /data/local/tmp/cppllama-bundle/llama.cpp/predictor"`
- [ ] Check libraries: `adb shell "ls -la /data/local/tmp/cppllama-bundle/llama.cpp/build/bin/libc++_shared.so"`
- [ ] Test manually: `adb shell "cd /data/local/tmp/cppllama-bundle/llama.cpp && export LD_LIBRARY_PATH=\$PWD/build/bin && ./predictor 'test'"`

### Issue: "Multi-LinUCB solver not found"
- [ ] Check binary: `adb shell "ls -la /data/local/tmp/multilin"`
- [ ] Re-deploy: `cd device_scripts && ./deploy_multilin.sh`

### Issue: "No bid responses"
- [ ] Check listeners running: `adb shell "pgrep -f bid_listener"`
- [ ] Check logs: `adb shell "cat /sdcard/mesh_network/bid_listener.log"`
- [ ] Restart mesh: `./nuclear_cleanup.sh && ./start_mesh.sh`

## Success Criteria

- [ ] All devices respond to bid requests
- [ ] Token predictor runs successfully
- [ ] Scores calculated correctly
- [ ] Winner selected based on lowest score
- [ ] Logs show "Predicted tokens: X" for each device
- [ ] No "WARNING" or "ERROR" messages in logs

## Final Verification

- [ ] Run end-to-end test with real prompt
- [ ] Verify orchestration completes successfully
- [ ] Check all logs are clean
- [ ] System ready for production use

---

**Checklist Complete?** ✅  
**System Ready for Use?** ✅  
**Date:** _________________

## Quick Commands Reference

```bash
# Deploy everything
cd device_scripts && ./deploy_multilin.sh

# Start mesh
cd .. && ./start_mesh.sh

# Monitor
./monitor_live.sh

# Test
./trigger_orchestrator.sh DeviceA "Test prompt"

# Check logs
adb shell "tail -50 /sdcard/mesh_network/orchestrator.log"
```
