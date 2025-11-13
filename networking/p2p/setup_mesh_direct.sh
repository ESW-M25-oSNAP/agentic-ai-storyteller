#!/bin/bash

# Direct Mesh Network Setup (No run-as required)
# Deploys to /data/local/tmp/mesh instead of Termux private directory

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Direct Mesh Network Setup (No Termux Required)            ║"
echo "║     Deploys to /data/local/tmp/mesh                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get connected devices
DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
NUM_DEVICES=${#DEVICES[@]}

if [ $NUM_DEVICES -eq 0 ]; then
    echo -e "${RED}✗ No devices found${NC}"
    echo "Please connect devices via USB and enable USB debugging"
    exit 1
fi

echo -e "${GREEN}Found $NUM_DEVICES device(s)${NC}"
echo ""

# Assign letters
LETTERS=("A" "B" "C" "D" "E" "F")

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    echo "  Device $LETTER: $SERIAL"
done

echo ""
echo "Setup Process:"
echo "  1. Deploy scripts to /data/local/tmp/mesh"
echo "  2. Get device IPs"
echo "  3. Configure peer list"
echo "  4. Create launcher scripts"
echo ""
read -p "Press Enter to begin setup or Ctrl+C to cancel..."
echo ""

# Store device info
declare -A DEVICE_IPS
declare -A DEVICE_IDS

# Process each device
for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Processing $DEVICE_ID ($SERIAL)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get IP address
    echo -n "Getting IP address... "
    IP=$(adb -s $SERIAL shell "ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" | tr -d '\r\n')
    
    if [ -z "$IP" ]; then
        IP=$(adb -s $SERIAL shell "ip addr show swlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" | tr -d '\r\n')
        if [ -z "$IP" ]; then
            IP="0.0.0.0"
        fi
    else
        echo -e "${GREEN}$IP${NC}"
    fi
    
    DEVICE_IPS[$DEVICE_ID]=$IP
    DEVICE_IDS[$DEVICE_ID]=$SERIAL
    
    # Create directory
    echo -n "Creating mesh directory... "
    adb -s $SERIAL shell "rm -rf /data/local/tmp/mesh 2>/dev/null; mkdir -p /data/local/tmp/mesh" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    
    # Push scripts
    echo -n "Deploying mesh_listener.sh... "
    adb -s $SERIAL push termux/mesh_listener.sh /data/local/tmp/mesh/ >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    echo -n "Deploying mesh_sender.sh... "
    adb -s $SERIAL push termux/mesh_sender.sh /data/local/tmp/mesh/ >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    echo -n "Deploying run_slm.sh... "
    adb -s $SERIAL push termux/run_slm.sh /data/local/tmp/mesh/ >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Make executable
    echo -n "Setting permissions... "
    adb -s $SERIAL shell "chmod +x /data/local/tmp/mesh/*.sh" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    
    # Create device info file
    echo -n "Creating device info... "
    adb -s $SERIAL shell "echo '$DEVICE_ID:$IP:9999' > /data/local/tmp/mesh/my_info.txt" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    
    # Create outputs directory
    adb -s $SERIAL shell "mkdir -p /data/local/tmp/mesh/outputs" 2>/dev/null
    
    echo -e "${GREEN}✓ $DEVICE_ID setup complete${NC}"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Configuring Peer Network${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create peers.txt for each device (containing all OTHER devices)
for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo "Configuring peers for $DEVICE_ID..."
    
    # Build peers list (all devices except this one)
    PEERS_CONTENT=""
    for j in ${!DEVICES[@]}; do
        if [ $i -ne $j ]; then
            OTHER_LETTER="${LETTERS[$j]}"
            OTHER_ID="Device_$OTHER_LETTER"
            OTHER_IP="${DEVICE_IPS[$OTHER_ID]}"
            PEERS_CONTENT+="$OTHER_ID:$OTHER_IP:9999\n"
        fi
    done
    
    # Write peers.txt
    adb -s $SERIAL shell "echo -e '$PEERS_CONTENT' > /data/local/tmp/mesh/peers.txt" 2>/dev/null
    
    NUM_PEERS=$(($NUM_DEVICES - 1))
    echo -e "  ${GREEN}✓ Configured $NUM_PEERS peer(s)${NC}"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Creating Launcher Scripts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create launcher scripts
for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    IP="${DEVICE_IPS[$DEVICE_ID]}"
    
    LAUNCHER="start_mesh_${LETTER}.sh"
    
    cat > $LAUNCHER << EOF
#!/bin/bash
# Mesh Network Listener for $DEVICE_ID
# Serial: $SERIAL
# IP: $IP

echo "Starting mesh listener on $DEVICE_ID ($SERIAL)..."
echo "IP: $IP, Port: 9999"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s $SERIAL shell "cd /data/local/tmp/mesh && ./mesh_listener.sh $DEVICE_ID 9999"
EOF
    
    chmod +x $LAUNCHER
    echo -e "  ${GREEN}✓ Created $LAUNCHER${NC}"
done

# Create status script
cat > check_mesh_status.sh << 'EOF'
#!/bin/bash
# Check mesh network status

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
LETTERS=("A" "B" "C" "D" "E" "F")

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Mesh Network Status Check                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Device $DEVICE_ID ($SERIAL)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if mesh directory exists
    if adb -s $SERIAL shell "[ -d /data/local/tmp/mesh ]" 2>/dev/null; then
        echo "✓ Mesh directory exists"
        
        # Show device info
        echo ""
        echo "Device Info:"
        adb -s $SERIAL shell "cat /data/local/tmp/mesh/my_info.txt 2>/dev/null"
        
        # Show peers
        echo ""
        echo "Known Peers:"
        adb -s $SERIAL shell "cat /data/local/tmp/mesh/peers.txt 2>/dev/null"
        
        # Show recent log entries
        echo ""
        echo "Recent Activity (last 5 lines):"
        adb -s $SERIAL shell "tail -5 /data/local/tmp/mesh/mesh_*.log 2>/dev/null"
        
    else
        echo "✗ Mesh directory not found"
    fi
    
    echo ""
done
EOF

chmod +x check_mesh_status.sh
echo -e "  ${GREEN}✓ Created check_mesh_status.sh${NC}"

# Create manual send script
cat > send_message.sh << 'EOF'
#!/bin/bash
# Manual message sender

if [ $# -lt 3 ]; then
    echo "Usage: $0 <from_device_letter> <to_device_id> <message>"
    echo ""
    echo "Examples:"
    echo "  $0 A Device_B 'Hello from A'"
    echo "  $0 B all 'Broadcast message'"
    exit 1
fi

FROM_LETTER=$1
TO_DEVICE=$2
MESSAGE=$3

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
LETTERS=("A" "B" "C" "D" "E" "F")

# Find serial for from_device
for i in ${!LETTERS[@]}; do
    if [ "${LETTERS[$i]}" == "$FROM_LETTER" ]; then
        SERIAL="${DEVICES[$i]}"
        break
    fi
done

if [ -z "$SERIAL" ]; then
    echo "Error: Device $FROM_LETTER not found"
    exit 1
fi

echo "Sending message from Device_$FROM_LETTER to $TO_DEVICE..."
adb -s $SERIAL shell "cd /data/local/tmp/mesh && ./mesh_sender.sh text $TO_DEVICE '$MESSAGE'"
EOF

chmod +x send_message.sh
echo -e "  ${GREEN}✓ Created send_message.sh${NC}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Setup Complete!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Device Network:"
echo ""

# Create device map file for orchestrator launcher
DEVICE_MAP_FILE="$HOME/.mesh_device_map"
echo "# Device Map for Mesh Network" > "$DEVICE_MAP_FILE"
echo "# Format: DeviceID:Serial:IP" >> "$DEVICE_MAP_FILE"

for i in ${!DEVICES[@]}; do
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    SERIAL="${DEVICES[$i]}"
    IP="${DEVICE_IPS[$DEVICE_ID]}"
    echo "  $DEVICE_ID: $IP (Serial: $SERIAL)"
    echo "${DEVICE_ID}:${SERIAL}:${IP}" >> "$DEVICE_MAP_FILE"
done

echo ""
echo -e "${GREEN}✓ Device map saved to: $DEVICE_MAP_FILE${NC}"
echo ""
echo "Next Steps:"
echo ""
echo "1. Start mesh listeners (in separate terminals):"
for i in ${!DEVICES[@]}; do
    LETTER="${LETTERS[$i]}"
    echo "   ./start_mesh_${LETTER}.sh"
done

echo ""
echo "2. Check status:"
echo "   ./check_mesh_status.sh"

echo ""
echo "3. Send test message:"
echo "   ./send_message.sh A Device_B 'Hello from A!'"

echo ""
echo "4. Run orchestrator on a device:"
echo "   cd ../networking && ./run_orchestrator.sh Device_A"

echo ""
echo "5. Monitor all devices:"
echo "   python3 adb_mesh_monitor.py"

echo ""
echo "Notes:"
echo "  • Scripts deployed to: /data/local/tmp/mesh/"
echo "  • No Termux app required (runs in ADB shell)"
echo "  • Logs stored in: /data/local/tmp/mesh/mesh_*.log"
echo "  • Device configuration stored in: /data/local/tmp/mesh/device_config.json"
echo ""