# Testing Guide for Checkpoint 2 with Real Android Devices

## Overview
This guide will help you test the complete bidding and image transfer system with two real Android devices, displaying comprehensive device metrics including CPU, RAM, storage, battery, and NPU presence.

## Prerequisites

### On Your Laptop
1. Python 3.x installed
2. Required Python packages: `pip3 install opencv-python numpy`
3. Android NDK installed
4. ADB (Android Debug Bridge) installed
5. Your laptop and Android devices on the same network

### On Android Devices
1. Developer options enabled
2. USB debugging enabled
3. Both devices connected via ADB (wireless or USB)

## Step 1: Find Your Laptop's IP Address

```bash
# On Linux/Mac
ip addr show | grep inet

# Or
hostname -I

# Example output: 192.168.1.100
```

**Note down your laptop's IP address** - you'll need it later.

## Step 2: Build the Android Client

```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking

# Set Android NDK path if not already set
export ANDROID_NDK=/home/avani/ESW/agentic-ai-storyteller/android-ndk-r27d-linux

# Build the agent
chmod +x build_agent.sh
./build_agent.sh
```

The binary will be at: `build/agent`

## Step 3: Deploy to Android Devices

### Check Connected Devices
```bash
adb devices
```

You should see both devices listed. If you have multiple devices, use:
```bash
adb devices -l
```

### Deploy to Device A (First Device)
```bash
# If only one device connected
adb push build/agent /data/local/tmp/
adb shell chmod +x /data/local/tmp/agent

# If multiple devices, use -s flag with device serial
adb -s <DEVICE_A_SERIAL> push build/agent /data/local/tmp/
adb -s <DEVICE_A_SERIAL> shell chmod +x /data/local/tmp/agent
```

### Deploy to Device B (Second Device)
```bash
adb -s <DEVICE_B_SERIAL> push build/agent /data/local/tmp/
adb -s <DEVICE_B_SERIAL> shell chmod +x /data/local/tmp/agent
```

## Step 4: Prepare Test Image on Device A

Transfer a test image to Device A:
```bash
# Put your test image on Device A
adb -s <DEVICE_A_SERIAL> push test.jpg /storage/emulated/0/Pictures/test.jpg

# Verify it's there
adb -s <DEVICE_A_SERIAL> shell ls -la /storage/emulated/0/Pictures/test.jpg
```

## Step 5: Start the Orchestrator

Open a terminal on your laptop:

```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking
python3 src/orchestrator.py
```

You should see:
```
=== Orchestrator Starting ===
Listening on 0.0.0.0:8080
Orchestrator is running. Press Ctrl+C to stop.
```

## Step 6: Connect Device A

Open a new terminal:

```bash
# Connect to Device A via ADB shell
adb -s <DEVICE_A_SERIAL> shell

# Once in the shell, run the agent
cd /data/local/tmp
./agent A <YOUR_LAPTOP_IP> 8080

# Example:
# ./agent A 192.168.1.100 8080
```

**What you should see on orchestrator terminal:**
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
│ CPU Load:        [████████░░░░░░░░░░░░░░░░░░░░░░]  26.5%               │
│ Battery:         [████████████████████████████░░]  93.0% 🔋             │
│ RAM Usage:       [████████████████░░░░░░░░░░░░░░] 2845/6144 MB (46.3%) │
│ Storage:         [████████████████████░░░░░░░░░░]  45.2/128.0 GB free       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Step 7: Connect Device B

Open another terminal:

```bash
# Connect to Device B via ADB shell
adb -s <DEVICE_B_SERIAL> shell

# Once in the shell, run the agent
cd /data/local/tmp
./agent B <YOUR_LAPTOP_IP> 8080
```

**What you should see on orchestrator terminal:**
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
│ CPU Load:        [██████░░░░░░░░░░░░░░░░░░░░░░░░]  18.2%               │
│ Battery:         [████████████████████████████░░]  87.0% 🔋             │
│ RAM Usage:       [████████████░░░░░░░░░░░░░░░░░░] 1920/4096 MB (46.9%) │
│ Storage:         [████████████████░░░░░░░░░░░░░░]  28.5/64.0 GB free        │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Step 8: Send Image from Device A

### Method 1: Using Python Script (Recommended)

Create a simple Python script to send image from Device A:

```bash
# On your laptop, create send_from_device_a.py
```

