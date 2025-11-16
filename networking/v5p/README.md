# V4P: Multi-LinUCB Edge Orchestration with Token Predictor

To run the code with Multi-LinUCB bidding and token prediction:
 
1. Configure the three devices, input IP address manually and set NPU parameters
`./setup_configs.sh`

2. Deploy the configured details and Multi-LinUCB solver onto the devices
`./deploy_to_devices.sh`

**Important:** Also deploy the Multi-LinUCB binary and token predictor:
`cd device_scripts && ./deploy_multilin.sh`

3. Cleanup any running process to free the ports
`./nuclear_cleanup.sh`

4. Start Multi-LinUCB bid listeners on all devices (uses new Multi-LinUCB system with token prediction)
`./start_mesh.sh`

5. Monitor all devices simultaneously to see Multi-LinUCB scores and bidding
`./monitor_live.sh`

Or separately (recommended) on three different terminals using
`./monitor_device_a.sh`
`./monitor_device_b.sh`
`./monitor_device_c.sh`

6. Trigger the Multi-LinUCB orchestrator on a given device (DeviceA/DeviceB/DeviceC) 
`./trigger_orchestrator.sh <Device name> <prompt in "">`

Example: `./trigger_orchestrator.sh DeviceA "What is a banana?"`

This will:
- Calculate prompt_length from the prompt
- Use token predictor to estimate output tokens
- Broadcast BID_REQUEST with prompt_length and prompt to all devices on port 5001
- Each device calculates its Multi-LinUCB score based on current CPU/RAM and predicted tokens
- Orchestrator selects device with lowest score (best predicted latency)
- Winner's BidID is returned for feedback loop
- System learns from actual performance (TTFT and tokens/second)

## Key Improvements in Multi-LinUCB

- **Token Prediction**: Integrates external predictor for accurate output token estimation
- **Multi-Objective**: Predicts both TTFT (Time to First Token) and TPS (Tokens Per Second)
- **Better Latency Model**: `Latency = TTFT + (Tokens / TPS)` instead of simple average
- **Uncertainty Quantification**: Uses LinUCB exploration bonus for better device selection

Note: `start_mesh.sh` now starts `bid_listener.sh` (Multi-LinUCB) instead of `mesh_node.sh` (old system)

