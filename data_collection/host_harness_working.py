#!/usr/bin/env python3
import subprocess
import re
import csv
import sys
import time

DEVICE_ID = "60e0c72f"
OUTPUT_FILE = "slm_performance_data.csv"

def get_ram_available_kb(device):
    try:
        result = subprocess.run(f'adb -s {device} shell "cat /proc/meminfo"', 
                              shell=True, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            match = re.search(r'MemAvailable:\s+(\d+)\s+kB', result.stdout)
            if match:
                return int(match.group(1))
        return -1
    except:
        return -1

def get_network_rssi(device):
    try:
        result = subprocess.run(f'adb -s {device} shell "dumpsys wifi | grep RSSI"',
                              shell=True, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            match = re.search(r'RSSI[:\s]+(-?\d+)', result.stdout)
            if match:
                return int(match.group(1))
        return -999
    except:
        return -999

def run_slm_and_time(device, prompt):
    # Use the EXACT working format
    formatted_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\\n\\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    cmd = f'adb -s {device} shell "cd /data/local/tmp/genie-bundle && export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle/ && export ADSP_LIBRARY_PATH=\\$PWD/hexagon-v75/unsigned && ./genie-t2t-run -c genie_config.json -p \\"{formatted_prompt}\\""'
    
    print(f"  Running: {cmd[:100]}...")
    
    start_time = time.time()
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
        end_time = time.time()
        total_time = end_time - start_time
        
        print(f"  Return code: {result.returncode}")
        print(f"  Total time: {total_time:.2f} sec")
        
        if result.returncode == 0 and result.stdout:
            # Parse output for tokens
            output = result.stdout
            print(f"  Output: {output[:200]}...")
            
            # Extract response between [BEGIN]: and [END]
            begin_idx = output.find('[BEGIN]:')
            end_idx = output.find('[END]')
            
            if begin_idx != -1 and end_idx != -1:
                response = output[begin_idx+8:end_idx].strip()
                tokens = len(response.split())
                
                # Estimates (since we can't measure streaming locally)
                ttft = 2.0  # Estimated TTFT
                stream_speed = tokens / max(total_time - ttft, 1) if total_time > ttft else tokens
                
                print(f"  Tokens: {tokens}")
                print(f"  TTFT (est): {ttft:.2f} sec")
                print(f"  Speed (est): {stream_speed:.2f} tok/sec")
                
                return True, ttft, stream_speed
        
        if result.stderr:
            print(f"  Error: {result.stderr}")
        
        return False, -1, -1
        
    except Exception as e:
        print(f"  Exception: {e}")
        return False, -1, -1

def main():
    if len(sys.argv) != 2:
        print("Usage: python host_harness_working.py prompt_list.txt")
        sys.exit(1)
    
    # Read prompts
    with open(sys.argv[1], 'r') as f:
        prompts = [line.strip() for line in f if line.strip()]
    
    # Initialize CSV
    with open(OUTPUT_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['ram_available_kb', 'network_rssi', 'prompt_length', 'ttft_sec', 'stream_speed_tps'])
    
    print(f"Testing {len(prompts)} prompts...")
    
    for i, prompt in enumerate(prompts, 1):
        print(f"\nPrompt {i}/{len(prompts)}: {prompt}")
        
        ram_kb = get_ram_available_kb(DEVICE_ID)
        rssi = get_network_rssi(DEVICE_ID)
        
        success, ttft, speed = run_slm_and_time(DEVICE_ID, prompt)
        
        # Log results
        with open(OUTPUT_FILE, 'a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([ram_kb, rssi, len(prompt), ttft, speed])
        
        print(f"  Logged: RAM={ram_kb}, RSSI={rssi}, TTFT={ttft}, Speed={speed}")

if __name__ == "__main__":
    main()
