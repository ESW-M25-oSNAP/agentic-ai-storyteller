#!/usr/bin/env python3
"""
host_harness_final.py - Fixed version with proper RSSI handling and working SLM execution
"""

import subprocess
import re
import os
import csv 
import sys
import time
import random

# Constants
DEVICE_ID = "9688d142"
OUTPUT_FILE = "dataset-11.csv"

def parse_llama_perf_from_file(device: str,
                              remote_path="/data/local/tmp/cppllama-bundle/llama.cpp/stats.txt",
                              local_file="stats.txt"):
    subprocess.run(f"adb -s {device} pull {remote_path} {local_file}",
                   shell=True, capture_output=True)

    if not os.path.exists(local_file):
        print("No stats.txt found")
        return None

    with open(local_file, "r", encoding="utf-8", errors="ignore") as f:
        text = " ".join([ln.strip() for ln in f.readlines()[-15:]])

    def f(x): return float(x) if x else 0.0
    def i(x): return int(float(x)) if x else 0

    # --- Extract all key stats ---
    sampling = re.search(r"sampling time\s*=\s*([\d.]+)\s*ms\s*/\s*(\d+)\s*runs\s*\(\s*([\d.]+)\s*ms per token", text)
    load     = re.search(r"load time\s*=\s*([\d.]+)\s*ms", text)
    prompt   = re.search(r"prompt eval time\s*=\s*([\d.]+)\s*ms\s*/\s*(\d+)\s*tokens\s*\(\s*([\d.]+)\s*ms per token", text)
    ev       = re.search(r"eval time\s*=\s*([\d.]+)\s*ms\s*/\s*(\d+)\s*runs\s*\(\s*([\d.]+)\s*ms per token", text)
    total    = re.search(r"total time\s*=\s*([\d.]+)\s*ms\s*/\s*(\d+)\s*tokens", text)

    # --- Parse safely ---
    sampling_total_ms = f(sampling.group(1)) if sampling else 0
    sampling_runs     = i(sampling.group(2)) if sampling else 0
    sampling_pt_ms    = f(sampling.group(3)) if sampling else 0

    load_ms           = f(load.group(1)) if load else 0

    prompt_total_ms   = f(prompt.group(1)) if prompt else 0
    prompt_tokens     = i(prompt.group(2)) if prompt else 0
    prompt_pt_ms      = f(prompt.group(3)) if prompt else 0

    eval_total_ms     = f(ev.group(1)) if ev else 0
    eval_runs         = i(ev.group(2)) if ev else 0
    eval_pt_ms        = f(ev.group(3)) if ev else 0

    total_ms          = f(total.group(1)) if total else 0
    total_tokens      = i(total.group(2)) if total else eval_runs

    # --- Derived metrics ---
    ttft_warm_ms  = prompt_total_ms + eval_pt_ms + sampling_pt_ms
    ttft_cold_ms  = load_ms + ttft_warm_ms
    ttft_final_ms = 0.6 * ttft_cold_ms + 0.4 * ttft_warm_ms

    stream_speed  = (total_tokens / (total_ms / 1000.0)) if total_ms > 0 else 0.0

    return {
        "load_time_ms": load_ms,
        "prompt_eval_ms": prompt_total_ms,
        "prompt_per_token_ms": prompt_pt_ms,
        "eval_total_ms": eval_total_ms,
        "eval_runs": eval_runs,
        "eval_per_token_ms": eval_pt_ms,
        "sampling_total_ms": sampling_total_ms,
        "sampling_runs": sampling_runs,
        "sampling_per_token_ms": sampling_pt_ms,
        "tokens": total_tokens,
        "total_time_ms": total_ms,
        "ttft_warm": ttft_warm_ms / 1000.0,
        "ttft_cold": ttft_cold_ms / 1000.0,
        "ttft_final": ttft_final_ms / 1000.0,
        "stream_speed": stream_speed,
    }

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

