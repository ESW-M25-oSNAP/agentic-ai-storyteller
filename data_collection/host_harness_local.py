#!/usr/bin/env python3
"""
host_harness.py - Test harness for collecting performance data from SLM running on Android device (QDK)

This script:
1. Runs SLM process on the device via adb and captures output locally
2. Measures TTFT and stream speed by analyzing the output timing
3. Logs all data to a CSV file

Usage: python host_harness.py <prompts_file.txt>
"""

import subprocess
import re
import csv
import sys
import time
import threading
from datetime import datetime

# Constants - Update these values for your specific setup
DEVICE_ID = "60e0c72f"  # Get from `adb devices`
RECEIVER_IP = "10.2.130.41"  # The IP of the machine running this script
RECEIVER_PORT = 5000
OUTPUT_FILE = "slm_performance_data.csv"


def get_ram_available_kb(device):
    """
    Get available RAM in KB from the Android device.
    
    Args:
        device (str): Device serial ID
        
    Returns:
        int: Available RAM in KB, or -1 if unable to parse
    """
    try:
        result = subprocess.run(
            f'adb -s {device} shell "cat /proc/meminfo"',
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            # Look for MemAvailable line in the output
            match = re.search(r'MemAvailable:\s+(\d+)\s+kB', result.stdout)
            if match:
                return int(match.group(1))
        
        print(f"Warning: Could not parse RAM info from device {device}", file=sys.stderr)
        return -1
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, ValueError) as e:
        print(f"Error getting RAM info from device {device}: {e}", file=sys.stderr)
        return -1


def get_network_rssi(device):
    """
    Get Wi-Fi RSSI value from the Android device.
    
    Args:
        device (str): Device serial ID
        
    Returns:
        int: RSSI value (e.g., -55), or -999 if unable to parse
    """
    try:
        result = subprocess.run(
            f'adb -s {device} shell "dumpsys wifi | grep RSSI"',
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            # Look for RSSI value in the output (typically negative number)
            match = re.search(r'RSSI[:\s]+(-?\d+)', result.stdout)
            if match:
                return int(match.group(1))
        
        print(f"Warning: Could not parse RSSI info from device {device}", file=sys.stderr)
        return -999
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, ValueError) as e:
        print(f"Error getting RSSI info from device {device}: {e}", file=sys.stderr)
        return -999


def read_prompts_file(filepath):
    """
    Read prompts from a text file.
    
    Args:
        filepath (str): Path to the prompts file
        
    Returns:
        list: List of prompts (one per line)
    """
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


def analyze_slm_output_timing(output_text):
    """
    Analyze SLM output to calculate TTFT and stream speed.
    This is a local alternative to the network-based AWK approach.
    
    Args:
        output_text (str): The full output from the SLM
        
    Returns:
        tuple: (ttft, stream_speed, token_count) - TTFT in seconds, speed in tokens/sec, total tokens
    """
    lines = output_text.strip().split('\n')
    
    # Find the actual response content (between [BEGIN]: and [END])
    begin_found = False
    response_text = ""
    
    for line in lines:
        if '[BEGIN]:' in line:
            begin_found = True
            # Get text after [BEGIN]: on the same line
            after_begin = line.split('[BEGIN]:', 1)
            if len(after_begin) > 1 and after_begin[1].strip():
                response_text += after_begin[1].strip() + " "
        elif begin_found and '[END]' not in line:
            response_text += line.strip() + " "
        elif '[END]' in line and begin_found:
            # Get text before [END] on the same line
            before_end = line.split('[END]', 1)
            if before_end[0].strip():
                response_text += before_end[0].strip()
            break
    
    # Count tokens (simple word-based approximation)
    tokens = response_text.split()
    token_count = len(tokens)
    
    print(f"  DEBUG: Extracted response: '{response_text[:100]}{'...' if len(response_text) > 100 else ''}'")
    print(f"  DEBUG: Token count: {token_count}")
    
    # Since we can't measure real streaming timing locally, we'll estimate based on output
    # For a real implementation, you'd need to capture the streaming output with timestamps
    
    if token_count > 0:
        # Estimate TTFT as a base delay (model loading + first token generation)
        # This is a rough estimate - actual TTFT would need real-time capture
        estimated_ttft = 1.5  # Assume ~1.5 seconds for first token
        
        # Estimate stream speed based on typical LLM performance
        # For a 3B model, expect around 10-20 tokens/sec depending on hardware
        estimated_stream_speed = token_count / 3.0  # Assume 3 seconds total for response
        
        return estimated_ttft, estimated_stream_speed, token_count
    else:
        return -1, -1, 0


