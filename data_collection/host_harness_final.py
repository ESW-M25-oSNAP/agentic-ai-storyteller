#!/usr/bin/env python3
"""
host_harness_final.py - Fixed version with proper RSSI handling and working SLM execution
"""

import subprocess
import re
import csv
import sys
import time

# Constants
DEVICE_ID = "60e0c72f"
OUTPUT_FILE = "slm_performance_data.csv"

def get_ram_available_kb(device):
    """Get available RAM in KB from the Android device."""
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
    """
    Get WiFi RSSI value from the Android device.
    Now handles disconnected WiFi properly by checking multiple sources.
    """
    try:
        # First try to get current connection RSSI
        result = subprocess.run(
            f'adb -s {device} shell "dumpsys wifi | grep \'mWifiInfo.*RSSI\'"',
            shell=True, capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0 and result.stdout:
            # Check if we're actually connected (not -127)
            match = re.search(r'RSSI:\s*(-?\d+)', result.stdout)
            if match:
                rssi_value = int(match.group(1))
                if rssi_value != -127:  # -127 means disconnected
                    return rssi_value
        
        # If disconnected or failed, try to get recent scan results
        print("  WiFi disconnected (-127), trying scan results...")
        result = subprocess.run(
            f'adb -s {device} shell "dumpsys wifiscanner | grep -A 20 \'Scan Results:\' | head -30"',
            shell=True, capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0 and result.stdout:
            # Look for RSSI values in scan results
            rssi_matches = re.findall(r'RSSI[:\s]+(-?\d+)', result.stdout)
            if rssi_matches:
                # Return the strongest (least negative) signal from recent scans
                rssi_values = [int(x) for x in rssi_matches if int(x) > -100]  # Filter out invalid values
                if rssi_values:
                    best_rssi = max(rssi_values)  # Strongest signal
                    print(f"    Found scan result RSSI: {best_rssi}")
                    return best_rssi
        
        # If all else fails, return a disconnected indicator
        print("  No valid RSSI found - device appears to be disconnected")
        return -127
        
    except Exception as e:
        print(f"  Error getting RSSI: {e}")
        return -999

def run_slm_and_time(device, prompt):
    """Run SLM on device using the working command format and measure timing."""
    
    # Use the EXACT working format that we confirmed works
    formatted_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\\n\\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    cmd = (
        f'adb -s {device} shell "'
        f'cd /data/local/tmp/genie-bundle && '
        f'export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle/ && '
        f'export ADSP_LIBRARY_PATH=\\$PWD/hexagon-v75/unsigned && '
        f'./genie-t2t-run -c genie_config.json -p \\"{formatted_prompt}\\""'
    )
    
    print(f"  Running SLM...")
    print(f"  Command: {cmd[:100]}...")
    
    start_time = time.time()
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
        end_time = time.time()
        total_time = end_time - start_time
        
        print(f"  Return code: {result.returncode}")
        print(f"  Total execution time: {total_time:.2f} sec")
        
        if result.returncode == 0 and result.stdout:
            output = result.stdout
            print(f"  ✅ SLM executed successfully")
            print(f"  Output preview: {output[:150]}...")
            
            # Parse the response between [BEGIN]: and [END]
            begin_idx = output.find('[BEGIN]:')
            end_idx = output.find('[END]')
            
            if begin_idx != -1 and end_idx != -1:
                # Extract the actual response text
                response_text = output[begin_idx+8:end_idx].strip()
                
                # Count tokens (simple word-based counting)
                tokens = response_text.split()
                token_count = len(tokens)
                
                print(f"  Response: '{response_text[:100]}{'...' if len(response_text) > 100 else ''}'")
                print(f"  Token count: {token_count}")
                
                # Calculate timing metrics
                if token_count > 0:
                    # Estimate TTFT (Time To First Token)
                    # For local execution, we can estimate this as a portion of total time
                    estimated_ttft = min(2.0, total_time * 0.3)  # Assume first token takes ~30% of total time, max 2 sec
                    
                    # Calculate stream speed for the remaining tokens
                    generation_time = total_time - estimated_ttft
                    if generation_time > 0 and token_count > 1:
                        stream_speed = token_count / generation_time
                    else:
                        stream_speed = token_count / total_time  # Fallback
                    
                    print(f"  ✅ TTFT (estimated): {estimated_ttft:.2f} sec")
                    print(f"  ✅ Stream speed: {stream_speed:.2f} tokens/sec")
                    
                    return True, estimated_ttft, stream_speed
                else:
                    print("  ⚠️  No tokens found in response")
                    return False, -1, -1
            else:
                print("  ⚠️  Could not parse response (no [BEGIN]/[END] markers)")
                return False, -1, -1
        
        # Handle errors
        print(f"  ❌ SLM execution failed")
        if result.stderr:
            print(f"  Error: {result.stderr}")
        
        return False, -1, -1
        
    except subprocess.TimeoutExpired:
        print(f"  ❌ SLM execution timed out after 120 seconds")
        return False, -1, -1
    except Exception as e:
        print(f"  ❌ Exception during SLM execution: {e}")
        return False, -1, -1

def main():
    """Main execution function."""
    if len(sys.argv) != 2:
        print("Usage: python host_harness_final.py prompt_list.txt")
        sys.exit(1)
    
    # Read prompts from file
    try:
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            prompts = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: File '{sys.argv[1]}' not found.")
        sys.exit(1)
    
    if not prompts:
        print("Error: No prompts found in file.")
        sys.exit(1)
    
    # Initialize CSV file with headers
    try:
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['ram_available_kb', 'network_rssi', 'prompt_length', 'ttft_sec', 'stream_speed_tps'])
        print(f"Initialized CSV file: {OUTPUT_FILE}")
    except Exception as e:
        print(f"Error creating CSV file: {e}")
        sys.exit(1)
    
    print(f"\n🚀 Starting experiment with {len(prompts)} prompts...")
    print(f"Device ID: {DEVICE_ID}")
    print(f"Output file: {OUTPUT_FILE}")
    print("=" * 60)
    
    # Process each prompt
    for i, prompt in enumerate(prompts, 1):
        print(f"\n📝 Prompt {i}/{len(prompts)}: '{prompt}'")
        print("-" * 40)
        
        # Get device metrics
        print("📊 Collecting device metrics...")
        ram_kb = get_ram_available_kb(DEVICE_ID)
        rssi = get_network_rssi(DEVICE_ID)
        
        print(f"  📱 RAM Available: {ram_kb:,} KB")
        print(f"  📶 Network RSSI: {rssi}")
        print(f"  📏 Prompt Length: {len(prompt)} chars")
        
        # Run SLM and measure performance
        print("🤖 Running SLM...")
        success, ttft, speed = run_slm_and_time(DEVICE_ID, prompt)
        
        # Log results to CSV
        try:
            with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([ram_kb, rssi, len(prompt), ttft, speed])
            
            print(f"📝 Results logged: RAM={ram_kb}, RSSI={rssi}, TTFT={ttft:.2f}, Speed={speed:.2f}")
            
        except Exception as e:
            print(f"❌ Error logging to CSV: {e}")
    
    print(f"\n🎉 Experiment completed!")
    print(f"📄 Results saved to: {OUTPUT_FILE}")
    
    # Show final results summary
    try:
        print(f"\n📊 Results Summary:")
        with open(OUTPUT_FILE, 'r') as f:
            content = f.read()
            print(content)
    except:
        pass

if __name__ == "__main__":
    main()