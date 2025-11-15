To run the code:
 
1. Configure the three devices, input IP address manually and enter set NPU parameters
`./setup_configs.sh`

2. Deploy the configured details onto the devices
`./deploy_to_devices.sh `

3. Cleanup any running process to free the ports
`./nuclear_cleanup.sh`

4. Start mesh on all devices simulatneously 
`./start_mesh.sh`

5. Monitor all devices simultaneously 
`./monitor_live.sh`

Or separately (recommended) on three different terminals using
`./monitor_device_a.sh`
`./monitor_device_b.sh`
`./monitor_device_c.sh`

6. Trigger the orchestrator on a given device (DeviceA/DeviceB/DeviceC) 
`./trigger_orchestrator.sh <Device name> <prompt in "">`

Example: ./trigger_orchestrator.sh DeviceA "What is a banana?"