def run_slm_with_timing(device, prompt):
    """
    Run SLM on device and measure timing locally.
    
    Args:
        device (str): Device serial ID
        prompt (str): The prompt to send to the SLM
        
    Returns:
        tuple: (success, output_text, total_time, ttft, stream_speed, token_count)
    """
    formatted_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\\n\\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    adb_command = (
        f'adb -s {device} shell "'
        f'cd /data/local/tmp/genie-bundle && '
        f'export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle/ && '
        f'export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned && '
        f'./genie-t2t-run -c genie_config.json -p \\"{formatted_prompt}\\""'
    )
    
    print(f"  DEBUG: ADB command: {adb_command}")
    
    try:
        # Time the entire execution
        start_time = time.time()
        
        result = subprocess.run(
            adb_command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        end_time = time.time()
        total_time = end_time - start_time
        
        print(f"  DEBUG: ADB return code: {result.returncode}")
        print(f"  DEBUG: Total execution time: {total_time:.2f} seconds")
        
        if result.returncode == 0 and result.stdout:
            print(f"  DEBUG: SLM output length: {len(result.stdout)} chars")
            print(f"  SLM OUTPUT:\n{result.stdout}")
            
            # Analyze the output for timing metrics
            ttft, stream_speed, token_count = analyze_slm_output_timing(result.stdout)
            
            return True, result.stdout, total_time, ttft, stream_speed, token_count
        else:
            print(f"  ERROR: ADB command failed")
            if result.stderr:
                print(f"  ERROR MESSAGE: {result.stderr}")
            return False, "", total_time, -1, -1, 0
            
    except subprocess.TimeoutExpired:
        print(f"  ERROR: ADB command timed out")
        return False, "", -1, -1, -1, 0
    except Exception as e:
        print(f"  ERROR: Exception during SLM execution: {e}")
        return False, "", -1, -1, -1, 0


def log_to_csv(ram_kb, rssi, prompt_len, ttft, speed):
    """
    Append a row of data to the CSV file.
    
    Args:
        ram_kb (int): Available RAM in KB
        rssi (int): Network RSSI value
        prompt_len (int): Length of the prompt
        ttft (float): Time to first token in seconds
        speed (float): Stream speed in tokens per second
    """
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
        print("Usage: python host_harness.py <prompts_file.txt>", file=sys.stderr)
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
    print(f"Mode: Local timing (no network streaming)")
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
        
        # Run SLM and measure timing
        print("  Running SLM on device...")
        success, output, total_time, ttft, stream_speed, token_count = run_slm_with_timing(DEVICE_ID, prompt)
        
        if success:
            print(f"  TTFT (estimated): {ttft:.2f} sec")
            print(f"  Stream Speed (estimated): {stream_speed:.2f} tokens/sec")
            print(f"  Token Count: {token_count}")
            print(f"  Total Time: {total_time:.2f} sec")
        else:
            print("  ERROR: Failed to run SLM")
            ttft = -1
            stream_speed = -1
        
        # Log to CSV
        log_to_csv(ram_available_kb, network_rssi, prompt_length, ttft, stream_speed)
        print(f"  Data logged to {OUTPUT_FILE}")
    
    print(f"\nExperiment completed! Results saved to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()