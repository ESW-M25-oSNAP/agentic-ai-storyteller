# Manual Testing Instructions - Checkpoint 2
## Retrieving and Displaying Device Parameters

---

## 📋 Overview

This document provides step-by-step instructions for manually testing the device metrics collection and display system for Checkpoint 2. The system now retrieves and displays:

- ✅ CPU Load (%)
- ✅ Battery Level (%)
- ✅ RAM Usage (MB - used/total)
- ✅ Storage Info (GB - free/total)
- ✅ NPU Presence (Yes/No)
- ✅ Model Availability (Image/Text models)

---

## 🔧 Prerequisites

### Hardware:
- 2 Android devices (physically connected via USB or wireless ADB)
- Laptop/Computer on same network as devices

### Software:
- Android NDK installed
- ADB (Android Debug Bridge) working
- Python 3.x with required packages
- Build completed successfully

### Verification:
```bash
# Check ADB
adb devices

# Check Python
python3 --version

# Check build
ls -la /home/avani/ESW/agentic-ai-storyteller/networking/build/agent
```

---

## 📝 Step-by-Step Testing Procedure

### STEP 1: Identify Your Devices

```bash
# List all connected devices with details
adb devices -l

# Expected output:
# List of devices attached
# R5CR30XXXXX    device product:xxx model:xxx device:xxx
# R5CR40YYYYY    device product:yyy model:yyy device:yyy
```

**Record the serial numbers:**
- Device A Serial: `________________`
- Device B Serial: `________________`

---

### STEP 2: Get Your Laptop's Network IP

```bash
# Option 1
hostname -I | awk '{print $1}'

# Option 2
ip addr show | grep "inet " | grep -v "127.0.0.1"

# Option 3
ifconfig | grep "inet " | grep -v "127.0.0.1"
```

**Your Laptop IP: `________________`** (e.g., 192.168.1.100)

---

### STEP 3: Start the Orchestrator

Open a new terminal window (keep it visible):

```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking
python3 src/orchestrator.py
```

**Expected Output:**
```
=== Orchestrator Starting ===
Listening on 0.0.0.0:8080
Orchestrator is running. Press Ctrl+C to stop.
```

⏸️ **CHECKPOINT**: Is the orchestrator running? Yes ☐ No ☐

---

### STEP 4: Deploy Agent to Device A

Open a new terminal window:

```bash
# Replace <DEVICE_A_SERIAL> with actual serial from Step 1
export DEV_A=<DEVICE_A_SERIAL>

# Push agent to device
adb -s $DEV_A push /home/avani/ESW/agentic-ai-storyteller/networking/build/agent /data/local/tmp/

# Make it executable
adb -s $DEV_A shell chmod +x /data/local/tmp/agent

# Verify it's there
adb -s $DEV_A shell ls -la /data/local/tmp/agent
```

**Expected Output:**
```
/home/avani/ESW/.../agent: 1 file pushed
-rwxr-xr-x 1 shell shell 123456 2025-10-23 12:34 /data/local/tmp/agent
```

⏸️ **CHECKPOINT**: Agent pushed successfully? Yes ☐ No ☐

---

### STEP 5: Deploy Agent to Device B

In the same or another terminal:

```bash
# Replace <DEVICE_B_SERIAL> with actual serial from Step 1
export DEV_B=<DEVICE_B_SERIAL>

# Push agent to device
adb -s $DEV_B push /home/avani/ESW/agentic-ai-storyteller/networking/build/agent /data/local/tmp/

# Make it executable
adb -s $DEV_B shell chmod +x /data/local/tmp/agent

# Verify it's there
adb -s $DEV_B shell ls -la /data/local/tmp/agent
```

⏸️ **CHECKPOINT**: Agent pushed to both devices? Yes ☐ No ☐

---

### STEP 6: Connect Device A to Orchestrator

Keep the orchestrator terminal visible. Open a new terminal:

```bash
# Replace with your values
export DEV_A=<DEVICE_A_SERIAL>
export LAPTOP_IP=<YOUR_LAPTOP_IP>

# Connect to device shell
adb -s $DEV_A shell

# You're now IN the device shell
# Run the agent (A means NPU=true)
cd /data/local/tmp
./agent A 192.168.1.100 8080  # Replace with your LAPTOP_IP
```

**In Device A Terminal, Expected Output:**
```
Connected to orchestrator
Registration successful
```

