#!/bin/bash
# Quick Start Guide for Checkpoint 2 Orchestrator System

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║         CHECKPOINT 2 - ORCHESTRATOR QUICK START                  ║
╚══════════════════════════════════════════════════════════════════╝

📖 READ THIS FIRST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All requirements from working.txt Checkpoint 2 have been implemented!

✅ Pure bash scripts (no Python)
✅ Trigger from laptop: ./trigger_orchestrator.sh <device_name>
✅ Bid system with {has_NPU, CPU_Load, RAM_Load, npu_free}
✅ Evaluation logic: NPU first, then lowest CPU


🚀 STEP-BY-STEP USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Deploy Scripts (one-time setup)
────────────────────────────────────────
./deploy_orchestrator.sh


Step 2: Start Bid Listeners (do this after each reboot)
────────────────────────────────────────────────────────
./start_bid_listeners.sh


Step 3: Trigger Orchestrator
─────────────────────────────
./trigger_orchestrator.sh DeviceA
# or DeviceB, or DeviceC


🎯 EXAMPLE OUTPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ ./trigger_orchestrator.sh DeviceB

=========================================
Triggering Orchestrator on DeviceB
=========================================

✓ Found DeviceB on device 9688d142

Starting orchestrator on DeviceB...
=========================================

✓ NPU chosen: DeviceA

=========================================
Orchestrator completed on DeviceB
=========================================


🔧 MANAGEMENT COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stop bid listeners:
    ./stop_bid_listeners.sh

Check if listeners are running:
    adb shell ps -A | grep bid_listener

View orchestrator log:
    adb -s <serial> shell cat /sdcard/mesh_network/orchestrator.log

View bid listener log:
    adb -s <serial> shell cat /sdcard/mesh_network/bid_listener.log

Test metrics collection:
    adb -s <serial> shell "cd /sdcard/mesh_network && sh collect_metrics.sh"


🐛 TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Problem: "No bids received"
Solution: 
    ./stop_bid_listeners.sh
    ./start_bid_listeners.sh
    # Then try again

Problem: "Could not find DeviceX"
Solution:
    # Check device configs are deployed
    ./deploy_orchestrator.sh

Problem: Port already in use
Solution:
    ./stop_bid_listeners.sh
    # Kill any remaining nc processes
    adb shell pkill -9 nc


📚 DOCUMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Full Guide:       ORCHESTRATOR_README.md
Implementation:   CHECKPOINT2_STATUS.md
Summary:          CHECKPOINT2_SUMMARY.md
This Guide:       QUICK_START_CHECKPOINT2.sh


═══════════════════════════════════════════════════════════════════
                    🎉 READY TO GO! 🎉
═══════════════════════════════════════════════════════════════════

EOF
