╔══════════════════════════════════════════════════════════════════════════════╗
║              ORCHESTRATOR SYSTEM - COMPLETE SETUP GUIDE                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 CURRENT STATUS CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Connected Devices: 3 devices
  - 60e0c72f (should be DeviceA)
  - 9688d142 (should be DeviceB)  
  - RZCT90P1WAK (should be DeviceC)

NPU Configuration (in laptop configs):
  - DeviceA: has_npu=true, free_npu=true
  - DeviceB: has_npu=true, free_npu=true
  - DeviceC: has_npu=true, free_npu=true


🚀 COMPLETE SETUP PROCEDURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 1: CLEAN UP ANY EXISTING PROCESSES
────────────────────────────────────────────────────────────────────────────────

Run this to stop everything:

    cd /home/avani/ESW/agentic-ai-storyteller/networking/v2p
    ./stop_bid_listeners.sh
    ./nuclear_cleanup.sh


STEP 2: DEPLOY ALL SCRIPTS TO DEVICES
────────────────────────────────────────────────────────────────────────────────

Deploy the mesh network configs:

    ./deploy_to_devices.sh

When prompted, select devices:
  - DeviceA: 1 (60e0c72f)
  - DeviceB: 2 (9688d142)
  - DeviceC: 3 (RZCT90P1WAK)

This will deploy:
  ✓ mesh_node.sh (with NPU logging)
  ✓ device_X_config.json (with NPU settings)


STEP 3: DEPLOY ORCHESTRATOR SCRIPTS
────────────────────────────────────────────────────────────────────────────────

Deploy the orchestrator components:

    ./deploy_orchestrator.sh

This will deploy to ALL devices:
  ✓ collect_metrics.sh (collects CPU, RAM, NPU status)
  ✓ bid_listener.sh (listens for bid requests on port 5001)
  ✓ orchestrator.sh (runs orchestrator logic)


STEP 4: START BID LISTENERS
────────────────────────────────────────────────────────────────────────────────

Start the bid listeners on all devices:

    ./start_bid_listeners.sh

Expected output:
  ✓ Bid listener started on DeviceA
  ✓ Bid listener started on DeviceB
  ✓ Bid listener started on DeviceC


STEP 5: VERIFY BID LISTENERS ARE RUNNING
────────────────────────────────────────────────────────────────────────────────

Check that listeners are active:

    adb -s 60e0c72f shell "ps -A | grep bid_listener"
    adb -s 9688d142 shell "ps -A | grep bid_listener"
    adb -s RZCT90P1WAK shell "ps -A | grep bid_listener"

Each should show a process like:
  shell     12345  ...  sh bid_listener.sh


STEP 6: TEST THE ORCHESTRATOR
────────────────────────────────────────────────────────────────────────────────

Now trigger the orchestrator from any device:

    ./trigger_orchestrator.sh DeviceA

Expected output:
  ✓ NPU chosen: DeviceB (or DeviceC)

Or try from another device:

    ./trigger_orchestrator.sh DeviceB
    ./trigger_orchestrator.sh DeviceC


🐛 TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Problem: "No bids received"
────────────────────────────────────────────────────────────────────────────────
Cause: Bid listeners not running or wrong IP addresses

Fix:
  1. Check if bid listeners are running:
     adb shell "ps -A | grep bid_listener"
  
  2. Check device IPs match config:
     adb -s 60e0c72f shell "ip addr show wlan0 | grep 'inet '"
     adb -s 9688d142 shell "ip addr show wlan0 | grep 'inet '"
     adb -s RZCT90P1WAK shell "ip addr show wlan0 | grep 'inet '"
  
  3. Update IPs in configs if needed:
     Edit device_a_config.json, device_b_config.json, device_c_config.json
     Then run: ./deploy_to_devices.sh
  
  4. Restart bid listeners:
     ./stop_bid_listeners.sh
     ./start_bid_listeners.sh


Problem: "Could not find DeviceX"
────────────────────────────────────────────────────────────────────────────────
Cause: Device config not deployed or wrong device name

Fix:
  ./deploy_to_devices.sh
  # Make sure to select the right serial numbers for each device


Problem: Chooses CPU instead of NPU
────────────────────────────────────────────────────────────────────────────────
Cause: Device configs on Android have has_npu=false or free_npu=false

Fix:
  1. Check what's on the device:
     adb -s 60e0c72f shell "cat /sdcard/mesh_network/device_config.json"
  
  2. Redeploy configs:
     ./deploy_to_devices.sh


Problem: Port already in use
────────────────────────────────────────────────────────────────────────────────
Fix:
  ./stop_bid_listeners.sh
  ./nuclear_cleanup.sh
  ./start_bid_listeners.sh


🔍 VERIFICATION COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check device IP addresses
adb -s 60e0c72f shell "ip addr show wlan0 | grep 'inet '"
adb -s 9688d142 shell "ip addr show wlan0 | grep 'inet '"
adb -s RZCT90P1WAK shell "ip addr show wlan0 | grep 'inet '"

# Check configs on devices
adb -s 60e0c72f shell "cat /sdcard/mesh_network/device_config.json | grep -E 'device_name|has_npu|free_npu'"
adb -s 9688d142 shell "cat /sdcard/mesh_network/device_config.json | grep -E 'device_name|has_npu|free_npu'"
adb -s RZCT90P1WAK shell "cat /sdcard/mesh_network/device_config.json | grep -E 'device_name|has_npu|free_npu'"

# Check if bid listeners are running
adb shell "ps -A | grep bid_listener | wc -l"
# Should show 3 (one per device)

# Test metrics collection on a device
adb -s 60e0c72f shell "cd /sdcard/mesh_network && sh collect_metrics.sh"
# Should output: true,true,XX.XX,YY.YY (has_npu,free_npu,cpu_load,ram_percent)

# View bid listener logs
adb -s 60e0c72f shell "cat /sdcard/mesh_network/bid_listener.log | tail -20"

# View orchestrator logs
adb -s 60e0c72f shell "cat /sdcard/mesh_network/orchestrator.log | tail -30"


📝 EXPECTED BEHAVIOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

When you run: ./trigger_orchestrator.sh DeviceA

1. DeviceA broadcasts "BID_REQUEST" to DeviceB and DeviceC on port 5001
2. DeviceB and DeviceC receive the request
3. Each collects metrics: has_npu, free_npu, cpu_load, ram_load
4. Each sends "BID_RESPONSE" back to DeviceA on port 5002
5. DeviceA evaluates bids:
   - If ANY device has has_npu=true AND free_npu=true → Choose that device
   - Otherwise → Choose device with lowest CPU load
6. DeviceA prints the chosen device


🎯 QUICK TEST AFTER SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run these commands in sequence:

./stop_bid_listeners.sh                # Clean slate
./nuclear_cleanup.sh                   # Kill all processes
./deploy_to_devices.sh                 # Deploy configs (select 1,2,3)
./deploy_orchestrator.sh               # Deploy orchestrator scripts
./start_bid_listeners.sh               # Start listeners
sleep 3                                # Wait for listeners to stabilize
./trigger_orchestrator.sh DeviceA      # Test!


Expected output:
  ✓ NPU chosen: DeviceB
  or
  ✓ NPU chosen: DeviceC


═══════════════════════════════════════════════════════════════════════════════
             Need help? Check ORCHESTRATOR_README.md for full docs
═══════════════════════════════════════════════════════════════════════════════
