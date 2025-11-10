#!/bin/bash
# Complete Laptop-Based Mesh Network Setup for 3 Devices
# All scripts run via ADB, full visibility from laptop

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Laptop-Based Mesh Network Setup (3 Devices)               ║"
echo "║     Complete control and monitoring from laptop                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Auto-detect devices
DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
NUM_DEVICES=${#DEVICES[@]}

if [ $NUM_DEVICES -lt 2 ]; then
    echo -e "${RED}✗ Need at least 2 devices, found $NUM_DEVICES${NC}"
    exit 1
fi

echo -e "${GREEN}Found $NUM_DEVICES device(s)${NC}"
echo ""

# Assign device names
LETTERS=("A" "B" "C" "D" "E" "F")

declare -A DEVICE_SERIALS
declare -A DEVICE_IPS
declare -A DEVICE_IDS

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    DEVICE_SERIALS[$DEVICE_ID]=$SERIAL
    DEVICE_IDS[$LETTER]=$DEVICE_ID
    
    echo "  $DEVICE_ID: $SERIAL"
done

echo ""
read -p "Press Enter to begin setup..."
echo ""

# Deploy to each device
for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Setting up $DEVICE_ID ($SERIAL)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get IP
    echo -n "Getting IP address... "
    IP=$(adb -s $SERIAL shell "ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" | tr -d '\r\n')
    if [ -z "$IP" ]; then
        echo -e "${YELLOW}No WiFi IP${NC}"
        IP="0.0.0.0"
    else
        echo -e "${GREEN}$IP${NC}"
    fi
    DEVICE_IPS[$DEVICE_ID]=$IP
    
    # Create directory
    echo -n "Creating mesh directory... "
    adb -s $SERIAL shell "rm -rf /data/local/tmp/mesh 2>/dev/null; mkdir -p /data/local/tmp/mesh/outputs" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    
    # Push scripts
    echo -n "Deploying scripts... "
    adb -s $SERIAL push mesh_listener_standalone.sh /data/local/tmp/mesh/mesh_listener.sh >/dev/null 2>&1
    adb -s $SERIAL push mesh_sender_standalone.sh /data/local/tmp/mesh/mesh_sender.sh >/dev/null 2>&1
    adb -s $SERIAL push termux/run_slm.sh /data/local/tmp/mesh/run_slm.sh >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Set permissions
    echo -n "Setting permissions... "
    adb -s $SERIAL shell "chmod 755 /data/local/tmp/mesh/*.sh" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    
    # Create device info
    adb -s $SERIAL shell "echo '$DEVICE_ID:$IP:9999' > /data/local/tmp/mesh/my_info.txt" 2>/dev/null
    
    echo -e "${GREEN}✓ $DEVICE_ID ready${NC}"
    echo ""
done

# Configure peer lists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Configuring Peer Network${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    
    echo "Configuring peers for $DEVICE_ID..."
    
    # Build peers list
    PEERS_CONTENT=""
    for j in ${!DEVICES[@]}; do
        if [ $i -ne $j ]; then
            OTHER_LETTER="${LETTERS[$j]}"
            OTHER_ID="Device_$OTHER_LETTER"
            OTHER_IP="${DEVICE_IPS[$OTHER_ID]}"
            PEERS_CONTENT+="$OTHER_ID:$OTHER_IP:9999\n"
        fi
    done
    
    adb -s $SERIAL shell "echo -e '$PEERS_CONTENT' > /data/local/tmp/mesh/peers.txt" 2>/dev/null
    
    NUM_PEERS=$(($NUM_DEVICES - 1))
    echo -e "  ${GREEN}✓ Configured $NUM_PEERS peer(s)${NC}"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Creating Control Scripts${NC}"
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
# Serial: $SERIAL, IP: $IP

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Mesh Listener: $DEVICE_ID                                     "
echo "║  Serial: $SERIAL                                               "
echo "║  IP: $IP                                                       "
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Press Ctrl+C to stop"
echo ""

adb -s $SERIAL shell "cd /data/local/tmp/mesh && sh mesh_listener.sh $DEVICE_ID 9999"
EOF
    
    chmod +x $LAUNCHER
    echo -e "  ${GREEN}✓ Created $LAUNCHER${NC}"
done

# Create master launcher
cat > start_all_mesh.sh << 'EOFMASTER'
#!/bin/bash
# Start all mesh listeners in separate terminal windows

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Starting all mesh listeners..."
echo ""

# Check if running in tmux
if [ -n "$TMUX" ]; then
    echo "Running in tmux - creating new panes..."
    
    # Split vertically for first device
    tmux split-window -h "$SCRIPT_DIR/start_mesh_A.sh"
    
    # Split horizontally for second device
    tmux split-window -v "$SCRIPT_DIR/start_mesh_B.sh"
    
    # Select first pane and split for third device
    tmux select-pane -t 0
    tmux split-window -v "$SCRIPT_DIR/start_mesh_C.sh"
    
    echo "✓ All listeners started in tmux panes"
else
    echo "Please run this in tmux or start manually:"
    echo ""
    echo "Terminal 1: ./start_mesh_A.sh"
    echo "Terminal 2: ./start_mesh_B.sh"
    echo "Terminal 3: ./start_mesh_C.sh"
fi
EOFMASTER

chmod +x start_all_mesh.sh
echo -e "  ${GREEN}✓ Created start_all_mesh.sh${NC}"

# Create message sender
cat > send.sh << 'EOF'
#!/bin/bash
# Quick message sender from laptop

if [ $# -lt 3 ]; then
    echo "Usage: $0 <from_device> <to_device> <message>"
    echo ""
    echo "Devices: A, B, C"
    echo "Special: 'all' to broadcast"
    echo ""
    echo "Examples:"
    echo "  $0 A B 'Hello from A'"
    echo "  $0 B all 'Broadcast message'"
    exit 1
fi

FROM=$1
TO=$2
shift 2
MESSAGE="$*"

# Get device serials
case $FROM in
    A) SERIAL="60e0c72f" ;;
    B) SERIAL="9688d142" ;;
    C) SERIAL="RZCT90P1WAK" ;;
    *) echo "Unknown device: $FROM"; exit 1 ;;