```python
import socket
import json
import base64
import subprocess

# Get image from Device A
device_a_serial = "<DEVICE_A_SERIAL>"  # Replace with actual serial
image_path = "/storage/emulated/0/Pictures/test.jpg"

# Pull image from device
subprocess.run(["adb", "-s", device_a_serial, "pull", image_path, "/tmp/temp_image.jpg"])

# Read and encode image
with open("/tmp/temp_image.jpg", "rb") as f:
    image_data = base64.b64encode(f.read()).decode('utf-8')

# Send image message to orchestrator AS IF it came from Device A
message = {
    "type": "image",
    "agent_id": "A",
    "task_id": "",
    "subtask": "",
    "data": {
        "image_base64": image_data
    }
}

# Connect to orchestrator and send
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(("localhost", 8080))
sock.send(json.dumps(message).encode())
sock.close()

print("Image sent from Device A!")
```

Run it:
```bash
python3 send_from_device_a.py
```

### Method 2: Direct from Android Device (Advanced)

You can modify the C++ client to have a command to send an image, but Method 1 is simpler for testing.

## Step 9: Observe the Bidding Process

**What you should see on orchestrator terminal:**

```
Image received from A
Starting bidding process for task 12345678-1234-5678-1234-567812345678
Sent bid request to A
Sent bid request to B

📨 Bid from A: CPU=0.26, Battery=93%, ✓ NPU
📨 Bid from B: CPU=0.18, Battery=87%, ✗ No NPU

================================================================================
🎯 EVALUATING BIDS FOR TASK 12345678-1234-5678-1234-567812345678
================================================================================
  A: CPU=26.50%, Battery=93%, RAM=46.3%, NPU=✓
  B: CPU=18.20%, Battery=87%, RAM=46.9%, NPU=✗

🏆 WINNER: B
   CPU Load: 18.20%
   Battery: 87%
================================================================================

Sent image to B for processing
```

**On Device B's ADB shell, you should see:**
```
Received task 12345678-1234-5678-1234-567812345678, subtask: classify
Saving image as: image_1729699200.jpg
Decoded image size: 245678 bytes
Attempting to save image to: /data/local/tmp/image_1729699200.jpg
Image saved successfully to /data/local/tmp/image_1729699200.jpg
```

## Step 10: Verify Image Received

On Device B's terminal (or another terminal):
```bash
adb -s <DEVICE_B_SERIAL> shell ls -la /data/local/tmp/image_*.jpg
```

You should see the received image file!

## Step 11: Check Status Updates

Every 30 seconds, the orchestrator will display updated metrics for all connected devices:

```
================================================================================
📡 CONNECTED DEVICES SUMMARY (2 devices)
================================================================================

┌──────────────────────────────────────────────────────────────────────────────┐
│ Device ID: A                                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ NPU Present:     ✓ YES                                                       │
│ Capabilities:    classify, segment, generate_story                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ CPU Load:        [████████░░░░░░░░░░░░░░░░░░░░░░]  28.1%               │
│ Battery:         [████████████████████████████░░]  93.0% 🔋             │
│ RAM Usage:       [████████████████░░░░░░░░░░░░░░] 2850/6144 MB (46.4%) │
│ Storage:         [████████████████████░░░░░░░░░░]  45.2/128.0 GB free       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘

[Device B metrics display...]
```

## Troubleshooting

### Issue: Devices can't connect to orchestrator
- Check firewall settings on laptop
- Verify laptop and devices are on same network
- Test connectivity: `adb shell ping <LAPTOP_IP>`

### Issue: "Connection refused"
- Ensure orchestrator is running
- Check the port (8080) is not being used by another application
- Verify IP address is correct

### Issue: Build fails
- Ensure ANDROID_NDK is set correctly
- Check CMakeLists.txt paths
- Verify NDK version compatibility

### Issue: Can't push agent to device
- Check ADB is working: `adb devices`
- Ensure USB debugging is enabled
- Try: `adb kill-server && adb start-server`

### Issue: Metrics showing as 0 or N/A
- Some paths like `/sys/class/power_supply/battery/capacity` may vary by device
- Check device logs: `adb logcat | grep DeviceClient`
- RAM and storage metrics should work on all Android devices

## Success Criteria for Checkpoint 2

✅ Both devices connect and register with orchestrator
✅ Orchestrator displays comprehensive metrics (CPU, RAM, storage, battery, NPU)
✅ Image sent from Device A to orchestrator
✅ Bidding process initiated
✅ Both devices respond with bids
✅ Device with lowest CPU load selected as winner
✅ Image transferred to winning device
✅ Image saved to `/data/local/tmp/` on winning device
✅ Metrics update every 30 seconds

## Next Steps

After verifying Checkpoint 2 is working:
- Checkpoint 3: Run Inception-V3 on the winning device
- Checkpoint 4: Return classification results to orchestrator
- Continue with the story generation pipeline

---

**Created for: Agentic AI Storyteller Project**
**Date: October 23, 2025**
