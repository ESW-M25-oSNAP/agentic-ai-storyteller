#!/usr/bin/env python3
"""
host_harness.py - Test harness for collecting performance data from SLM running on Android device (QDK)

This script:
1. Launches a receiver process (nc | awk) on the laptop to listen for tokens
2. Triggers the SLM process on the device via adb, streaming tokens to the receiver
3. Captures metrics (TTFT, Stream Speed) calculated by the receiver process
4. Logs all data to a CSV file

Usage: python host_harness.py <prompts_file.txt>
"""

import subprocess
import re
import csv
import sys
import time

# Constants - Update these values for your specific setup
DEVICE_ID = "60e0c72f"  # Get from `adb devices`
RECEIVER_IP = "10.2.130.41"  # The IP of the machine running this script
RECEIVER_PORT = 5000
OUTPUT_FILE = "slm_performance_data.csv"

# This is the awk script that will be run by the receiver process
AWK_COMMAND = """
awk -v RS=' ' '
BEGIN {
    start = systime()
    first = 0
    tokens = 0
}
{
    if (first == 0 && length($0) > 0) {
        first = systime()
        print "TTFT:", first - start, "sec" > "/dev/stderr"
    }
    tokens++
    printf "%s ", $0; fflush(stdout)
}
END {
    total = systime() - first
    if (tokens > 1 && total > 0)
        print "\\nAverage generation speed:", tokens / total, "tokens/sec" > "/dev/stderr"
    else
        print "\\nNot enough tokens to compute speed." > "/dev/stderr"
}'
"""


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


def parse_metrics_from_stderr(stderr_output):
    """
    Parse TTFT and stream speed metrics from the receiver's stderr output.
    
    Args:
        stderr_output (str): The stderr output from the receiver process
        
    Returns:
        tuple: (ttft, stream_speed) - both as floats, -1 if not found
    """
    ttft = -1
    stream_speed = -1
    
    if stderr_output:
        print(f"DEBUG: Receiver stderr output: {repr(stderr_output)}")
        # Parse TTFT (Time To First Token)
        ttft_match = re.search(r"TTFT:\s*(\d+\.?\d*)", stderr_output)
        if ttft_match:
            ttft = float(ttft_match.group(1))
        
        # Parse stream speed
        speed_match = re.search(r"Average generation speed:\s*(\d+\.?\d*)", stderr_output)
        if speed_match:
            stream_speed = float(speed_match.group(1))
    
    return ttft, stream_speed


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
    print(f"Receiver IP: {RECEIVER_IP}:{RECEIVER_PORT}")
    print(f"Output file: {OUTPUT_FILE}")
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
        
        # Start receiver process
        print("  Starting receiver process...")
        receiver_command = f"nc -l -p {RECEIVER_PORT} | {AWK_COMMAND}"
        print(f"  DEBUG: Receiver command: {receiver_command}")
        
        try:
            receiver_proc = subprocess.Popen(
                receiver_command,
                shell=True,
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True
            )
            
            # Give the nc listener time to start
            print("  Waiting for receiver to start...")
            time.sleep(2)
            
            # Trigger SLM process on device - Updated command format
            print("  Triggering SLM process on device...")
            formatted_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\\n\\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
            
            # Updated adb command to match your working format
            adb_command = (
                f'adb -s {DEVICE_ID} shell "'
                f'cd /data/local/tmp/genie-bundle && '
                f'export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle/ && '
                f'export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned && '
                f'./genie-t2t-run -c genie_config.json -p \\"{formatted_prompt}\\" | '
                f'./busybox-arm64 nc {RECEIVER_IP} {RECEIVER_PORT}"'
            )
            
            print(f"  DEBUG: ADB command: {adb_command}")
            
            # Execute adb command (blocking)
            print("  Executing ADB command...")
            adb_result = subprocess.run(
                adb_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            print(f"  DEBUG: ADB return code: {adb_result.returncode}")
            if adb_result.stdout:
                print(f"  DEBUG: ADB stdout: {repr(adb_result.stdout)}")
            if adb_result.stderr:
                print(f"  DEBUG: ADB stderr: {repr(adb_result.stderr)}")
            
            # If ADB command failed, show the error and continue
            if adb_result.returncode != 0:
                print(f"  ERROR: ADB command failed with return code {adb_result.returncode}")
                if adb_result.stderr:
                    print(f"  ERROR MESSAGE: {adb_result.stderr}")
                # Kill the receiver process and log error data
                if receiver_proc.poll() is None:
                    receiver_proc.terminate()
                log_to_csv(ram_available_kb, network_rssi, prompt_length, -1, -1)
                continue
            
            # Get metrics from receiver process
            print("  Collecting metrics from receiver...")
            stdout_output, stderr_output = receiver_proc.communicate(timeout=10)
            
            print(f"  DEBUG: Receiver stdout: {repr(stdout_output)}")
            print(f"  DEBUG: Receiver stderr: {repr(stderr_output)}")
            
            # Also print the actual SLM output (tokens)
            if stdout_output:
                print(f"  SLM OUTPUT: {stdout_output}")
            
            # Parse metrics
            ttft, stream_speed = parse_metrics_from_stderr(stderr_output)
            
            print(f"  TTFT: {ttft} sec")
            print(f"  Stream Speed: {stream_speed} tokens/sec")
            
            # Log to CSV
            log_to_csv(ram_available_kb, network_rssi, prompt_length, ttft, stream_speed)
            print(f"  Data logged to {OUTPUT_FILE}")
            
        except subprocess.TimeoutExpired:
            print(f"  Error: ADB command timed out for prompt {i}", file=sys.stderr)
            # Kill the receiver process if it's still running
            if receiver_proc.poll() is None:
                receiver_proc.terminate()
            # Log error data
            log_to_csv(ram_available_kb, network_rssi, prompt_length, -1, -1)
            
        except Exception as e:
            print(f"  Error processing prompt {i}: {e}", file=sys.stderr)
            # Kill the receiver process if it's still running
            if 'receiver_proc' in locals() and receiver_proc.poll() is None:
                receiver_proc.terminate()
            # Log error data
            log_to_csv(ram_available_kb, network_rssi, prompt_length, -1, -1)
    
    print(f"\nExperiment completed! Results saved to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()