#!/usr/bin/env python3

"""
Test script for Checkpoint 2: Image transfer and bidding process
Run this from the networking directory: python3 test_checkpoint2.py <image_path>
"""

import sys
import os
import time
import threading

# Add src directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from orchestrator import Orchestrator

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 test_checkpoint2.py <path_to_test_image>")
        print("Example: python3 test_checkpoint2.py /path/to/test_image.jpg")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"Error: Image file {image_path} not found")
        sys.exit(1)
    
    print("=== Checkpoint 2 Test ===")
    print("This test will:")
    print("1. Start the orchestrator")
    print("2. Wait for Android devices to connect")
    print("3. Simulate receiving an image from a device")
    print("4. Initiate bidding process")
    print("5. Send image to winning device")
    print()
    
    # Start orchestrator
    print("Starting orchestrator on port 8080...")
    orchestrator = Orchestrator(host='0.0.0.0', port=8080)
    orchestrator.run()
    
    print("Orchestrator started. Waiting for devices to connect...")
    print("Make sure your Android devices are running the agent and connected.")
    print("Press Enter when ready to start the test...")
    input()
    
    # Check connected devices
    print(f"Connected devices: {list(orchestrator.devices.keys())}")
    if not orchestrator.devices:
        print("No devices connected. Make sure Android agents are running and connected.")
        return
    
    # Simulate image from first connected device
    first_device = list(orchestrator.devices.keys())[0]
    print(f"Simulating image received from device: {first_device}")
    print(f"Image path: {image_path}")
    
    orchestrator.simulate_image_from_device(first_device, image_path)
    
    print("\nBidding process initiated. Check logs above for:")
    print("- Bid requests sent to devices")
    print("- Bids received from devices") 
    print("- Winner selection based on lowest CPU load")
    print("- Image sent to winning device")
    print("\nTest will continue running. Press Ctrl+C to stop.")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nTest stopped.")

if __name__ == "__main__":
    main()