#!/usr/bin/env python3
"""
host_harness_debug.py - Enhanced debug version of test harness for SLM performance data collection
"""

import subprocess
import re
import csv
import sys
import time
import signal
import os

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
    print "DEBUG: AWK script started at", start > "/dev/stderr"
}
{
    if (first == 0 && length($0) > 0) {
        first = systime()
        print "TTFT:", first - start, "sec" > "/dev/stderr"
        print "DEBUG: First token received:", $0 > "/dev/stderr"
    }
    tokens++
    printf "%s ", $0; fflush(stdout)
    if (tokens % 10 == 0) {
        print "DEBUG: Received", tokens, "tokens so far" > "/dev/stderr"
    }
}
END {
    end_time = systime()
    total = end_time - first
    print "DEBUG: AWK script ending. Total tokens:", tokens, "Time elapsed:", total > "/dev/stderr"
    if (tokens > 1 && total > 0)
        print "\\nAverage generation speed:", tokens / total, "tokens/sec" > "/dev/stderr"
    else
        print "\\nNot enough tokens to compute speed." > "/dev/stderr"
}'
"""

def debug_print(message):
    """Print debug message with timestamp"""
    timestamp = time.strftime("%H:%M:%S", time.localtime())
    print(f"[{timestamp}] DEBUG: {message}")

def get_ram_available_kb(device):
    """Get available RAM in KB from the Android device."""
    debug_print(f"Getting RAM info from device {device}")
    try:
        result = subprocess.run(
            f'adb -s {device} shell "cat /proc/meminfo"',
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        debug_print(f"RAM command exit code: {result.returncode}")
        if result.returncode == 0:
            # Look for MemAvailable line in the output
            match = re.search(r'MemAvailable:\s+(\d+)\s+kB', result.stdout)
            if match:
                ram_kb = int(match.group(1))
                debug_print(f"Found RAM: {ram_kb} KB")
                return ram_kb
        
        debug_print(f"Could not parse RAM info. stdout: {result.stdout[:200]}")
        return -1
        
    except Exception as e:
        debug_print(f"Error getting RAM info: {e}")
        return -1

def get_network_rssi(device):
    """Get Wi-Fi RSSI value from the Android device."""
    debug_print(f"Getting RSSI info from device {device}")
    try:
        result = subprocess.run(
            f'adb -s {device} shell "dumpsys wifi | grep RSSI"',
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        debug_print(f"RSSI command exit code: {result.returncode}")
        if result.returncode == 0:
            # Look for RSSI value in the output (typically negative number)
            match = re.search(r'RSSI[:\s]+(-?\d+)', result.stdout)
            if match:
                rssi = int(match.group(1))
                debug_print(f"Found RSSI: {rssi}")
                return rssi
        
        debug_print(f"Could not parse RSSI info. stdout: {result.stdout[:200]}")
        return -999
        
    except Exception as e:
        debug_print(f"Error getting RSSI info: {e}")
        return -999

def read_prompts_file(filepath):
    """Read prompts from a text file."""
    debug_print(f"Reading prompts from {filepath}")
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            prompts = [line.strip() for line in f if line.strip()]
        debug_print(f"Loaded {len(prompts)} prompts")
        return prompts
    except FileNotFoundError:
        print(f"Error: Prompts file '{filepath}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading prompts file '{filepath}': {e}", file=sys.stderr)
        sys.exit(1)

def initialize_csv_file():
    """Initialize the CSV output file with headers."""
    debug_print(f"Initializing CSV file: {OUTPUT_FILE}")
    try:
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(['ram_available_kb', 'network_rssi', 'prompt_length', 'ttft_sec', 'stream_speed_tps'])
        debug_print("CSV file initialized successfully")
    except Exception as e:
        print(f"Error initializing CSV file: {e}", file=sys.stderr)
        sys.exit(1)

def parse_metrics_from_stderr(stderr_output):
    """Parse TTFT and stream speed metrics from the receiver's stderr output."""
    debug_print(f"Parsing metrics from stderr output ({len(stderr_output)} chars)")
    debug_print(f"Stderr content: {stderr_output}")
    
    ttft = -1
    stream_speed = -1
    
    if stderr_output:
        # Parse TTFT (Time To First Token)
        ttft_match = re.search(r"TTFT:\s*(\d+\.?\d*)", stderr_output)
        if ttft_match:
            ttft = float(ttft_match.group(1))
            debug_print(f"Found TTFT: {ttft}")
        else:
            debug_print("TTFT not found in stderr output")
        
        # Parse stream speed
        speed_match = re.search(r"Average generation speed:\s*(\d+\.?\d*)", stderr_output)
        if speed_match:
            stream_speed = float(speed_match.group(1))
            debug_print(f"Found stream speed: {stream_speed}")
        else:
            debug_print("Stream speed not found in stderr output")
    
    return ttft, stream_speed

def log_to_csv(ram_kb, rssi, prompt_len, ttft, speed):
    """Append a row of data to the CSV file."""
    debug_print(f"Logging to CSV: RAM={ram_kb}, RSSI={rssi}, PromptLen={prompt_len}, TTFT={ttft}, Speed={speed}")
    try:
        with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow([ram_kb, rssi, prompt_len, ttft, speed])
        debug_print("Data logged successfully")
    except Exception as e:
        print(f"Error writing to CSV file: {e}", file=sys.stderr)

