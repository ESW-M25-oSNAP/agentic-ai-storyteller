import socket
import threading
import json
import base64
import cv2
import numpy as np
import uuid
import time

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

    def accept_connections(self):
        while True:
            conn, addr = self.server.accept()
            print(f"New connection from {addr}")
            threading.Thread(target=self.handle_client, args=(conn,)).start()

    def handle_client(self, conn):
        while True:
            try:
                data = conn.recv(4096).decode()
                if not data:
                    print("Connection closed")
                    break
                msg = json.loads(data)
                device_id = msg.get("agent_id") or msg["data"].get("deviceId")
                if msg["type"] == "register":
                    self.devices[device_id] = {
                        "has_npu": msg["data"]["hasNpu"],
                        "capabilities": msg["data"]["capabilities"],
                        "metrics": msg["data"]["metrics"],
                        "conn": conn
                    }
                    print(f"Registered {device_id}")
                elif msg["type"] == "status":
                    self.devices[device_id]["metrics"] = msg["data"]["metrics"]
                    print(f"Updated status for {device_id}: {msg['data']['metrics']}")
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
                    # For EdgeMLBalancer: Update scores with confidence
                    task = msg["subtask"]
                    confidence = msg["data"].get("confidence", 0.5)
                    cpu_load = self.devices[device_id]["metrics"].get("cpu_load", 0.5)
                    self.update_scores(task, device_id, cpu_load, confidence)
                elif msg["type"] == "heartbeat":
                    print(f"Heartbeat from {device_id}")
            except Exception as e:
                print(f"Error in handle_client: {e}")
                break
        conn.close()
        # Remove device from registry
        for dev_id in list(self.devices.keys()):
            if self.devices[dev_id]["conn"] == conn:
                del self.devices[dev_id]
                print(f"Removed {dev_id} from registry")

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
            print(f"Received bid from {device_id} for task {task_id}: CPU load = {bid_data.get('cpu_load', 'N/A')}")

    def evaluate_bids(self, task_id):
        """Evaluate bids and select winning device based on lowest CPU load"""
        if task_id not in self.pending_bids:
            print(f"Task {task_id} not found in pending bids")
            return
        
        task_info = self.pending_bids[task_id]
        bids = task_info["bids"]
        
        if not bids:
            print(f"No bids received for task {task_id}")
            del self.pending_bids[task_id]
            return
        
        # Select device with lowest CPU load
        winner = min(bids.keys(), key=lambda d: bids[d].get("cpu_load", 1.0))
        winner_bid = bids[winner]
        
        print(f"Task {task_id} assigned to {winner} (CPU load: {winner_bid.get('cpu_load', 'N/A')})")
        
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
                "output_path": "/data/local/tmp/received-image"
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
            time.sleep(1)
            # Print connected devices periodically
            if orchestrator.devices:
                device_count = len(orchestrator.devices)
                if device_count > 0:
                    print(f"Connected devices: {device_count}")
                    for device_id, device_info in orchestrator.devices.items():
                        metrics = device_info.get('metrics', {})
                        cpu_load = metrics.get('cpu_load', 'N/A')
                        battery = metrics.get('battery', 'N/A')
                        print(f"  {device_id}: CPU={cpu_load}, Battery={battery}")
            time.sleep(30)  # Print status every 30 seconds
    except KeyboardInterrupt:
        print("\nOrchestrator stopped.")