#!/usr/bin/env python3
"""
P2P Mesh Orchestrator
Runs on Android device and coordinates task execution across mesh network
Uses P2P mesh networking for device communication
"""

import json
import time
import subprocess
import os
import sys

class P2POrchestratorError(Exception):
    """Custom exception for P2P Orchestrator errors"""
    pass

class P2POrchestrator:
    def __init__(self, mesh_dir="/data/local/tmp/mesh"):
        self.mesh_dir = mesh_dir
        self.device_id = self.get_device_id()
        self.device_config = self.load_device_config()
        self.peers_file = os.path.join(mesh_dir, "peers.txt")
        self.pending_bids = {}
        self.bid_timeout = 10  # seconds to wait for bids
        
        print(f"{'='*80}")
        print(f"P2P Orchestrator Starting on {self.device_id}")
        print(f"{'='*80}")
        print(f"Mesh Directory: {mesh_dir}")
        print(f"NPU Available: {self.device_config.get('has_npu', False)}")
        print(f"{'='*80}\n")
    
    def get_device_id(self):
        """Get device ID from mesh configuration"""
        try:
            my_info_file = os.path.join(self.mesh_dir, "my_info.txt")
            if os.path.exists(my_info_file):
                with open(my_info_file, 'r') as f:
                    # Format: DeviceID:IP:Port
                    return f.read().strip().split(':')[0]
            return "unknown"
        except Exception as e:
            print(f"Warning: Could not read device ID: {e}")
            return "unknown"
    
    def load_device_config(self):
        """Load device configuration including NPU status"""
        config_file = os.path.join(self.mesh_dir, "device_config.json")
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    return json.load(f)
            else:
                # Create default config
                config = {
                    "device_id": self.device_id,
                    "has_npu": False  # Default to no NPU
                }
                with open(config_file, 'w') as f:
                    json.dump(config, f, indent=2)
                return config
        except Exception as e:
            print(f"Warning: Could not load device config: {e}")
            return {"device_id": self.device_id, "has_npu": False}
    
    def get_connected_peers(self):
        """Get list of connected peer devices"""
        peers = []
        try:
            if os.path.exists(self.peers_file):
                with open(self.peers_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line and ':' in line:
                            parts = line.split(':')
                            if len(parts) >= 3:
                                peers.append({
                                    'device_id': parts[0],
                                    'ip': parts[1],
                                    'port': parts[2]
                                })
        except Exception as e:
            print(f"Error reading peers file: {e}")
        return peers
    
    def send_mesh_message(self, target_device, message_type, data):
        """Send message to target device via mesh network"""
        try:
            message = f"{message_type}|{self.device_id}|{json.dumps(data)}"
            
            # Use mesh_sender.sh to send message
            sender_script = os.path.join(self.mesh_dir, "mesh_sender.sh")
            
            # Create a temporary message file
            msg_file = os.path.join(self.mesh_dir, f"msg_{int(time.time())}.tmp")
            with open(msg_file, 'w') as f:
                f.write(message)
            
            # Send using mesh sender
            cmd = f"sh {sender_script} raw {target_device} '{message}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
            
            # Clean up
            try:
                os.remove(msg_file)
            except:
                pass
            
            return result.returncode == 0
        except Exception as e:
            print(f"Error sending mesh message: {e}")
            return False
    
    def broadcast_bid_request(self, task_id, task_type="slm_inference", prompt=""):
        """Broadcast bid request to all connected peers"""
        print(f"\n{'='*80}")
        print(f"📢 Broadcasting Bid Request: {task_id}")
        print(f"Task Type: {task_type}")
        print(f"{'='*80}\n")
        
        peers = self.get_connected_peers()
        if not peers:
            print("❌ No peers connected!")
            return False
        
        bid_data = {
            "task_id": task_id,
            "task_type": task_type,
            "prompt": prompt,
            "deadline": self.bid_timeout
        }
        
        # Initialize bid tracking
        self.pending_bids[task_id] = {
            "bids": {},
            "start_time": time.time(),
            "prompt": prompt
        }
        
        # Send to all peers
        success_count = 0
        for peer in peers:
            print(f"Sending bid request to {peer['device_id']}...")
            if self.send_mesh_message(peer['device_id'], "BID_REQUEST", bid_data):
                success_count += 1
                print(f"  ✓ Sent to {peer['device_id']}")
            else:
                print(f"  ✗ Failed to send to {peer['device_id']}")
        
        print(f"\n📤 Bid request sent to {success_count}/{len(peers)} peers")
        return success_count > 0
    
    def collect_bids(self, task_id):
        """Collect bids from bid response file"""
        print(f"\n⏳ Waiting {self.bid_timeout}s for bids...\n")
        
        bid_file = os.path.join(self.mesh_dir, f"bids_{task_id}.json")
        start_time = time.time()
        
        # Wait for bid responses
        while (time.time() - start_time) < self.bid_timeout:
            if os.path.exists(bid_file):
                try:
                    with open(bid_file, 'r') as f:
                        bids = json.load(f)
                        if bids:
                            self.pending_bids[task_id]["bids"] = bids
                            break
                except:
                    pass
            time.sleep(0.5)
        
        # Parse bid responses from mesh network logs
        # In practice, this would be handled by mesh_listener.sh writing to a bid file
        return self.pending_bids[task_id]["bids"]
    
    def evaluate_bids(self, task_id):
        """
        Evaluate bids and select winner
        Priority: NPU devices first, then lowest CPU load
        """
        if task_id not in self.pending_bids:
            print(f"❌ Task {task_id} not found")
            return None
        
        bids = self.pending_bids[task_id]["bids"]
        
        if not bids:
            print(f"❌ No bids received for task {task_id}")
            return None
        
        print(f"\n{'='*80}")
        print(f"🎯 EVALUATING BIDS (NPU-First Strategy)")
        print(f"{'='*80}\n")
        
        # Separate NPU and non-NPU devices
        npu_devices = {}
        cpu_devices = {}
        
        for device_id, bid in bids.items():
            has_npu = bid.get('has_npu', False)
            cpu_load = bid.get('cpu_load', 1.0)
            battery = bid.get('battery', 0)
            
            print(f"Device: {device_id}")
            print(f"  NPU: {'✓ YES' if has_npu else '✗ NO'}")
            print(f"  CPU Load: {cpu_load:.2%}")
            print(f"  Battery: {battery}%")
            print()
            
            if has_npu:
                npu_devices[device_id] = bid
            else:
                cpu_devices[device_id] = bid
        
        # Selection logic: NPU first, then lowest CPU
        winner = None
        winner_type = None
        
        if npu_devices:
            # Select NPU device with lowest CPU load
            winner = min(npu_devices.keys(), 
                        key=lambda d: npu_devices[d].get('cpu_load', 1.0))
            winner_type = "NPU"
            print(f"🏆 WINNER (NPU Priority): {winner}")
        elif cpu_devices:
            # Select CPU device with lowest load
            winner = min(cpu_devices.keys(), 
                        key=lambda d: cpu_devices[d].get('cpu_load', 1.0))
            winner_type = "CPU"
            print(f"🏆 WINNER (Lowest CPU): {winner}")
        
        if winner:
            winner_bid = bids[winner]
            print(f"\n📊 Winner Details:")
            print(f"   Device: {winner}")
            print(f"   Type: {winner_type}")
            print(f"   CPU Load: {winner_bid.get('cpu_load', 0):.2%}")
            print(f"   Battery: {winner_bid.get('battery', 0)}%")
            print(f"{'='*80}\n")
        
        return winner, winner_type
    
    def send_task_to_device(self, device_id, task_id, prompt, use_npu=False):
        """Send task to selected device"""
        print(f"\n📤 Sending task to {device_id}...")
        print(f"   Prompt: {prompt[:100]}...")
        print(f"   Using: {'NPU' if use_npu else 'CPU'}")
        
        task_data = {
            "task_id": task_id,
            "prompt": prompt,
            "use_npu": use_npu,
            "prompt_type": "npu_prompt" if use_npu else "cpu_prompt"
        }
        
        # Send task via mesh network
        success = self.send_mesh_message(device_id, "TASK", task_data)
        
        if success:
            print(f"✓ Task sent successfully")
        else:
            print(f"✗ Failed to send task")
        
        return success
    
    def wait_for_result(self, task_id, timeout=300):
        """Wait for result from device"""
        print(f"\n⏳ Waiting for result (timeout: {timeout}s)...\n")
        
        result_file = os.path.join(self.mesh_dir, f"result_{task_id}.json")
        start_time = time.time()
        
        while (time.time() - start_time) < timeout:
            if os.path.exists(result_file):
                try:
                    with open(result_file, 'r') as f:
                        result = json.load(f)
                        print(f"\n{'='*80}")
                        print(f"✅ RESULT RECEIVED")
                        print(f"{'='*80}\n")
                        print(f"Device: {result.get('device_id', 'unknown')}")
                        print(f"Task ID: {result.get('task_id', 'unknown')}")
                        print(f"Status: {result.get('status', 'unknown')}")
                        print(f"\n{'='*80}")
                        print(f"OUTPUT:")
                        print(f"{'='*80}")
                        print(result.get('output', 'No output'))
                        print(f"{'='*80}\n")
                        
                        # Clean up
                        os.remove(result_file)
                        return result
                except Exception as e:
                    print(f"Error reading result: {e}")
            
            time.sleep(1)
        
        print("❌ Timeout waiting for result")
        return None
    
    def run_inference_task(self, prompt, use_npu_prompt=None, use_cpu_prompt=None):
        """
        Main workflow: Request bids, select device, send task, get result
        
        Args:
            prompt: The prompt to execute
            use_npu_prompt: Optional specific prompt for NPU devices
            use_cpu_prompt: Optional specific prompt for CPU devices
        """
        task_id = f"task_{int(time.time())}"
        
        # Step 1: Broadcast bid request
        if not self.broadcast_bid_request(task_id, prompt=prompt):
            print("Failed to broadcast bid request")
            return None
        
        # Step 2: Collect bids
        bids = self.collect_bids(task_id)
        
        # Step 3: Evaluate and select winner
        result = self.evaluate_bids(task_id)
        if not result:
            print("No device selected")
            return None
        
        winner_device, winner_type = result
        
        # Step 4: Select appropriate prompt
        if winner_type == "NPU" and use_npu_prompt:
            final_prompt = use_npu_prompt
        elif winner_type == "CPU" and use_cpu_prompt:
            final_prompt = use_cpu_prompt
        else:
            final_prompt = prompt
        
        # Step 5: Send task to winner
        use_npu = (winner_type == "NPU")
        if not self.send_task_to_device(winner_device, task_id, final_prompt, use_npu):
            print("Failed to send task")
            return None
        
        # Step 6: Wait for result
        result = self.wait_for_result(task_id)
        
        # Clean up
        if task_id in self.pending_bids:
            del self.pending_bids[task_id]
        
        return result

def main():
    """Main entry point"""
    print("\n" + "="*80)
    print("P2P MESH ORCHESTRATOR")
    print("="*80 + "\n")
    
    try:
        orchestrator = P2POrchestrator()
        
        # Check for peers
        peers = orchestrator.get_connected_peers()
        print(f"Connected Peers: {len(peers)}")
        for peer in peers:
            print(f"  - {peer['device_id']} ({peer['ip']}:{peer['port']})")
        print()
        
        if not peers:
            print("⚠️  No peers connected. Please ensure devices are connected to mesh network.")
            print("   Run setup_mesh_direct.sh to configure mesh network.")
            return
        
        # Interactive mode
        print("Enter prompt for inference (or 'exit' to quit):")
        
        while True:
            try:
                prompt = input("\n> ").strip()
                
                if prompt.lower() in ['exit', 'quit', 'q']:
                    print("Exiting...")
                    break
                
                if not prompt:
                    continue
                
                # Run inference task
                result = orchestrator.run_inference_task(
                    prompt=prompt,
                    use_npu_prompt=f"[NPU Optimized] {prompt}",
                    use_cpu_prompt=f"[CPU Mode] {prompt}"
                )
                
                if result:
                    print("\n✓ Task completed successfully")
                else:
                    print("\n✗ Task failed")
                
            except KeyboardInterrupt:
                print("\n\nInterrupted by user")
                break
            except Exception as e:
                print(f"Error: {e}")
        
    except Exception as e:
        print(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
