#!/bin/bash
# Quick Start Guide for P2P Orchestrator

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║           P2P ORCHESTRATOR - QUICK START GUIDE                 ║
╚════════════════════════════════════════════════════════════════╝

STEP 1: Setup Mesh Network
─────────────────────────────────────────────────────────────────
$ cd networking/p2p
$ ./setup_mesh_direct.sh

This will:
  • Deploy scripts to all connected Android devices
  • Configure peer lists
  • Prompt for NPU configuration for each device
  • Create device map file


STEP 2: Start Mesh Listeners (in separate terminals)
─────────────────────────────────────────────────────────────────
$ ./start_mesh_A.sh    # Terminal 1
$ ./start_mesh_B.sh    # Terminal 2
$ ./start_mesh_C.sh    # Terminal 3

You should see:
  [READY] Mesh listener is ready!
  [READY] Listening on port 9999...


STEP 3: Launch Orchestrator on a Device
─────────────────────────────────────────────────────────────────
$ cd ../networking
$ ./run_orchestrator.sh Device_A

Choose any device to run the orchestrator. It will coordinate
with all other devices in the mesh.

The script will prompt for NPU configuration on first run:
  Does this device have NPU? (y/n): y


STEP 4: Submit Inference Tasks
─────────────────────────────────────────────────────────────────
In the orchestrator interface, enter your prompt:

  > Describe a beautiful sunset over the ocean

The orchestrator will:
  1. Broadcast bid request to all devices
  2. Collect bids (CPU, RAM, Battery, NPU status)
  3. Select best device (NPU-first, then lowest CPU)
  4. Send task with appropriate prompt
  5. Display result when complete


CHECKING STATUS
─────────────────────────────────────────────────────────────────
View connected devices:
  $ cat ~/.mesh_device_map

Check mesh listeners:
  $ cd networking/p2p
  $ ./check_mesh_status.sh

View device logs:
  $ adb shell cat /data/local/tmp/mesh/mesh_Device_A.log


UPDATING NPU CONFIGURATION
─────────────────────────────────────────────────────────────────
To change NPU setting for a device:

$ adb shell
# echo '{"device_id": "Device_A", "has_npu": true}' > /data/local/tmp/mesh/device_config.json
# exit

Then restart the mesh listener for that device.


TROUBLESHOOTING
─────────────────────────────────────────────────────────────────
Problem: No bids received
Solution: Check all mesh listeners are running
  $ ./check_mesh_status.sh

Problem: Orchestrator won't start
Solution: Check device map exists
  $ ls -la ~/.mesh_device_map

Problem: Device not responding
Solution: Check device logs
  $ adb shell cat /data/local/tmp/mesh/mesh_Device_A.log


ARCHITECTURE
─────────────────────────────────────────────────────────────────
Laptop          →  Triggers orchestrator on Device_A
Device_A        →  Runs orchestrator, broadcasts bid request
Device_B/C/D    →  Send bids with metrics
Device_A        →  Selects winner, sends task
Winner Device   →  Executes SLM, sends result back
Device_A        →  Displays final result


FILE LOCATIONS
─────────────────────────────────────────────────────────────────
On Device:
  /data/local/tmp/mesh/                    # Mesh directory
  /data/local/tmp/mesh/device_config.json  # NPU config
  /data/local/tmp/mesh/peers.txt           # Peer list
  /data/local/tmp/mesh/mesh_*.log          # Logs

On Laptop:
  ~/.mesh_device_map                       # Device mapping
  networking/run_orchestrator.sh           # Orchestrator launcher
  networking/src/orchestrator_p2p.py       # Orchestrator code
  networking/p2p/termux/mesh_listener.sh   # Device listener
  networking/p2p/termux/mesh_sender.sh     # Message sender


For detailed documentation, see:
  networking/P2P_ORCHESTRATOR_ARCHITECTURE.md

╚════════════════════════════════════════════════════════════════╝
EOF