def run_slm_and_time(device, prompt):
    """Run SLM on device using the working command format and measure timing."""
    
    cmd = (
        f'adb -s {device} shell "'
        f'cd /data/local/tmp/cppllama-bundle/llama.cpp && '
        f'export LD_LIBRARY_PATH=/data/local/tmp/cppllama-bundle/llama.cpp/build/bin/ && '
        f'./build/bin/llama-cli -n 5 -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p \\"{prompt}\\" -no-cnv --log-timestamps --log-file stats.txt"'
    )
    
    print(f"  Running SLM...")
    print(f"  Command: {cmd[:100]}...")
    
    start_time = time.time()
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=False, text=True, timeout=120)
        end_time = time.time()
        total_time = end_time - start_time

        print(f"  Return code: {result.returncode}")
        print(f"  Total execution time: {total_time:.2f} sec")

        if result.returncode != 0:
            print("SLM execution failed")
            if result.stderr:
                print(f"  Error: {result.stderr}")
            return False, -1, -1, -1

        # output = result.stdout
        # if not output:
        #     print("No output received from device")
        #     return False, -1, -1, -1

        # print(f"SLM executed successfully")
        # print(f"Output preview: {output[:150]}...")

        # # --- Step 1: Extract generated text ---
        # lines = output.splitlines()
        # generated_lines = []
        # capture = False

        # for line in lines:
        #     if prompt.strip() in line:
        #         capture = True
        #         continue
        #     if "[end of text]" in line:
        #         break
        #     if capture and line.strip():
        #         generated_lines.append(line.strip())

        # response_text = " ".join(generated_lines).strip()

        # if not response_text:
        #     print("Could not extract generated text from output")
        #     return False, -1, -1, -1

        # print(f"Response: '{response_text[:120]}{'...' if len(response_text) > 10000 else ''}'")

        perf = parse_llama_perf_from_file(device)
        if not perf:
            return False, -1, -1, -1

        print(f"Perf stats:")
        for k, v in perf.items():
            if "ms" in k:
                print(f"     {k:<22}= {v:.2f} ms")
            else:
                print(f"     {k:<22}= {v:.3f} sec")

        print(f"TTFT (cold)  : {perf['ttft_cold']:.3f} sec")
        print(f"TTFT (warm)  : {perf['ttft_warm']:.3f} sec")
        print(f"TTFT (final) : {perf['ttft_final']:.3f} sec")
        print(f"Stream speed : {perf['stream_speed']:.2f} tokens/sec")

        # --- Step 3: Summary line ---
        print(
            f"SUMMARY | Device: {device} | TTFT: {perf['ttft_final']:.2f}s | "
            f"Speed: {perf['stream_speed']:.2f} tok/s | Tokens: {perf['tokens']} | "
            f"Load: {perf['load_time_ms']/1000:.2f}s | OK"
        )

        return True, perf['tokens'], perf['ttft_final'], perf['stream_speed']

    except subprocess.TimeoutExpired:
        print(f"SLM execution timed out after 120 seconds")
        return False, -1, -1, -1
    except Exception as e:
        print(f"Exception during SLM execution: {e}")
        return False, -1, -1, -1

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
            writer.writerow(['cpu_load', 'ram_load', 'ram_kb', 'tokens', 'prompt_length', 'ttft_sec', 'stream_speed_tps'])
        print(f"Initialized CSV file: {OUTPUT_FILE}")
    except Exception as e:
        print(f"Error creating CSV file: {e}")
        sys.exit(1)
    
    print(f"\nStarting experiment with {len(prompts)} prompts...")
    print(f"Device ID: {DEVICE_ID}")
    print(f"Output file: {OUTPUT_FILE}")
    print("=" * 60)
    
    
    for n1 in range(1, 101, 6):
        for n2 in range(1, 101, 6):
            # IMPORTANT LINE
            if n1 < 85 or (n1 == 85 and n2 < 25):
                continue
            print(f"\nApplying pre-load: loadgen({n1}, 8), ramload({n2}, 8)")

            # Start both background load processes asynchronously
            loadgen_proc = subprocess.Popen(
                f"adb -s {DEVICE_ID} shell 'cd /data/local/tmp/cppllama-bundle && ./loadgen {n1} 8 &'",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            ramload_proc = subprocess.Popen(
                f"adb -s {DEVICE_ID} shell 'cd /data/local/tmp/cppllama-bundle && ./ramload {n2} 8 &'",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

            try:
                # Give the load processes time to stabilize
                print("Waiting 1 second for load stabilization...")
                time.sleep(1)

                # --- Inner loop: process each prompt ---
                for i, prompt in enumerate(prompts, 1):
                    print(f"\nPrompt {i}/{len(prompts)}: '{prompt}'")
                    print("-" * 40)

                    # Collect metrics
                    print("Collecting device metrics...")
                    ram_kb = get_ram_available_kb(DEVICE_ID)

                    print(f"RAM Available: {ram_kb:,} KB")
                    print(f"Prompt Length: {len(prompt)} chars")

                    # Run SLM
                    print("Running SLM...")
                    success, toks, ttft, speed = run_slm_and_time(DEVICE_ID, prompt)

                    # Log results
                    with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as f:
                        writer = csv.writer(f)
                        writer.writerow([n1, n2, ram_kb, toks, len(prompt), ttft, speed])
                    print(f"Logged: CPU={n1}, RAM={n2}, Tokens={toks}, TTFT={ttft:.2f}, Speed={speed:.2f}")

            finally:
                # Stop background load before next n2 iteration
                print("Stopping background load processes...")
                subprocess.run(f"adb -s {DEVICE_ID} shell pkill -f loadgen", shell=True)
                subprocess.run(f"adb -s {DEVICE_ID} shell pkill -f ramload", shell=True)

                # Ensure local handles are cleaned up
                loadgen_proc.terminate()
                ramload_proc.terminate()

            print(f"Completed iteration n1={n1}, n2={n2}")

if __name__ == "__main__":
    main()