def check_device_connectivity():
    """Check if the device is connected and responsive."""
    debug_print("Checking device connectivity...")
    try:
        result = subprocess.run(f'adb -s {DEVICE_ID} shell "echo test"', shell=True, capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and "test" in result.stdout:
            debug_print("Device is connected and responsive")
            return True
        else:
            debug_print(f"Device check failed. Return code: {result.returncode}, stdout: {result.stdout}")
            return False
    except Exception as e:
        debug_print(f"Device connectivity check failed: {e}")
        return False

def check_port_availability():
    """Check if the receiver port is available."""
    debug_print(f"Checking if port {RECEIVER_PORT} is available...")
    try:
        result = subprocess.run(f'netstat -ln | grep ":{RECEIVER_PORT}"', shell=True, capture_output=True, text=True)
        if result.stdout:
            debug_print(f"Port {RECEIVER_PORT} appears to be in use: {result.stdout.strip()}")
            return False
        else:
            debug_print(f"Port {RECEIVER_PORT} appears to be available")
            return True
    except Exception as e:
        debug_print(f"Port check failed: {e}")
        return True  # Assume available if check fails

def main():
    """Main execution function."""
    debug_print("Starting host_harness_debug.py")
    
    # Check command-line arguments
    if len(sys.argv) != 2:
        print("Usage: python host_harness_debug.py <prompts_file.txt>", file=sys.stderr)
        sys.exit(1)
    
    prompts_file = sys.argv[1]
    debug_print(f"Using prompts file: {prompts_file}")
    
    # Pre-flight checks
    if not check_device_connectivity():
        print("Error: Device is not connected or not responsive", file=sys.stderr)
        sys.exit(1)
    
    if not check_port_availability():
        print(f"Warning: Port {RECEIVER_PORT} may be in use", file=sys.stderr)
    
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
        print(f"\\nProcessing prompt {i}/{len(prompts)}...")
        debug_print(f"Prompt: {prompt[:100]}...")  # Show first 100 chars
        
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
        debug_print(f"Receiver command: {receiver_command}")
        
        receiver_proc = None
        try:
            receiver_proc = subprocess.Popen(
                receiver_command,
                shell=True,
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True
            )
            debug_print(f"Receiver process started with PID: {receiver_proc.pid}")
            
            # Give the nc listener time to start
            debug_print("Waiting for receiver to be ready...")
            time.sleep(2)
            
            # Trigger SLM process on device
            print("  Triggering SLM process on device...")
            formatted_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\\n\\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
            debug_print(f"Formatted prompt length: {len(formatted_prompt)}")
            
            adb_command = (
                f'adb -s {DEVICE_ID} shell "'
                f'export LD_LIBRARY_PATH=$PWD; '
                f'export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned; '
                f'cd /data/local/tmp/genie-bundle; '
                f'./genie-t2t-run -c genie_config.json -p \\"{formatted_prompt}\\" | '
                f'./busybox-arm64 nc {RECEIVER_IP} {RECEIVER_PORT}"'
            )
            debug_print(f"ADB command: {adb_command}")
            
            print("  Executing ADB command...")
            debug_print("Starting ADB subprocess...")
            
            # Execute adb command (blocking)
            adb_result = subprocess.run(
                adb_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            debug_print(f"ADB command completed with return code: {adb_result.returncode}")
            debug_print(f"ADB stdout: {adb_result.stdout}")
            debug_print(f"ADB stderr: {adb_result.stderr}")
            
            # Get metrics from receiver process
            print("  Collecting metrics from receiver...")
            debug_print("Communicating with receiver process...")
            
            # Wait a moment for receiver to finish processing
            time.sleep(1)
            
            # Check if receiver process is still running
            if receiver_proc.poll() is None:
                debug_print("Receiver process still running, terminating...")
                receiver_proc.terminate()
                time.sleep(1)
                if receiver_proc.poll() is None:
                    debug_print("Force killing receiver process...")
                    receiver_proc.kill()
            
            stdout_output, stderr_output = receiver_proc.communicate()
            
            debug_print(f"Receiver stdout: {stdout_output}")
            debug_print(f"Receiver stderr: {stderr_output}")
            
            # Parse metrics
            ttft, stream_speed = parse_metrics_from_stderr(stderr_output)
            
            print(f"  TTFT: {ttft} sec")
            print(f"  Stream Speed: {stream_speed} tokens/sec")
            
            # Log to CSV
            log_to_csv(ram_available_kb, network_rssi, prompt_length, ttft, stream_speed)
            print(f"  Data logged to {OUTPUT_FILE}")
            
        except subprocess.TimeoutExpired:
            print(f"  Error: ADB command timed out for prompt {i}", file=sys.stderr)
            debug_print("ADB command timed out")
            # Kill the receiver process if it's still running
            if receiver_proc and receiver_proc.poll() is None:
                debug_print("Killing receiver process due to timeout")
                receiver_proc.kill()
            # Log error data
            log_to_csv(ram_available_kb, network_rssi, prompt_length, -1, -1)
            
        except Exception as e:
            print(f"  Error processing prompt {i}: {e}", file=sys.stderr)
            debug_print(f"Exception in main loop: {e}")
            # Kill the receiver process if it's still running
            if receiver_proc and receiver_proc.poll() is None:
                debug_print("Killing receiver process due to exception")
                receiver_proc.kill()
            # Log error data
            log_to_csv(ram_available_kb, network_rssi, prompt_length, -1, -1)
        
        # Small delay between prompts
        debug_print("Waiting before next prompt...")
        time.sleep(1)
    
    print(f"\\nExperiment completed! Results saved to {OUTPUT_FILE}")
    debug_print("Script completed successfully")

if __name__ == "__main__":
    main()