**In Orchestrator Terminal, Expected Output:**
```
================================================================================
✅ NEW DEVICE REGISTERED: A
================================================================================
┌──────────────────────────────────────────────────────────────────────────────┐
│ Device ID: A                                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ NPU Present:     ✓ YES                                                       │
│ Capabilities:    classify, segment, generate_story                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ CPU Load:        [████████░░░░░░░░░░░░░░░░░░░░░░]  XX.X%                    │
│ Battery:         [████████████████████████████░░]  XX.X% 🔋                  │
│ RAM Usage:       [████████████████░░░░░░░░░░░░░░] XXXX/XXXX MB (XX.X%)      │
│ Storage:         [████████████████████░░░░░░░░░░]  XX.X/XXX.X GB free       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### ⏸️ **VERIFICATION CHECKPOINT - Device A Metrics**

In the orchestrator terminal, verify you can see:

**Device A Metrics Checklist:**
- ☐ Device ID displayed as "A"
- ☐ NPU Present shows "✓ YES"
- ☐ Capabilities listed (classify, segment, generate_story)
- ☐ CPU Load shows percentage with progress bar
- ☐ Battery Level shows percentage with progress bar and 🔋 icon
- ☐ RAM Usage shows used/total in MB with percentage
- ☐ Storage shows free/total in GB
- ☐ Image Model shows "✓ Available"
- ☐ Text Model shows "✓ Available"

**Record the values you see:**
- CPU Load: `_______%`
- Battery: `_______%`
- RAM: `______ / ______ MB (___%)`
- Storage: `______ / ______ GB free`

---

### STEP 7: Connect Device B to Orchestrator

Open another new terminal:

```bash
# Replace with your values
export DEV_B=<DEVICE_B_SERIAL>
export LAPTOP_IP=<YOUR_LAPTOP_IP>

# Connect to device shell
adb -s $DEV_B shell

# You're now IN the device shell
# Run the agent (B means NPU=false)
cd /data/local/tmp
./agent B 192.168.1.100 8080  # Replace with your LAPTOP_IP
```

**In Orchestrator Terminal, Expected Output:**
```
================================================================================
✅ NEW DEVICE REGISTERED: B
================================================================================
┌──────────────────────────────────────────────────────────────────────────────┐
│ Device ID: B                                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ NPU Present:     ✗ NO                                                        │
│ Capabilities:    classify, generate_story                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ CPU Load:        [██████░░░░░░░░░░░░░░░░░░░░░░░░]  XX.X%                    │
│ Battery:         [████████████████████████████░░]  XX.X% 🔋                  │
│ RAM Usage:       [████████████░░░░░░░░░░░░░░░░░░] XXXX/XXXX MB (XX.X%)      │
│ Storage:         [████████████████░░░░░░░░░░░░░░]  XX.X/XXX.X GB free       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### ⏸️ **VERIFICATION CHECKPOINT - Device B Metrics**

**Device B Metrics Checklist:**
- ☐ Device ID displayed as "B"
- ☐ NPU Present shows "✗ NO"
- ☐ Capabilities listed (classify, generate_story) - Note: NO "segment"
- ☐ CPU Load shows percentage with progress bar
- ☐ Battery Level shows percentage with progress bar
- ☐ RAM Usage shows used/total in MB
- ☐ Storage shows free/total in GB
- ☐ Both models show "✓ Available"

**Record the values you see:**
- CPU Load: `_______%`
- Battery: `_______%`
- RAM: `______ / ______ MB (___%)`
- Storage: `______ / ______ GB free`

---

### STEP 8: Test Image Transfer and Bidding

Open a new terminal (keep others running):

```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking

# Make sure test.jpg exists
ls -la test.jpg

# If not, copy any image as test.jpg
# cp /path/to/some/image.jpg test.jpg

# Send image from "Device A"
python3 send_image_from_device.py A test.jpg
```

**Expected Output in Send Terminal:**
```
Reading image from: test.jpg
Image size: XXXXX bytes
Encoded size: YYYYY characters
Connecting to orchestrator at localhost:8080...
✓ Image sent from Device A!
  Message size: ZZZZZ bytes
```

---

### ⏸️ **VERIFICATION CHECKPOINT - Bidding Process**

**In Orchestrator Terminal, Expected Output:**

1. **Image Received:**
```
Image received from A
Starting bidding process for task XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
Sent bid request to A
Sent bid request to B
```

2. **Bids Received:**
```
📨 Bid from A: CPU=0.XX, Battery=XX%, ✓ NPU
📨 Bid from B: CPU=0.XX, Battery=XX%, ✗ No NPU
```

