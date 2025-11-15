#!/bin/bash
# ONE-LINE QUICK START - Run this to set everything up automatically

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║           ORCHESTRATOR QUICK START - EASIEST METHOD              ║
╚══════════════════════════════════════════════════════════════════╝

OPTION 1: FULLY AUTOMATED (Recommended for 3 devices)
══════════════════════════════════════════════════════════════════

Run this single command to do everything:

    ./complete_setup.sh

This will:
  1. Clean up existing processes
  2. Deploy all configs to devices
  3. Deploy orchestrator scripts
  4. Start bid listeners
  5. Verify everything is working

Then test with:

    ./trigger_orchestrator.sh DeviceA


OPTION 2: MANUAL STEP-BY-STEP (if automated fails)
══════════════════════════════════════════════════════════════════

./stop_bid_listeners.sh         # 1. Stop old processes
./nuclear_cleanup.sh            # 2. Kill everything
./deploy_to_devices.sh          # 3. Deploy configs (pick 1,2,3)
./deploy_orchestrator.sh        # 4. Deploy scripts
./start_bid_listeners.sh        # 5. Start listeners
./trigger_orchestrator.sh DeviceA   # 6. Test!


CURRENT STATUS
══════════════════════════════════════════════════════════════════

EOF

# Show devices
adb devices | grep device

echo ""
echo "Full guide: COMPLETE_SETUP_GUIDE.md"
echo ""
