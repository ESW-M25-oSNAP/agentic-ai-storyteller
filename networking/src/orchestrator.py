import socket
import threading
import json
import base64
import cv2
import numpy as np
import uuid

class Orchestrator:
    def __init__(self, host='0.0.0.0', port=8080):
        self.devices = {}  # {deviceId: {"has_npu", "capabilities", "metrics", "conn"}}
        self.scores = {}   # For EdgeMLBalancer integration
        self.logs = []     # Historical metrics
        self.task_map = {"classify": ["A", "B"], "segment": ["A"]}
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

    def update_scores(self, task, device, U_i, C_i):
        # Placeholder for EdgeMLBalancer scoring
        key = f"{task}-{device}"
        task_logs = [log for log in self.logs[-10:] if log[0] == task and log[1] == device]
        U_avg = np.mean([log[2] for log in task_logs]) if task_logs else U_i
        C_avg = np.mean([log[3] for log in task_logs]) if task_logs else C_i
        score = min(U_i, U_avg) * (1 - C_avg / C_i if C_i > 0 else 1)
        self.scores[key] = {"score": score, "U_avg": U_avg, "C_avg": C_avg}
        self.logs.append((task, device, U_i, C_i))

    def run(self):
        threading.Thread(target=self.accept_connections).start()

if __name__ == "__main__":
    orchestrator = Orchestrator()
    orchestrator.run()