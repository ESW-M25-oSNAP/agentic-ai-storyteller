# Quick Start Guide - Testing with Real Android Devices

## 🚀 Quick Setup (5 Minutes)

### 1. Get Your Laptop IP
```bash
hostname -I | awk '{print $1}'
# Example output: 192.168.1.100
```

### 2. Start Orchestrator
```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking
python3 src/orchestrator.py
```

### 3. Deploy to Android Devices

**Terminal 1 - Device A:**
```bash
adb -s <DEVICE_A_SERIAL> push build/agent /data/local/tmp/
adb -s <DEVICE_A_SERIAL> shell chmod +x /data/local/tmp/agent
adb -s <DEVICE_A_SERIAL> shell
# Now in device shell:
cd /data/local/tmp
./agent A 192.168.1.100 8080  # Use your laptop IP
```

**Terminal 2 - Device B:**
```bash
adb -s <DEVICE_B_SERIAL> push build/agent /data/local/tmp/
adb -s <DEVICE_B_SERIAL> shell chmod +x /data/local/tmp/agent
adb -s <DEVICE_B_SERIAL> shell
# Now in device shell:
cd /data/local/tmp
./agent B 192.168.1.100 8080  # Use your laptop IP
```

### 4. Check Connection

You should see on orchestrator terminal:
- ✅ Device A registered with all metrics
- ✅ Device B registered with all metrics
- Beautiful formatted tables showing:
  - CPU Load (with progress bar)
  - Battery Level (with progress bar)
  - RAM Usage (used/total MB)
  - Storage (free/total GB)
  - NPU Presence
  - Model availability

### 5. Test Image Transfer

**Terminal 3 - Send Image:**
```bash
cd /home/avani/ESW/agentic-ai-storyteller/networking
python3 send_image_from_device.py A test.jpg
```

### 6. Observe Bidding

Watch the orchestrator terminal for:
1. 📨 Bids received from both devices
2. 🎯 Bid evaluation with all metrics
3. 🏆 Winner selection (lowest CPU load)
4. ✅ Image sent to winner

### 7. Verify Image Received

```bash
# Check on winning device (e.g., Device B)
adb -s <DEVICE_B_SERIAL> shell ls -la /data/local/tmp/image_*.jpg
```

## 📊 What Metrics You'll See

### Device Registration Display:
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Device ID: A                                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ NPU Present:     ✓ YES                                                       │
│ Capabilities:    classify, segment, generate_story                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ CPU Load:        [████████░░░░░░░░░░░░░░░░░░░░░░]  26.5%                    │
│ Battery:         [████████████████████████████░░]  93.0% 🔋                  │
│ RAM Usage:       [████████████████░░░░░░░░░░░░░░] 2845/6144 MB (46.3%)      │
│ Storage:         [████████████████████░░░░░░░░░░]  45.2/128.0 GB free       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Image Model:     ✓ Available                                                │
│ Text Model:      ✓ Available                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Bid Evaluation Display:
```
================================================================================
🎯 EVALUATING BIDS FOR TASK 12345678-1234-5678-1234-567812345678
================================================================================
  A: CPU=26.50%, Battery=93%, RAM=46.3%, NPU=✓
  B: CPU=18.20%, Battery=87%, RAM=46.9%, NPU=✗

🏆 WINNER: B
   CPU Load: 18.20%
   Battery: 87%
================================================================================
```

## 🔧 Troubleshooting

### Can't find device serial?
```bash
adb devices -l
```

### Connection refused?
```bash
# Check orchestrator is running
# Check firewall on laptop
sudo ufw allow 8080/tcp  # If using ufw

# Test from device
adb shell ping <LAPTOP_IP>
```

### Wrong IP address?
```bash
# Get all network interfaces
ip addr show

# Find the one connected to your WiFi/Ethernet
# Usually starts with 192.168.x.x or 10.x.x.x
```

### Build errors?
```bash
# Verify NDK path
echo $ANDROID_NDK

# Should be: /home/avani/ESW/agentic-ai-storyteller/android-ndk-r27d-linux

# If not set:
export ANDROID_NDK=/home/avani/ESW/agentic-ai-storyteller/android-ndk-r27d-linux

# Rebuild
cd /home/avani/ESW/agentic-ai-storyteller/networking
./build_agent.sh
```

## ✅ Success Checklist

- [ ] Both devices connected and registered
- [ ] CPU load displayed with progress bar
- [ ] Battery level displayed with progress bar  
- [ ] RAM usage shown (used/total MB)
- [ ] Storage info shown (free/total GB)
- [ ] NPU presence indicated (✓ or ✗)
- [ ] Image sent successfully
- [ ] Bidding process completed
- [ ] Winner selected (lowest CPU)
- [ ] Image received on winning device
- [ ] Status updates every 30 seconds

## 📝 Notes

- Device A (first argument "A"): Has NPU = true
- Device B (first argument "B"): Has NPU = false
- Status updates sent every 30 seconds
- Metrics displayed on registration and status updates
- Image saved with timestamp: `/data/local/tmp/image_<timestamp>.jpg`

---

**For detailed information, see TESTING_GUIDE.md**
