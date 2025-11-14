# Device Monitoring Scripts

## Overview
Individual monitoring scripts for each device to view logs in separate terminals.

## Scripts

### Individual Device Monitors
- **`monitor_device_a.sh`** - Monitor DeviceA (60e0c72f) logs only
- **`monitor_device_b.sh`** - Monitor DeviceB (9688d142) logs only
- **`monitor_device_c.sh`** - Monitor DeviceC (RZCT90P1WAK) logs only

### All Devices Monitor (Legacy)
- **`monitor_live.sh`** - Shows all devices in a single terminal with color-coded output

### Multi-Terminal Launcher
- **`monitor_all_devices.sh`** - Opens all 3 device monitors in separate terminal tabs

## Usage

### Option 1: Launch All Monitors at Once (Recommended)
```bash
./monitor_all_devices.sh
```
This will open a new terminal window with 3 tabs:
- Tab 1: DeviceA Monitor
- Tab 2: DeviceB Monitor
- Tab 3: DeviceC Monitor

### Option 2: Launch Individual Monitors Manually
Open 3 separate terminal windows/tabs and run:

**Terminal 1:**
```bash
./monitor_device_a.sh
```

**Terminal 2:**
```bash
./monitor_device_b.sh
```

**Terminal 3:**
```bash
./monitor_device_c.sh
```

### Option 3: Use Combined Monitor (All Devices)
```bash
./monitor_live.sh
```
Shows all devices in one view with color coding

## Output Format

Each device monitor shows:
```
=========================================
Monitoring DeviceX Logs (Live)
=========================================

Press Ctrl+C to stop monitoring

----------------------------------------
[DeviceX] 2025-11-14 06:51:12 [DeviceX] Starting mesh node...
[DeviceX] 2025-11-14 06:51:12 [DeviceX] Connecting to peer...
[DeviceX] {"type":"hello","from":"DeviceY"}
...
```

## Features

- **Real-time monitoring**: Uses `tail -f` for live log streaming
- **Device-specific**: Each script shows only one device's activity
- **Clean output**: Prefixed with `[DeviceX]` for clarity
- **Easy to stop**: Press `Ctrl+C` in any terminal to stop monitoring

## Terminal Emulator Support

The `monitor_all_devices.sh` launcher supports:
- **gnome-terminal** (Ubuntu default) ✅
- **konsole** (KDE) ✅
- **xterm** (Fallback) ✅

If your terminal isn't supported, run the individual scripts manually.

## Workflow Examples

### Example 1: Testing Checkpoint 3
```bash
# Terminal 1: Launch monitors
./monitor_all_devices.sh

# Terminal 2: Trigger orchestrator with prompt
./trigger_orchestrator.sh DeviceA "What is the capital of France?"

# Watch the flow:
# - DeviceA tab: See orchestrator logs, bid collection, prompt sending
# - DeviceB tab: See bid response, prompt execution, result return
# - DeviceC tab: See bid response
```

### Example 2: Debugging Device Issues
```bash
# Monitor only the problematic device
./monitor_device_b.sh

# In another terminal, trigger actions
./trigger_orchestrator.sh DeviceB "Test prompt"
```

### Example 3: Comparing Device Behavior
```bash
# Open all 3 monitors side by side
./monitor_all_devices.sh

# Trigger orchestrator and watch how each device responds
./trigger_orchestrator.sh DeviceA "Who won the World Cup?"

# Observe:
# - Which device sends bids
# - Which device gets chosen
# - How fast each responds
```

## Stopping Monitors

- **Single monitor**: Press `Ctrl+C` in the terminal
- **All monitors**: Close the terminal window or press `Ctrl+C` in each tab
- **Background processes**: They automatically stop when terminal closes

## Log Files Location

All monitors read from:
```
/sdcard/mesh_network/mesh.log (on each Android device)
```

To view historical logs (not live):
```bash
adb -s 60e0c72f shell cat /sdcard/mesh_network/mesh.log       # DeviceA
adb -s 9688d142 shell cat /sdcard/mesh_network/mesh.log        # DeviceB
adb -s RZCT90P1WAK shell cat /sdcard/mesh_network/mesh.log    # DeviceC
```

## Orchestrator Logs

To view orchestrator-specific logs:
```bash
adb -s <orchestrator_serial> shell cat /sdcard/mesh_network/orchestrator.log
```

Example:
```bash
adb -s 60e0c72f shell cat /sdcard/mesh_network/orchestrator.log
```

## Tips

1. **Arrange windows**: Tile the 3 terminal windows side-by-side for best view
2. **Filter output**: Pipe to grep for specific messages:
   ```bash
   ./monitor_device_a.sh | grep "ORCHESTRATOR"
   ```
3. **Save logs**: Redirect to file:
   ```bash
   ./monitor_device_a.sh > devicea_session.log
   ```
4. **Clear old logs**: Before testing, clear device logs:
   ```bash
   adb -s 60e0c72f shell "echo '' > /sdcard/mesh_network/mesh.log"
   ```
