#!/bin/bash
# Mesh Network Setup and Deployment Script
# Deploys Termux-based P2P mesh network to Android devices

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMUX_SCRIPTS_DIR="$SCRIPT_DIR/termux"
TERMUX_APK_URL="https://f-droid.org/repo/com.termux_118.apk"
TERMUX_APK="termux_118.apk"

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║              Mesh Network Setup & Deployment Script                       ║"
echo "║              Termux-based P2P Network for Android Devices                 ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing=0
    
    # Check for adb
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}✗ ADB not found. Please install Android Debug Bridge.${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ ADB found${NC}"
    fi
    
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 not found.${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Python 3 found${NC}"
    fi
    
    # Check for required scripts
    if [ ! -d "$TERMUX_SCRIPTS_DIR" ]; then
        echo -e "${RED}✗ Termux scripts directory not found: $TERMUX_SCRIPTS_DIR${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Termux scripts directory found${NC}"
    fi
    
    if [ $missing -ne 0 ]; then
        echo -e "\n${RED}Please install missing prerequisites and try again.${NC}"
        exit 1
    fi
    
    echo ""
}

# Get connected devices
get_devices() {
    echo -e "${YELLOW}Scanning for connected devices...${NC}"
    
    local devices=$(adb devices | grep -w "device" | awk '{print $1}')
    
    if [ -z "$devices" ]; then
        echo -e "${RED}No devices found. Please connect Android devices via USB.${NC}"
        exit 1
    fi
    
    local count=$(echo "$devices" | wc -l)
    echo -e "${GREEN}Found $count device(s)${NC}\n"
    
    # Display devices
    local idx=0
    for device in $devices; do
        local letter=$(printf "\x$(printf %x $((65+idx)))")  # A, B, C, etc.
        echo -e "  ${CYAN}Device $letter:${NC} $device"
        DEVICE_ARRAY[$idx]="$device"
        DEVICE_NAMES[$idx]="Device_$letter"
        idx=$((idx+1))
    done
    
    echo ""
}

# Check if Termux is installed on device
check_termux() {
    local device=$1
    adb -s "$device" shell pm list packages 2>/dev/null | grep -q "com.termux"
}

# Install Termux on device
install_termux() {
    local device=$1
    local device_name=$2
    
    echo -e "${YELLOW}Installing Termux on $device_name...${NC}"
    
    # Check if already installed
    if check_termux "$device"; then
        echo -e "${GREEN}✓ Termux already installed${NC}"
        return 0
    fi
    
    # Download Termux APK if not present
    if [ ! -f "$TERMUX_APK" ]; then
        echo -e "${YELLOW}Downloading Termux APK...${NC}"
        if command -v wget &> /dev/null; then
            wget -O "$TERMUX_APK" "$TERMUX_APK_URL"
        elif command -v curl &> /dev/null; then
            curl -L -o "$TERMUX_APK" "$TERMUX_APK_URL"
        else
            echo -e "${RED}Please download Termux APK manually from F-Droid${NC}"
            echo -e "${YELLOW}URL: $TERMUX_APK_URL${NC}"
            return 1
        fi
    fi
    
    # Install APK
    echo -e "${YELLOW}Installing APK...${NC}"
    adb -s "$device" install "$TERMUX_APK"
    
    if check_termux "$device"; then
        echo -e "${GREEN}✓ Termux installed successfully${NC}"
        
        echo -e "${YELLOW}Please open Termux on the device to initialize it, then press Enter...${NC}"
        read -r
        
        return 0
    else
        echo -e "${RED}✗ Termux installation failed${NC}"
        return 1
    fi
}

# Setup Termux environment on device
setup_termux() {
    local device=$1
    local device_name=$2
    
    echo -e "${YELLOW}Setting up Termux on $device_name...${NC}"
    
    # Update packages
    echo -e "${CYAN}Updating Termux packages...${NC}"
    adb -s "$device" shell "run-as com.termux sh -c 'pkg update -y 2>&1 | head -20'" || true
    
    # Install required packages
    echo -e "${CYAN}Installing required packages (netcat-openbsd, termux-services)...${NC}"
    adb -s "$device" shell "run-as com.termux sh -c 'pkg install -y netcat-openbsd termux-services 2>&1 | tail -5'" || true
    
    # Create mesh directory
    echo -e "${CYAN}Creating mesh directory...${NC}"
    adb -s "$device" shell "run-as com.termux mkdir -p /data/data/com.termux/files/home/mesh" || true
    adb -s "$device" shell "run-as com.termux mkdir -p /data/data/com.termux/files/home/mesh/outputs" || true
    adb -s "$device" shell "run-as com.termux mkdir -p /data/data/com.termux/files/home/mesh/logs" || true
    
    echo -e "${GREEN}✓ Termux setup complete${NC}"
}

# Deploy scripts to device
deploy_scripts() {
    local device=$1
    local device_name=$2
    local device_id="${device_name/Device_/}"
    
    echo -e "${YELLOW}Deploying scripts to $device_name...${NC}"
    
    # Push scripts via adb
    echo -e "${CYAN}Copying mesh_listener.sh...${NC}"
    adb -s "$device" push "$TERMUX_SCRIPTS_DIR/mesh_listener.sh" "/sdcard/mesh_listener.sh"
    adb -s "$device" shell "run-as com.termux cp /sdcard/mesh_listener.sh /data/data/com.termux/files/home/mesh/"
    adb -s "$device" shell "run-as com.termux chmod +x /data/data/com.termux/files/home/mesh/mesh_listener.sh"
    
    echo -e "${CYAN}Copying mesh_sender.sh...${NC}"
    adb -s "$device" push "$TERMUX_SCRIPTS_DIR/mesh_sender.sh" "/sdcard/mesh_sender.sh"
    adb -s "$device" shell "run-as com.termux cp /sdcard/mesh_sender.sh /data/data/com.termux/files/home/mesh/"
    adb -s "$device" shell "run-as com.termux chmod +x /data/data/com.termux/files/home/mesh/mesh_sender.sh"
    
    echo -e "${CYAN}Copying run_slm.sh...${NC}"
    adb -s "$device" push "$TERMUX_SCRIPTS_DIR/run_slm.sh" "/sdcard/run_slm.sh"
    adb -s "$device" shell "run-as com.termux cp /sdcard/run_slm.sh /data/data/com.termux/files/home/mesh/"
    adb -s "$device" shell "run-as com.termux chmod +x /data/data/com.termux/files/home/mesh/run_slm.sh"
    
    # Create convenience symlinks
    adb -s "$device" shell "run-as com.termux ln -sf /data/data/com.termux/files/home/mesh/mesh_sender.sh /data/data/com.termux/files/home/send" 2>/dev/null || true
    adb -s "$device" shell "run-as com.termux ln -sf /data/data/com.termux/files/home/mesh/mesh_listener.sh /data/data/com.termux/files/home/listen" 2>/dev/null || true
    
    # Clean up sdcard
    adb -s "$device" shell "rm /sdcard/mesh_listener.sh /sdcard/mesh_sender.sh /sdcard/run_slm.sh" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Scripts deployed${NC}"
}

# Get device IP address
get_device_ip() {
    local device=$1
    adb -s "$device" shell "ip addr show wlan0 | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null | tr -d '\r'
}

# Configure mesh network
configure_mesh() {
    echo -e "\n${YELLOW}Configuring mesh network...${NC}\n"
    
    # Collect device info
    declare -A device_info
    
    for idx in "${!DEVICE_ARRAY[@]}"; do
        local device="${DEVICE_ARRAY[$idx]}"
        local name="${DEVICE_NAMES[$idx]}"
        local device_id="${name/Device_/}"
        local ip=$(get_device_ip "$device")
        
        if [ -z "$ip" ]; then
            echo -e "${RED}✗ Could not get IP for $name${NC}"
            ip="0.0.0.0"
        fi
        
        device_info[$idx]="$device_id:$ip:9999"
        echo -e "  ${CYAN}$name:${NC} $device_id @ $ip:9999"
    done
    
    echo ""
    
    # Configure peers on each device
    for idx in "${!DEVICE_ARRAY[@]}"; do
        local device="${DEVICE_ARRAY[$idx]}"
        local name="${DEVICE_NAMES[$idx]}"
        
        echo -e "${YELLOW}Configuring peers for $name...${NC}"
        
        # Create peers file with all other devices
        local peers_content=""
        for peer_idx in "${!DEVICE_ARRAY[@]}"; do
            if [ "$peer_idx" != "$idx" ]; then
                peers_content+="${device_info[$peer_idx]}\n"
            fi
        done
        
        # Write peers file
        echo -e "$peers_content" | adb -s "$device" shell "run-as com.termux cat > /data/data/com.termux/files/home/mesh/peers.txt"
        
        echo -e "${GREEN}✓ Configured ${#DEVICE_ARRAY[@]} peer(s)${NC}"
    done
    
    echo ""
}

# Create launcher script for each device
create_launcher() {
    local device=$1
    local device_name=$2
    local device_id="${device_name/Device_/}"
    local script_name="start_mesh_${device_id}.sh"
    
    cat > "$script_name" << EOF
#!/bin/bash
# Launcher script for $device_name
# This script starts the mesh listener on the Android device via ADB

DEVICE_SERIAL="$device"
DEVICE_ID="$device_id"

echo "Starting mesh listener on $device_name..."
echo "Device: \$DEVICE_SERIAL"
echo ""

# Start the listener in Termux
adb -s "\$DEVICE_SERIAL" shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home/mesh && ./mesh_listener.sh \$DEVICE_ID 9999'"
EOF
    
    chmod +x "$script_name"
    echo -e "${GREEN}✓ Created launcher: $script_name${NC}"
}

# Generate usage instructions
generate_instructions() {
    cat > "MESH_NETWORK_USAGE.md" << 'EOF'
# Mesh Network Usage Instructions

## Starting the Mesh Network

### Option 1: Using Launcher Scripts (Recommended)

For each device, run the generated launcher script in separate terminals:

```bash
# Terminal 1 - Device A
./start_mesh_A.sh

# Terminal 2 - Device B  
./start_mesh_B.sh

# Terminal 3 - Monitor (optional)
python3 adb_mesh_monitor.py
```

### Option 2: Manual Start via ADB

```bash
# For each device
adb -s <DEVICE_SERIAL> shell
run-as com.termux
cd mesh
./mesh_listener.sh <DEVICE_ID> 9999
```

## Sending Messages

### From Laptop (via ADB)

```bash
# Send text message
adb -s <DEVICE_SERIAL> shell "run-as com.termux sh -c 'cd mesh && ./mesh_sender.sh text Device_B \"Hello from A\"'"

# Send SLM prompt
adb -s <DEVICE_SERIAL> shell "run-as com.termux sh -c 'cd mesh && ./mesh_sender.sh slm Device_B \"Describe this image\"'"

# List peers
adb -s <DEVICE_SERIAL> shell "run-as com.termux sh -c 'cd mesh && ./mesh_sender.sh list'"
```

### From Termux on Device

1. Open Termux on the device
2. Navigate to mesh directory: `cd mesh`
3. Send messages:

```bash
# Send text
./mesh_sender.sh text Device_B "Hello!"

# Send SLM prompt
./mesh_sender.sh slm Device_B "Process this prompt"

# Broadcast to all
./mesh_sender.sh text all "Broadcast message"

# List peers
./mesh_sender.sh list
```

## Monitoring

### Using Python Monitor

```bash
python3 adb_mesh_monitor.py
```

This will show real-time logs from all connected devices.

### Manual Monitoring via ADB

```bash
# Watch logs for a specific device
adb -s <DEVICE_SERIAL> shell "run-as com.termux tail -f mesh/mesh_*.log"
```

## SLM Integration

### Prerequisites

1. Install Genie Bundle on the device
2. Place it in `/data/local/tmp/genie-bundle/`
3. Update `run_slm.sh` with the correct Genie Bundle execution command

### Configuring SLM Execution

Edit `/data/data/com.termux/files/home/mesh/run_slm.sh` on each device to point to your Genie Bundle installation.

Common patterns:
```bash
# Method 1: Shell script
./run_model.sh "$prompt"

# Method 2: Python
python run_inference.py --prompt "$prompt"

# Method 3: Direct binary
./genie --input "$prompt"
```

### Testing SLM

```bash
# Send SLM prompt from Device A to Device B
adb -s <DEVICE_A_SERIAL> shell "run-as com.termux sh -c 'cd mesh && ./mesh_sender.sh slm Device_B \"Test prompt\"'"

# Monitor Device B for execution
# You should see SLM execution logs and results
```

## Troubleshooting

### Mesh listener not starting

- Check Termux is installed: `adb shell pm list packages | grep termux`
- Check netcat is installed: `adb shell "run-as com.termux which nc"`
- Check scripts are executable: `adb shell "run-as com.termux ls -la mesh/"`

### Cannot send messages

- Verify devices are on same network
- Check peer IP addresses: `adb shell "run-as com.termux cat mesh/peers.txt"`
- Test network connectivity: `adb shell "run-as com.termux nc -zv <PEER_IP> 9999"`

### SLM not executing

- Check Genie Bundle path in `run_slm.sh`
- Test Genie Bundle manually: `cd /data/local/tmp/genie-bundle && ./run_model.sh "test"`
- Check permissions on Genie Bundle directory

## Network Topology

The mesh network creates peer-to-peer connections:

```
Device A <---> Device B
    ^            ^
    |            |
    v            v
Device C <---> Device D
```

All devices can communicate directly with each other.

## Message Protocol

Format: `TYPE|FROM_DEVICE|PAYLOAD`

Message types:
- `HELLO`: Device announcement
- `TEXT`: Text message
- `SLM_PROMPT`: Trigger SLM execution
- `SLM_RESULT`: SLM execution result
- `DISCOVER`: Discovery request

## Tips

1. **Always start the listener first** before sending messages
2. **Use the monitor** (`adb_mesh_monitor.py`) to see all activity
3. **Check logs** in `mesh/mesh_*.log` for debugging
4. **Test connectivity** with simple text messages before trying SLM
5. **Ensure same network** - all devices must be on the same WiFi

## Example Workflow

1. Start mesh listener on all devices
2. Verify connectivity with text messages
3. Send SLM prompt from Device A to Device B
4. Monitor Device B for SLM execution
5. View results in logs or via monitor

EOF
    
    echo -e "${GREEN}✓ Created usage guide: MESH_NETWORK_USAGE.md${NC}"
}

# Main installation process
main() {
    check_prerequisites
    
    declare -a DEVICE_ARRAY
    declare -a DEVICE_NAMES
    
    get_devices
    
    echo -e "${CYAN}${BOLD}Setup Process:${NC}"
    echo -e "  1. Install/verify Termux"
    echo -e "  2. Setup Termux environment"
    echo -e "  3. Deploy mesh scripts"
    echo -e "  4. Configure mesh network"
    echo -e "  5. Create launcher scripts"
    echo -e ""
    
    read -p "Press Enter to begin setup or Ctrl+C to cancel..."
    echo ""
    
    # Process each device
    for idx in "${!DEVICE_ARRAY[@]}"; do
        local device="${DEVICE_ARRAY[$idx]}"
        local name="${DEVICE_NAMES[$idx]}"
        
        echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}${BOLD}Processing $name ($device)${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        # Install Termux if needed
        if ! check_termux "$device"; then
            install_termux "$device" "$name" || continue
        else
            echo -e "${GREEN}✓ Termux already installed${NC}"
        fi
        
        # Setup Termux
        setup_termux "$device" "$name"
        
        # Deploy scripts
        deploy_scripts "$device" "$name"
        
        # Create launcher
        create_launcher "$device" "$name"
        
        echo -e "${GREEN}${BOLD}✓ $name setup complete${NC}"
    done
    
    # Configure mesh network
    configure_mesh
    
    # Generate instructions
    generate_instructions
    
    # Summary
    echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                     Setup Complete!                                        ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Start mesh listeners on each device:"
    for idx in "${!DEVICE_ARRAY[@]}"; do
        local name="${DEVICE_NAMES[$idx]}"
        local device_id="${name/Device_/}"
        echo -e "     ${YELLOW}./start_mesh_${device_id}.sh${NC}"
    done
    echo -e "\n  2. Monitor all devices:"
    echo -e "     ${YELLOW}python3 adb_mesh_monitor.py${NC}"
    echo -e "\n  3. Read usage instructions:"
    echo -e "     ${YELLOW}cat MESH_NETWORK_USAGE.md${NC}"
    echo ""
}

# Run main
main