3. **Bid Evaluation:**
```
================================================================================
🎯 EVALUATING BIDS FOR TASK XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
================================================================================
  A: CPU=XX.XX%, Battery=XX%, RAM=XX.X%, NPU=✓
  B: CPU=XX.XX%, Battery=XX%, RAM=XX.X%, NPU=✗

🏆 WINNER: [A or B - whichever has LOWER CPU]
   CPU Load: XX.XX%
   Battery: XX%
================================================================================

Sent image to [WINNER] for processing
```

**Bidding Process Checklist:**
- ☐ Image received message shown
- ☐ Task ID generated (UUID format)
- ☐ Bid requests sent to both devices
- ☐ Bids received from both devices
- ☐ All metrics displayed in bid evaluation
- ☐ Winner selected (device with lowest CPU load)
- ☐ Image sent to winner

**Record:**
- Device A CPU in bid: `_______%`
- Device B CPU in bid: `_______%`
- Winner: `Device _____`

---

### STEP 9: Verify Image Received on Winner Device

```bash
# If Device A won:
adb -s $DEV_A shell ls -la /data/local/tmp/image_*.jpg

# If Device B won:
adb -s $DEV_B shell ls -la /data/local/tmp/image_*.jpg

# You can also pull the image back to verify:
# adb -s $DEV_A pull /data/local/tmp/image_*.jpg ./received_image.jpg
```

**Expected Output:**
```
-rw-r--r-- 1 shell shell XXXXX 2025-10-23 12:45 /data/local/tmp/image_1729699500.jpg
```

⏸️ **CHECKPOINT**: Image file exists on winner device? Yes ☐ No ☐

---

### STEP 10: Observe Status Updates

**Wait 30 seconds** and observe the orchestrator terminal.

**Expected Output:**
```
================================================================================
📡 CONNECTED DEVICES SUMMARY (2 devices)
================================================================================

[Device A full metrics display]

[Device B full metrics display]
```

**Status Update Checklist:**
- ☐ Summary appears every 30 seconds
- ☐ Shows count of connected devices
- ☐ Displays full metrics for each device
- ☐ Metrics may have changed slightly from initial values

---

## ✅ Final Verification - Checkpoint 2 Complete

### All Requirements Met:

**Connection & Registration:**
- ☐ Both devices successfully connected
- ☐ Both devices registered with orchestrator
- ☐ Registration messages displayed clearly

**Metrics Display:**
- ☐ CPU load displayed with progress bars
- ☐ Battery level displayed with progress bars and icons
- ☐ RAM usage displayed (used/total MB and percentage)
- ☐ Storage displayed (free/total GB)
- ☐ NPU presence indicated correctly (A=✓, B=✗)
- ☐ Model availability shown
- ☐ Capabilities list shown correctly

**Bidding Process:**
- ☐ Image sent successfully
- ☐ Bidding process initiated
- ☐ Both devices submitted bids
- ☐ Bids displayed with all metrics
- ☐ Winner selected based on lowest CPU load
- ☐ Winner announcement displayed clearly

**Image Transfer:**
- ☐ Image sent to winning device
- ☐ Image file exists on winning device at `/data/local/tmp/`
- ☐ Image filename follows pattern: `image_<timestamp>.jpg`

**Status Updates:**
- ☐ Status updates sent every 30 seconds
- ☐ Metrics refreshed in display
- ☐ Summary shows all connected devices

---

## 📊 Test Results Summary

**Date of Test:** _______________  
**Tester Name:** _______________

**Devices Used:**
- Device A: Model: ____________ Serial: ____________
- Device B: Model: ____________ Serial: ____________

**Laptop IP:** _______________

**Test Duration:** _______________

**Issues Encountered:**
```
[List any problems, errors, or unexpected behavior]




```

**Screenshots/Photos Attached:** Yes ☐ No ☐

**Overall Result:** PASS ☐ FAIL ☐

---

## 🔍 Troubleshooting Reference

### Device won't connect
- Check `adb devices` output
- Verify USB debugging enabled
- Check network connectivity
- Verify laptop IP is correct

### Metrics show as 0 or N/A
- Check device permissions
- Some paths may vary by device
- Check device logs: `adb logcat | grep DeviceClient`

### No bids received
- Check devices are still connected
- Verify image was sent successfully
- Check device logs for errors

### Build failed
- Verify ANDROID_NDK is set
- Check CMakeLists.txt paths
- Ensure NDK version compatible

---

**END OF MANUAL TESTING INSTRUCTIONS**

**Next Step:** After successful verification, proceed to Checkpoint 3 (Running Inception-V3 model)
