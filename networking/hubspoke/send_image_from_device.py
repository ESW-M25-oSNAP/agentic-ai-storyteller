#!/usr/bin/env python3
"""
Script to simulate sending an image from Device A to the orchestrator.
This is used for testing Checkpoint 2.
"""

import socket
import json
import base64
import sys
import os

def send_image(device_id, image_path, orchestrator_ip="localhost", orchestrator_port=8080):
    """
    Send an image to the orchestrator as if it came from a specific device.
    
    Args:
        device_id: The device ID (e.g., "A" or "B")
        image_path: Path to the image file on the local system
        orchestrator_ip: IP address of the orchestrator
        orchestrator_port: Port of the orchestrator
    """
    
    # Check if image exists
    if not os.path.exists(image_path):
        print(f"Error: Image file not found: {image_path}")
        return False
    
    # Read and encode image
    print(f"Reading image from: {image_path}")
    with open(image_path, "rb") as f:
        image_bytes = f.read()
        image_base64 = base64.b64encode(image_bytes).decode('utf-8')
    
    print(f"Image size: {len(image_bytes)} bytes")
    print(f"Encoded size: {len(image_base64)} characters")
    
    # Create message
    message = {
        "type": "image",
        "agent_id": device_id,
        "task_id": "",
        "subtask": "",
        "data": {
            "image_base64": image_base64
        }
    }
    
    try:
        # Connect to orchestrator
        print(f"Connecting to orchestrator at {orchestrator_ip}:{orchestrator_port}...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((orchestrator_ip, orchestrator_port))
        
        # Send message
        message_json = json.dumps(message)
        sock.send(message_json.encode())
        print(f"✓ Image sent from Device {device_id}!")
        print(f"  Message size: {len(message_json)} bytes")
        
        sock.close()
        return True
        
    except ConnectionRefusedError:
        print(f"Error: Could not connect to orchestrator at {orchestrator_ip}:{orchestrator_port}")
        print("Make sure the orchestrator is running.")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_image_from_device.py <device_id> <image_path> [orchestrator_ip] [port]")
        print()
        print("Examples:")
        print("  python3 send_image_from_device.py A test.jpg")
        print("  python3 send_image_from_device.py A test.jpg 192.168.1.100 8080")
        print()
        print("This simulates Device A sending an image to the orchestrator.")
        sys.exit(1)
    
    device_id = sys.argv[1]
    image_path = sys.argv[2]
    orchestrator_ip = sys.argv[3] if len(sys.argv) > 3 else "localhost"
    orchestrator_port = int(sys.argv[4]) if len(sys.argv) > 4 else 8080
    
    success = send_image(device_id, image_path, orchestrator_ip, orchestrator_port)
    sys.exit(0 if success else 1)
