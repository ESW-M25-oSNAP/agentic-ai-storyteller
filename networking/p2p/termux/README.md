# Termux Mesh Network Scripts

This directory contains the scripts that run **on Android devices** in the Termux environment to create a peer-to-peer mesh network.

## Scripts Overview

### 🔧 mesh_listener.sh
**Primary listener daemon - runs continuously on each device**

**Purpose:** 
- Listen for incoming network messages on port 9999
- Route messages based on type
- Trigger SLM execution on prompt receipt
- Log all activity

**Usage:**
```bash
./mesh_listener.sh <DEVICE_ID> [PORT]

# Examples:
./mesh_listener.sh Device_A 9999
./mesh_listener.sh Device_B
```

**Message Types Handled:**
- `HELLO` - Device announcement
- `TEXT` - Text messages
- `SLM_PROMPT` - Triggers SLM execution
- `SLM_RESULT` - SLM results
- `DISCOVER` - Discovery requests

**Features:**
- Color-coded logging
- Automatic peer management
- Background SLM execution
- Periodic status broadcasts
- Error handling

---

### 🔧 mesh_sender.sh
**Command-line tool for sending messages**

**Purpose:**
- Send messages to other devices
- Manage peer list
- Support multiple message types

**Usage:**
```bash
./mesh_sender.sh <command> <args>

Commands:
  text <peer_id|all> <message>    Send text message
  slm <peer_id> <prompt>          Send SLM prompt
  discover <ip> [port]            Discover peer
  list                             List known peers
  add <id> <ip> [port]            Add peer manually
```

**Examples:**
```bash
# Send text to specific device
./mesh_sender.sh text Device_B "Hello from A!"

# Broadcast to all
./mesh_sender.sh text all "Broadcast message"

# Send SLM prompt
./mesh_sender.sh slm Device_B "Classify this image: cat"

# Discover new peer
./mesh_sender.sh discover 192.168.1.105 9999

# List known peers
./mesh_sender.sh list

# Add peer manually
./mesh_sender.sh add Device_C 192.168.1.105 9999
```

**Features:**
- Multiple message types
- Broadcast support
- Peer management
- User-friendly output
- Error handling

---

### 🔧 run_slm.sh
**Wrapper for Genie Bundle SLM execution**

**Purpose:**
- Interface between mesh network and Genie Bundle
- Execute SLM inference
- Capture and return results

**Usage:**
```bash
./run_slm.sh <prompt_file>

# Example:
echo "Describe a sunset" > prompt.txt
./run_slm.sh prompt.txt
```

**What It Does:**
1. Locates Genie Bundle installation
2. Reads prompt from file
3. Executes SLM inference
4. Captures output
5. Returns formatted result

**Features:**
- Auto-detection of Genie Bundle location
- Timeout protection (5 minutes)
- Error handling
- Output logging
- Execution time tracking

**Configuration:**
Edit the script to match your Genie Bundle installation:
```bash
GENIE_DIR="/data/local/tmp/genie-bundle"
```

And the execution command in `run_genie_slm()` function.

---

## Installation

These scripts are automatically deployed by `setup_mesh_network.sh`, but for manual installation:

```bash
# 1. Copy scripts to device
adb push mesh_listener.sh /sdcard/
adb push mesh_sender.sh /sdcard/
adb push run_slm.sh /sdcard/

# 2. Move to Termux and set permissions
adb shell
run-as com.termux
mkdir -p ~/mesh
cp /sdcard/mesh_*.sh ~/mesh/
cp /sdcard/run_slm.sh ~/mesh/
chmod +x ~/mesh/*.sh

# 3. Create required directories
mkdir -p ~/mesh/outputs
mkdir -p ~/mesh/logs
```

## File Structure Created

When running, these scripts create:

```
~/mesh/
├── mesh_listener.sh          # This script
├── mesh_sender.sh            # This script
├── run_slm.sh                # This script
├── peers.txt                 # List of known peers
├── my_info.txt               # This device's info
├── mesh_*.log                # Activity logs
├── outputs/
│   ├── prompt_*.txt          # Received prompts
│   └── slm_output_*.txt      # SLM results
└── logs/
    └── slm_execution.log     # SLM execution log
```

## Requirements

**Termux Packages:**
```bash
pkg install netcat-openbsd
```

**Optional (for auto-start):**
```bash
pkg install termux-services
```

## Quick Start

### On First Device (Device A)

```bash
# In Termux
cd ~/mesh
./mesh_listener.sh Device_A 9999
```

### On Second Device (Device B)

```bash
# In another terminal/device
cd ~/mesh
./mesh_listener.sh Device_B 9999
```

