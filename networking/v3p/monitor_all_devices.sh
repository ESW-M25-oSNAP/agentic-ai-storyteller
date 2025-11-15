#!/bin/bash
# Launch separate monitors for all 3 devices in different terminal tabs
# Works with gnome-terminal (default on Ubuntu)

echo "========================================="
echo "Launching Device Monitors"
echo "========================================="
echo ""
echo "Opening 3 terminal tabs:"
echo "  - Tab 1: DeviceA Monitor"
echo "  - Tab 2: DeviceB Monitor"  
echo "  - Tab 3: DeviceC Monitor"
echo ""

# Check if gnome-terminal is available
if command -v gnome-terminal &> /dev/null; then
    gnome-terminal \
        --tab --title="DeviceA Monitor" -- bash -c "./monitor_device_a.sh; exec bash" \
        --tab --title="DeviceB Monitor" -- bash -c "./monitor_device_b.sh; exec bash" \
        --tab --title="DeviceC Monitor" -- bash -c "./monitor_device_c.sh; exec bash"
    echo "✓ Monitors launched in new terminal window"
    
elif command -v xterm &> /dev/null; then
    # Fallback to xterm
    xterm -T "DeviceA Monitor" -e "./monitor_device_a.sh" &
    xterm -T "DeviceB Monitor" -e "./monitor_device_b.sh" &
    xterm -T "DeviceC Monitor" -e "./monitor_device_c.sh" &
    echo "✓ Monitors launched in separate xterm windows"
    
elif command -v konsole &> /dev/null; then
    # Fallback to konsole (KDE)
    konsole --new-tab -e "./monitor_device_a.sh" \
            --new-tab -e "./monitor_device_b.sh" \
            --new-tab -e "./monitor_device_c.sh" &
    echo "✓ Monitors launched in konsole tabs"
    
else
    echo "⚠️  No supported terminal emulator found (gnome-terminal, xterm, konsole)"
    echo ""
    echo "Please run manually in separate terminals:"
    echo "  Terminal 1: ./monitor_device_a.sh"
    echo "  Terminal 2: ./monitor_device_b.sh"
    echo "  Terminal 3: ./monitor_device_c.sh"
    exit 1
fi

echo ""
echo "To stop monitoring: Close the terminal tabs or press Ctrl+C in each"
