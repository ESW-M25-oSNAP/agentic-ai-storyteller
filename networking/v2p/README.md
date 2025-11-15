To run the code with LinUCB bidding:
 
1. Configure the three devices, input IP address manually and enter set NPU parameters
`./setup_configs.sh`

2. Deploy the configured details and LinUCB solver onto the devices
`./deploy_to_devices.sh`

3. Cleanup any running process to free the ports
`./nuclear_cleanup.sh`

4. Start LinUCB bid listeners on all devices (uses new LinUCB system)
`./start_mesh.sh`

5. Monitor all devices simultaneously to see LinUCB scores and bidding
`./monitor_live.sh`

Or separately (recommended) on three different terminals using
`./monitor_device_a.sh`
`./monitor_device_b.sh`
`./monitor_device_c.sh`

6. Trigger the LinUCB orchestrator on a given device (DeviceA/DeviceB/DeviceC) 
`./trigger_orchestrator.sh <Device name> <prompt in "">`

Example: `./trigger_orchestrator.sh DeviceA "What is a banana?"`

This will:
- Calculate prompt_length from the prompt
- Broadcast BID_REQUEST with prompt_length to all devices on port 5001
- Each device calculates its LinUCB score based on current CPU/RAM
- Orchestrator selects device with lowest score (most optimistic)
- Winner's BidID is returned for feedback loop (Checkpoint 3)

Note: `start_mesh.sh` now starts `bid_listener.sh` (LinUCB) instead of `mesh_node.sh` (old system)