esac

TO_DEVICE="Device_$TO"
if [ "$TO" = "all" ]; then
    TO_DEVICE="all"
fi

echo "Sending: Device_$FROM → $TO_DEVICE"
echo "Message: $MESSAGE"
echo ""

adb -s $SERIAL shell "cd /data/local/tmp/mesh && sh mesh_sender.sh text $TO_DEVICE '$MESSAGE'"
EOF

chmod +x send.sh
echo -e "  ${GREEN}✓ Created send.sh${NC}"

# Create status checker
cat > status.sh << 'EOF'
#!/bin/bash
# Check mesh network status

DEVICES=(60e0c72f 9688d142 RZCT90P1WAK)
LETTERS=(A B C)

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Mesh Network Status                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

for i in ${!DEVICES[@]}; do
    SERIAL="${DEVICES[$i]}"
    LETTER="${LETTERS[$i]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Device $LETTER ($SERIAL)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check connection
    adb -s $SERIAL get-state >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Connected via ADB"
        
        # IP address
        IP=$(adb -s $SERIAL shell "ip addr show wlan0 | grep 'inet '" | awk '{print $2}' | cut -d'/' -f1 | tr -d '\r')
        echo "  IP: $IP"
        
        # Check if listener is running
        LISTENER=$(adb -s $SERIAL shell "ps | grep mesh_listener" | grep -v grep)
        if [ -n "$LISTENER" ]; then
            echo "  ✓ Listener running"
        else
            echo "  ✗ Listener not running"
        fi
        
        # Peer count
        PEER_COUNT=$(adb -s $SERIAL shell "wc -l < /data/local/tmp/mesh/peers.txt 2>/dev/null" | tr -d '\r')
        echo "  Peers configured: $PEER_COUNT"
        
        # Recent log
        echo "  Recent activity:"
        adb -s $SERIAL shell "tail -3 /data/local/tmp/mesh/mesh_Device_${LETTER}.log 2>/dev/null" | sed 's/^/    /'
        
    else
        echo "✗ Not connected"
    fi
    
    echo ""
done
EOF

chmod +x status.sh
echo -e "  ${GREEN}✓ Created status.sh${NC}"

# Create live monitor
cat > monitor.sh << 'EOF'
#!/bin/bash
# Live monitoring of all devices

DEVICES=(60e0c72f 9688d142 RZCT90P1WAK)
LETTERS=(A B C)
COLORS=('\033[0;32m' '\033[0;34m' '\033[0;35m')
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Live Mesh Network Monitor                            ║"
echo "║           Press Ctrl+C to stop                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Tail all logs simultaneously
tail -f \
  >(adb -s 60e0c72f shell "tail -f /data/local/tmp/mesh/mesh_Device_A.log 2>/dev/null" | sed "s/^/[A] /" --unbuffered) \
  >(adb -s 9688d142 shell "tail -f /data/local/tmp/mesh/mesh_Device_B.log 2>/dev/null" | sed "s/^/[B] /" --unbuffered) \
  >(adb -s RZCT90P1WAK shell "tail -f /data/local/tmp/mesh/mesh_Device_C.log 2>/dev/null" | sed "s/^/[C] /" --unbuffered) \
  2>/dev/null
EOF

chmod +x monitor.sh
echo -e "  ${GREEN}✓ Created monitor.sh${NC}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Setup Complete!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Device Network:"
echo ""

for i in ${!DEVICES[@]}; do
    LETTER="${LETTERS[$i]}"
    DEVICE_ID="Device_$LETTER"
    SERIAL="${DEVICES[$i]}"
    IP="${DEVICE_IPS[$DEVICE_ID]}"
    echo "  $DEVICE_ID: $IP (Serial: $SERIAL)"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Start Commands (from laptop):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Start listeners (open 3 terminals):"
echo "   Terminal 1: ./start_mesh_A.sh"
echo "   Terminal 2: ./start_mesh_B.sh"
echo "   Terminal 3: ./start_mesh_C.sh"
echo ""
echo "2. Send messages:"
echo "   ./send.sh A B 'Hello from A to B'"
echo "   ./send.sh B C 'Hello from B to C'"
echo "   ./send.sh A all 'Broadcast from A'"
echo ""
echo "3. Check status:"
echo "   ./status.sh"
echo ""
echo "4. Live monitor (real-time logs):"
echo "   ./monitor.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
