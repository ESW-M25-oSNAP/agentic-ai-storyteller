#!/usr/bin/env python3

"""
Simple orchestrator runner for Checkpoint 2
Run from networking directory: python3 run_orchestrator.py
"""

import sys
import os

# Add src directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from orchestrator import Orchestrator

def main():
    print("=== Starting Orchestrator for Checkpoint 2 ===")
    print("Listening on 0.0.0.0:8080")
    print("Waiting for Android devices to connect...")
    print("Press Ctrl+C to stop")
    print()
    
    try:
        orchestrator = Orchestrator(host='0.0.0.0', port=8080)
        orchestrator.run()
        
        # Keep running
        while True:
            import time
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nOrchestrator stopped.")

if __name__ == "__main__":
    main()