import socket
import threading
import json
import base64
import cv2
import numpy as np
import uuid
import time
import random

class Orchestrator:
    def __init__(self, host='0.0.0.0', port=8080):
        self.devices = {}  # {deviceId: {"has_npu", "capabilities", "metrics", "conn"}}
        self.scores = {}   # For EdgeMLBalancer integration
        self.logs = []     # Historical metrics
        self.task_map = {"classify": ["A", "B"], "segment": ["A"]}
        self.pending_bids = {}  # {task_id: {"image_data": base64, "bids": {device_id: bid_data}}}
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.bind((host, port))
        self.server.listen(5)
        print(f"Listening on {host}:{port}")

    def is_overloaded(self, device):
        metrics = self.devices.get(device, {}).get("metrics", {})
        return metrics.get("cpu_load", 0) > 0.8 or metrics.get("battery", 100) < 20
    
    def print_device_metrics(self, device_id):
        """Print device metrics in a formatted way"""
        if device_id not in self.devices:
            return
        
        device_info = self.devices[device_id]
        metrics = device_info.get("metrics", {})
        
        print(f"┌{'─'*78}┐")
        print(f"│ Device ID: {device_id:<64} │")
        print(f"├{'─'*78}┤")
        
        # NPU and Capabilities
        has_npu = device_info.get("has_npu", False)
        npu_status = "✓ YES" if has_npu else "✗ NO"
        capabilities = ", ".join(device_info.get("capabilities", []))
        print(f"│ NPU Present:     {npu_status:<60} │")
        print(f"│ Capabilities:    {capabilities:<60} │")
        print(f"├{'─'*78}┤")
        
        # CPU Load
        cpu_load = metrics.get("cpu_load", 0)
        cpu_bar = self.get_progress_bar(cpu_load, 30)
        print(f"│ CPU Load:        {cpu_bar} {cpu_load*100:5.1f}%{' '*15}│")
        
        # Battery
        battery = metrics.get("battery", 0)
        battery_normalized = battery / 100.0 if battery > 0 else 0
        battery_bar = self.get_progress_bar(battery_normalized, 30)
        battery_icon = "🔋" if battery > 20 else "⚠️"
        print(f"│ Battery:         {battery_bar} {battery:5.1f}% {battery_icon}{' '*13}│")
        
        # RAM Usage
        ram = metrics.get("ram", {})
        if ram:
            ram_used = ram.get("used_mb", 0)
            ram_total = ram.get("total_mb", 1)
            ram_percent = ram.get("usage_percent", 0) / 100.0
            ram_bar = self.get_progress_bar(ram_percent, 30)
            print(f"│ RAM Usage:       {ram_bar} {ram_used:5.0f}/{ram_total:5.0f} MB ({ram_percent*100:5.1f}%) │")
        
        # Storage
        storage = metrics.get("storage", {})
        if storage:
            storage_used = storage.get("used_gb", 0)
            storage_total = storage.get("total_gb", 1)
            storage_free = storage.get("free_gb", 0)
            storage_percent = storage.get("usage_percent", 0) / 100.0
            storage_bar = self.get_progress_bar(storage_percent, 30)
            print(f"│ Storage:         {storage_bar} {storage_free:5.1f}/{storage_total:5.1f} GB free{' '*7}│")
        
    print(f"└{'─'*78}┘")
    print()
    
    def get_progress_bar(self, value, width=30):
        """Generate a progress bar string"""
        filled = int(value * width)
        empty = width - filled
        bar = "█" * filled + "░" * empty
        return f"[{bar}]"

    def accept_connections(self):
        while True:
            conn, addr = self.server.accept()
            print(f"New connection from {addr}")
            threading.Thread(target=self.handle_client, args=(conn,)).start()

    import random
    def handle_client(self, conn):
        buffer = ""
        random_battery = random.randint(10, 100)  # Generate once per connection
        while True:
            try:
                data = conn.recv(4096).decode()
                if not data:
                    print("Connection closed")
                    break
                buffer += data
                # Try to parse complete JSON messages
                while buffer:
                    try:
                        decoder = json.JSONDecoder()
                        msg, idx = decoder.raw_decode(buffer)
                        buffer = buffer[idx:].lstrip()
                        # Inject random battery into registration/status metrics
                        if msg.get("type") in ("register", "status") and "metrics" in msg.get("data", {}):
                            msg["data"]["metrics"]["battery"] = random_battery
                        self.process_message(msg, conn)
                    except json.JSONDecodeError:
                        break
            except Exception as e:
                print(f"Error in handle_client: {e}")
                break
        conn.close()
        for dev_id in list(self.devices.keys()):
            if self.devices[dev_id]["conn"] == conn:
                del self.devices[dev_id]
                print(f"Removed {dev_id} from registry")
    
    def process_message(self, msg, conn):
        """Process a complete JSON message"""
        device_id = msg.get("agent_id") or msg["data"].get("deviceId")
        
        if msg["type"] == "register":
            self.devices[device_id] = {
                "has_npu": msg["data"]["hasNpu"],
                "capabilities": msg["data"]["capabilities"],
                "metrics": msg["data"]["metrics"],
                "conn": conn
            }
            print(f"\n{'='*80}")
            print(f"✅ NEW DEVICE REGISTERED: {device_id}")
            print(f"{'='*80}")
            self.print_device_metrics(device_id)
            
        elif msg["type"] == "status":
            if device_id in self.devices:
                self.devices[device_id]["metrics"] = msg["data"]["metrics"]
                print(f"\n📊 STATUS UPDATE: {device_id}")
                self.print_device_metrics(device_id)
        elif msg["type"] == "image":
            # Image received from device, initiate bidding process
            print(f"Image received from {device_id}")
            self.handle_image_received(device_id, msg["data"])
        elif msg["type"] == "bid":
            # Bid received from device
            print(f"Bid received from {device_id}: {msg['data']}")
            self.handle_bid_received(device_id, msg)
        elif msg["type"] == "result":
            print(f"Result from {device_id}: {msg['data']}")
            
            # Handle classification results specifically
            if msg['data'].get('status') == 'classification_complete':
                classification = msg['data'].get('classification', '')
                print(f"🎯 CLASSIFICATION RESULT from {device_id}:")
                print(f"   {classification}")
                print(f"   Image processed successfully!")
                
            # For EdgeMLBalancer: Update scores with confidence
            task = msg["subtask"]
            confidence = msg["data"].get("confidence", 0.5)
            if device_id in self.devices:
                cpu_load = self.devices[device_id]["metrics"].get("cpu_load", 0.5)
                self.update_scores(task, device_id, cpu_load, confidence)
        elif msg["type"] == "heartbeat":
            print(f"Heartbeat from {device_id}")

    def handle_image_received(self, source_device, data):
        """Handle image received from Android device and initiate bidding"""
        task_id = str(uuid.uuid4())
        image_data = data.get("image_base64", "")
        
        print(f"Starting bidding process for task {task_id}")
        
        # Initialize pending bids for this task
        self.pending_bids[task_id] = {
            "image_data": image_data,
            "bids": {},
            "source_device": source_device,
            "start_time": time.time()
        }
        
        # Request bids from all connected devices
        bid_request = {
            "type": "bid_request",
            "agent_id": "orchestrator",
            "task_id": task_id,
            "subtask": "classify",
            "data": {
                "task_type": "image_classification",
                "deadline": 30  # seconds
            }
        }
        
        bid_request_json = json.dumps(bid_request)
        for device_id, device_info in self.devices.items():
            if "classify" in device_info["capabilities"]:
                try:
                    device_info["conn"].send(bid_request_json.encode())
                    print(f"Sent bid request to {device_id}")
                except Exception as e:
                    print(f"Failed to send bid request to {device_id}: {e}")
        
        # Set timer to evaluate bids after 5 seconds
        threading.Timer(5.0, self.evaluate_bids, args=[task_id]).start()

    def handle_bid_received(self, device_id, msg):
        """Handle bid received from device"""
        task_id = msg["task_id"]
        bid_data = msg["data"]
        
        if task_id in self.pending_bids:
            self.pending_bids[task_id]["bids"][device_id] = bid_data
            cpu_load = bid_data.get('cpu_load', 'N/A')
            battery = bid_data.get('battery', 'N/A')
            has_npu = bid_data.get('has_npu', False)
            npu_str = "✓ NPU" if has_npu else "✗ No NPU"
            print(f"📨 Bid from {device_id}: CPU={cpu_load:.2f}, Battery={battery}%, {npu_str}")

    def evaluate_bids(self, task_id):
        """Evaluate bids and select winning device based on lowest CPU load"""
        if task_id not in self.pending_bids:
            print(f"Task {task_id} not found in pending bids")
            return
        
        task_info = self.pending_bids[task_id]
        bids = task_info["bids"]
        
        if not bids:
            print(f"❌ No bids received for task {task_id}")
            del self.pending_bids[task_id]
            return
        
        print(f"\n{'='*80}")
        print(f"🎯 EVALUATING BIDS FOR TASK {task_id}")
        print(f"{'='*80}")
        
        # Display all bids
        for dev_id, bid in bids.items():
            cpu = bid.get('cpu_load', 1.0)
            battery = bid.get('battery', 0)
            ram = bid.get('ram', {})
            ram_percent = ram.get('usage_percent', 0) if ram else 0
            npu = "✓" if bid.get('has_npu', False) else "✗"
            print(f"  {dev_id}: CPU={cpu:.2%}, Battery={battery}%, RAM={ram_percent:.1f}%, NPU={npu}")
        
        # Select device with lowest CPU load
        winner = min(bids.keys(), key=lambda d: bids[d].get("cpu_load", 1.0))
        winner_bid = bids[winner]
        
        print(f"\n🏆 WINNER: {winner}")
        print(f"   CPU Load: {winner_bid.get('cpu_load', 0):.2%}")
        print(f"   Battery: {winner_bid.get('battery', 0)}%")
        print(f"{'='*80}\n")
        
        # Send image to winning device
        self.send_image_to_device(winner, task_id, task_info["image_data"])
        
        # Clean up
        del self.pending_bids[task_id]

    def send_image_to_device(self, device_id, task_id, image_data):
        """Send image to the winning device"""
        if device_id not in self.devices:
            print(f"Device {device_id} not found")
            return
        
        task_message = {
            "type": "task",
            "agent_id": "orchestrator", 
            "task_id": task_id,
            "subtask": "classify",
            "data": {
                "image_base64": image_data,
                "output_path": "/data/local/tmp/received-images"
            }
        }
        
        try:
            task_json = json.dumps(task_message)
            self.devices[device_id]["conn"].send(task_json.encode())
            print(f"Sent image to {device_id} for processing")
        except Exception as e:
            print(f"Failed to send image to {device_id}: {e}")

    def update_scores(self, task, device, U_i, C_i):
        # Placeholder for EdgeMLBalancer scoring
        key = f"{task}-{device}"
        task_logs = [log for log in self.logs[-10:] if log[0] == task and log[1] == device]
        U_avg = np.mean([log[2] for log in task_logs]) if task_logs else U_i
        C_avg = np.mean([log[3] for log in task_logs]) if task_logs else C_i
        score = min(U_i, U_avg) * (1 - C_avg / C_i if C_i > 0 else 1)
        self.scores[key] = {"score": score, "U_avg": U_avg, "C_avg": C_avg}
        self.logs.append((task, device, U_i, C_i))

    def simulate_image_from_device(self, device_id, image_path):
        """Simulate receiving an image from a device for testing purposes"""
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
                image_base64 = base64.b64encode(image_bytes).decode('utf-8')
                
            fake_msg_data = {"image_base64": image_base64}
            self.handle_image_received(device_id, fake_msg_data)
            print(f"Simulated image from {device_id}")
        except Exception as e:
            print(f"Failed to simulate image: {e}")

    def run(self):
        threading.Thread(target=self.accept_connections).start()

if __name__ == "__main__":
    print("=== Orchestrator Starting ===")
    orchestrator = Orchestrator()
    orchestrator.run()
    
    print("Orchestrator is running. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(30)  # Print status every 30 seconds
            
            if orchestrator.devices:
                device_count = len(orchestrator.devices)
                print(f"\n{'='*80}")
                print(f"📡 CONNECTED DEVICES SUMMARY ({device_count} devices)")
                print(f"{'='*80}\n")
                
                for device_id in orchestrator.devices:
                    orchestrator.print_device_metrics(device_id)
                    
    except KeyboardInterrupt:
        print("\n\n{'='*80}")
        print("Orchestrator stopped.")
        print(f"{'='*80}")