### Send Test Message

```bash
# On Device A
cd ~/mesh
./mesh_sender.sh text Device_B "Hello from A!"
```

## Monitoring

### View Logs
```bash
# Real-time log viewing
tail -f ~/mesh/mesh_*.log

# View SLM logs
tail -f ~/mesh/logs/slm_execution.log
```

### List Output Files
```bash
ls -lh ~/mesh/outputs/
```

### View Specific Output
```bash
cat ~/mesh/outputs/slm_output_<timestamp>.txt
```

## Configuration

### Change Listen Port

Edit `mesh_listener.sh`:
```bash
LISTEN_PORT="${2:-9999}"  # Change default port
```

### Genie Bundle Location

Edit `run_slm.sh`:
```bash
GENIE_DIR="/data/local/tmp/genie-bundle"  # Your Genie Bundle path
```

### Genie Bundle Execution

Edit the `run_genie_slm()` function in `run_slm.sh` to match your Genie Bundle interface:

```bash
# Example: Shell script
timeout 300 "$GENIE_SCRIPT" "$prompt" > "$output_file" 2>&1

# Example: Python
timeout 300 python "$GENIE_DIR/run_inference.py" --prompt "$prompt" > "$output_file" 2>&1

# Example: Binary
timeout 300 "$GENIE_DIR/genie" --input "$prompt" > "$output_file" 2>&1
```

## Troubleshooting

### Listener won't start
```bash
# Check if netcat is installed
which nc

# Install if missing
pkg install netcat-openbsd

# Check if port is available
nc -zv localhost 9999
```

### Can't send messages
```bash
# Check peers file
cat ~/mesh/peers.txt

# Test connectivity to peer
nc -zv <PEER_IP> 9999

# Check if listener is running
ps aux | grep mesh_listener
```

### SLM execution fails
```bash
# Check Genie Bundle exists
ls -la /data/local/tmp/genie-bundle/

# Test Genie Bundle manually
cd /data/local/tmp/genie-bundle
./run_model.sh "test prompt"

# Check logs
cat ~/mesh/logs/slm_execution.log
```

### Permission errors
```bash
# Make scripts executable
chmod +x ~/mesh/*.sh

# Check directory permissions
ls -la ~/mesh/
```

## Advanced Usage

### Auto-start on Boot

Using termux-services:

```bash
# Install termux-services
pkg install termux-services

# Create service
mkdir -p ~/.termux/sv/mesh-listener
cat > ~/.termux/sv/mesh-listener/run << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec ~/mesh/mesh_listener.sh Device_A 9999 2>&1
EOF

chmod +x ~/.termux/sv/mesh-listener/run

# Enable service
sv-enable mesh-listener
```

### Custom Message Types

Add new handlers in `mesh_listener.sh`:

```bash
handle_message() {
    case "$msg_type" in
        "TEXT") ... ;;
        "SLM_PROMPT") ... ;;
        "YOUR_TYPE")
            # Your custom handler
            ;;
    esac
}
```

### Peer Discovery

Broadcast discovery to subnet:

```bash
# Find all devices on network
for i in {1..254}; do
    ./mesh_sender.sh discover 192.168.1.$i 9999 &
done
wait
```

## Integration Examples

### With Orchestrator

Bridge mesh network to orchestrator:

```bash
# Receive from orchestrator, forward to mesh
cat orchestrator_output.txt | while read line; do
    ./mesh_sender.sh text all "$line"
done
```

### With Native App

Share data with native Android app:

```bash
# Save mesh output to app-accessible location
cat ~/mesh/outputs/slm_output_*.txt > /sdcard/app_data/result.txt
```

## Performance Tips

1. **Reduce broadcast frequency** - Edit status_broadcast interval in mesh_listener.sh
2. **Limit log file size** - Add log rotation
3. **Use discovery sparingly** - Manual peer addition is faster
4. **Optimize SLM timeout** - Adjust based on your model's speed

## Security Notes

⚠️ **These scripts are for development/testing**

For production:
- Add message encryption
- Implement authentication
- Validate all inputs
- Use TLS/SSL
- Isolate network

## Contributing

To improve these scripts:
1. Test thoroughly
2. Document changes
3. Maintain compatibility
4. Keep it simple

## Support

For issues:
1. Check logs: `~/mesh/mesh_*.log`
2. Verify Termux packages installed
3. Test network connectivity
4. Review configuration

## Version

- **Version:** 1.0
- **Last Updated:** November 7, 2025
- **Compatible With:** Termux (latest), Android 8+

---

**Parent Documentation:** See `../TERMUX_MESH_NETWORK_GUIDE.md` for complete system documentation.
