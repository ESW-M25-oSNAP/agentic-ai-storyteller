#!/usr/bin/env python3

"""
Simple image sender to test the bidding flow
This simulates an Android device sending an image to the orchestrator
"""

import socket
import json
import base64
import sys
import os

def send_image_to_orchestrator(image_path, orchestrator_host='localhost', orchestrator_port=8080):
    """Send an image to the orchestrator to trigger the bidding process"""
    
    if not os.path.exists(image_path):
        print(f"Error: Image file {image_path} not found")
        return False
    
    try:
        # Read and encode image
        with open(image_path, 'rb') as f:
            image_bytes = f.read()
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
        
        print(f"Image size: {len(image_bytes)} bytes")
        print(f"Base64 size: {len(image_base64)} characters")
        
        # Connect to orchestrator
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((orchestrator_host, orchestrator_port))
        
        # First register as a device (simulate device registration)
        register_msg = {
            "type": "register",
            "agent_id": "test_device",
            "task_id": "",
            "subtask": "",
            "data": {
                "deviceId": "test_device",
                "hasNpu": True,
                "capabilities": ["classify", "generate_story"],
                "metrics": {
                    "battery": 85,
                    "cpu_load": 0.3,
                    "image_model_free": True,
                    "text_model_free": True
                }
            }
        }
        
        sock.send(json.dumps(register_msg).encode())
        print("Sent registration message")
        
        # Wait a moment
        import time
        time.sleep(1)
        
        # Send image message
        image_msg = {
            "type": "image",
            "agent_id": "test_device", 
            "task_id": "",
            "subtask": "",
            "data": {
                "image_base64": image_base64
            }
        }
        
        sock.send(json.dumps(image_msg).encode())
        print("Sent image to orchestrator")
        print("This should trigger the bidding process...")
        
        sock.close()
        return True
        
    except Exception as e:
        print(f"Error sending image: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 send_test_image.py <image_path> [host] [port]")
        print("Example: python3 send_test_image.py test.jpg localhost 8080")
        return
    
    image_path = sys.argv[1]
    host = sys.argv[2] if len(sys.argv) > 2 else 'localhost'
    port = int(sys.argv[3]) if len(sys.argv) > 3 else 8080
    
    print(f"Sending image {image_path} to {host}:{port}")
    
    if send_image_to_orchestrator(image_path, host, port):
        print("Image sent successfully!")
    else:
        print("Failed to send image")

if __name__ == "__main__":
    main()