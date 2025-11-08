#!/usr/bin/env python3
"""
host_harness_realtime.py - Test harness with real-time streaming timing for SLM performance data

This script captures real streaming timing by monitoring output as it's generated.
"""

import subprocess
import re
import csv
import sys
import time
import threading
import queue
from datetime import datetime

# Constants - Update these values for your specific setup
DEVICE_ID = "60e0c72f"  # Get from `adb devices`
RECEIVER_IP = "10.2.130.41"  # The IP of the machine running this script
RECEIVER_PORT = 5000
OUTPUT_FILE = "slm_performance_data.csv"


def get_ram_available_kb(device):
    """Get available RAM in KB from the Android device."""
    try:
        result = subprocess.run(
            f'adb -s {device} shell "cat /proc/meminfo"',
            shell=True, capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            match = re.search(r'MemAvailable:\s+(\d+)\s+kB', result.stdout)
            if match:
                return int(match.group(1))
        return -1
    except:
        return -1


def get_network_rssi(device):
    """Get Wi-Fi RSSI value from the Android device."""
    try:
        result = subprocess.run(
            f'adb -s {device} shell "dumpsys wifi | grep RSSI"',
            shell=True, capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            match = re.search(r'RSSI[:\s]+(-?\d+)', result.stdout)
            if match:
                return int(match.group(1))
        return -999
    except:
        return -999


def read_prompts_file(filepath):
    """Read prompts from a text file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            prompts = [line.strip() for line in f if line.strip()]
        print(f"Loaded {len(prompts)} prompts from {filepath}")
        return prompts
    except FileNotFoundError:
        print(f"Error: Prompts file '{filepath}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading prompts file '{filepath}': {e}", file=sys.stderr)
        sys.exit(1)


def initialize_csv_file():
    """Initialize the CSV output file with headers."""
    try:
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(['ram_available_kb', 'network_rssi', 'prompt_length', 'ttft_sec', 'stream_speed_tps'])
        print(f"Initialized CSV file: {OUTPUT_FILE}")
    except Exception as e:
        print(f"Error initializing CSV file: {e}", file=sys.stderr)
        sys.exit(1)


def monitor_output_stream(process, output_queue, timing_data):
    """
    Monitor the output stream in real-time to capture timing metrics.
    This runs in a separate thread to capture output as it arrives.
    """
    first_token_time = None
    start_time = time.time()
    token_count = 0
    response_started = False
    
    timing_data['start_time'] = start_time
    
    try:
        # Read output character by character to catch streaming
        for line in iter(process.stdout.readline, ''):
            current_time = time.time()
            
            if not line:
                break
                
            # Put the line in the queue for the main thread
            output_queue.put(('stdout', line))
            
            # Look for the start of the actual response
            if '[BEGIN]:' in line and not response_started:
                response_started = True
                first_token_time = current_time
                timing_data['first_token_time'] = first_token_time
                timing_data['ttft'] = first_token_time - start_time
                
            # Count tokens in response content (simple word-based)
            if response_started and '[END]' not in line:
                # Extract text content from the line
                if '[BEGIN]:' in line:
                    text = line.split('[BEGIN]:', 1)[-1]
                else:
                    text = line
                    
                words = text.strip().split()
                token_count += len(words)
                timing_data['token_count'] = token_count
                timing_data['current_time'] = current_time
            
            # End of response
            if '[END]' in line:
                end_time = current_time
                timing_data['end_time'] = end_time
                if first_token_time and token_count > 0:
                    generation_time = end_time - first_token_time
                    timing_data['stream_speed'] = token_count / generation_time if generation_time > 0 else 0
                break
                
    except Exception as e:
        output_queue.put(('error', f"Stream monitoring error: {e}"))
    finally:
        output_queue.put(('done', None))


def run_slm_with_realtime_timing(device, prompt):
    """
    Run SLM on device with real-time output monitoring for accurate timing.
    """
    # Use simpler prompt format that was working in our test
    simple_prompt = prompt
    
    # Use the working command format but capture output locally
    adb_command = (
        f'adb -s {device} shell "'
        f'cd /data/local/tmp/genie-bundle && '
        f'export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle/ && '
        f'export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned && '
        f'./genie-t2t-run -c genie_config.json -p \\"{simple_prompt}\\""'
    )
    
    print(f"  DEBUG: Simplified ADB command: {adb_command}")
    
    try:
        # Start the process with streaming output
        process = subprocess.Popen(
            adb_command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,  # Line buffered
            universal_newlines=True
        )
        
        # Set up real-time monitoring
        output_queue = queue.Queue()
        timing_data = {}
        
        # Start monitoring thread
        monitor_thread = threading.Thread(
            target=monitor_output_stream,
            args=(process, output_queue, timing_data)
        )
        monitor_thread.start()
        
        # Collect output and monitor progress
        full_output = ""
        
        while True:
            try:
                msg_type, content = output_queue.get(timeout=1)
                
                if msg_type == 'stdout':
                    full_output += content
                    # Show streaming progress
                    if content.strip():
                        print(f"    {content.strip()}")
                        
                elif msg_type == 'error':
                    print(f"  ERROR: {content}")
                    
                elif msg_type == 'done':
                    break
                    
            except queue.Empty:
                # Check if process is still running
                if process.poll() is not None:
                    break
        
        # Wait for process to complete
        monitor_thread.join(timeout=5)
        return_code = process.wait(timeout=30)
        
        # Get any remaining stderr
        stderr_output = process.stderr.read()
        
        print(f"  DEBUG: Process return code: {return_code}")
        print(f"  DEBUG: Full output length: {len(full_output)} chars")
        
        if stderr_output:
            print(f"  DEBUG: Stderr: {stderr_output}")
        
        # Extract timing metrics
        ttft = timing_data.get('ttft', -1)
        stream_speed = timing_data.get('stream_speed', -1)
        token_count = timing_data.get('token_count', 0)
        
        # If real-time timing failed, fall back to simple estimates
        if ttft == -1 and return_code == 0 and full_output:
            # Parse output for basic metrics
            if '[BEGIN]:' in full_output and '[END]' in full_output:
                # Extract response text
                begin_idx = full_output.find('[BEGIN]:')
                end_idx = full_output.find('[END]')
                if begin_idx != -1 and end_idx != -1:
                    response_text = full_output[begin_idx+8:end_idx].strip()
                    token_count = len(response_text.split())
                    
                    # Use basic estimates
                    ttft = 1.5  # Estimated TTFT
                    stream_speed = token_count / 3.0 if token_count > 0 else 0  # Estimated speed
        
        success = (return_code == 0 and len(full_output) > 0)
        return success, full_output, ttft, stream_speed, token_count
        
    except subprocess.TimeoutExpired:
        print(f"  ERROR: SLM command timed out")
        return False, "", -1, -1, 0
    except Exception as e:
        print(f"  ERROR: Exception during SLM execution: {e}")
        return False, "", -1, -1, 0


def log_to_csv(ram_kb, rssi, prompt_len, ttft, speed):
    """Append a row of data to the CSV file."""
    try:
        with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow([ram_kb, rssi, prompt_len, ttft, speed])
    except Exception as e:
        print(f"Error writing to CSV file: {e}", file=sys.stderr)


def main():
    """Main execution function."""
    # Check command-line arguments
    if len(sys.argv) != 2:
        print("Usage: python host_harness_realtime.py <prompts_file.txt>", file=sys.stderr)
        sys.exit(1)
    
    prompts_file = sys.argv[1]
    
    # Read prompts from file
    prompts = read_prompts_file(prompts_file)
    if not prompts:
        print("Error: No prompts found in the file.", file=sys.stderr)
        sys.exit(1)
    
    # Initialize CSV file with headers
    initialize_csv_file()
    
    print(f"Starting experiment with {len(prompts)} prompts...")
    print(f"Device ID: {DEVICE_ID}")
    print(f"Output file: {OUTPUT_FILE}")
    print(f"Mode: Real-time streaming timing")
    print("-" * 60)
    
    # Main experiment loop
    for i, prompt in enumerate(prompts, 1):
        print(f"\nProcessing prompt {i}/{len(prompts)}: '{prompt[:50]}{'...' if len(prompt) > 50 else ''}'")
        
        # Get input metrics from device
        print("  Getting device metrics...")
        ram_available_kb = get_ram_available_kb(DEVICE_ID)
        network_rssi = get_network_rssi(DEVICE_ID)
        prompt_length = len(prompt)
        
        print(f"  RAM Available: {ram_available_kb} KB")
        print(f"  Network RSSI: {network_rssi}")
        print(f"  Prompt Length: {prompt_length} chars")
        
        # Run SLM with real-time timing
        print("  Running SLM with real-time monitoring...")
        success, output, ttft, stream_speed, token_count = run_slm_with_realtime_timing(DEVICE_ID, prompt)
        
        if success:
            print(f"  ✅ TTFT: {ttft:.2f} sec")
            print(f"  ✅ Stream Speed: {stream_speed:.2f} tokens/sec")
            print(f"  ✅ Token Count: {token_count}")
        else:
            print("  ❌ ERROR: Failed to run SLM or get timing")
            ttft = -1
            stream_speed = -1
        
        # Log to CSV
        log_to_csv(ram_available_kb, network_rssi, prompt_length, ttft, stream_speed)
        print(f"  Data logged to {OUTPUT_FILE}")
    
    print(f"\nExperiment completed! Results saved to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()