# CPU Prompt Execution - Output Capture Pattern

## Analysis of host_harness.py

The `host_harness.py` script (lines 97-154) shows the intended output capture logic:

```python
# Run command with capture_output=True (currently False in your version)
result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)

# Extract generated text (currently commented out)
output = result.stdout
lines = output.splitlines()
generated_lines = []
capture = False

for line in lines:
    if prompt.strip() in line:
        capture = True  # Start capturing AFTER we see the prompt
        continue
    if "[end of text]" in line:
        break  # Stop at end marker
    if capture and line.strip():
        generated_lines.append(line.strip())

response_text = " ".join(generated_lines).strip()
```

**Key Steps:**
1. **Find the prompt** in the output (this is where llama-cli echoes the user input)
2. **Start capturing** on the next line (the actual LLM response begins here)
3. **Stop capturing** when we hit `[end of text]` marker
4. **Join lines** into a single string

## Bash Implementation for mesh_node.sh

### Option 1: Simple sed-based extraction

```bash
execute_cpu_prompt() {
    local prompt="$1"
    local orchestrator_device="$2"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Starting..." >> "$LOG_FILE"
    
    (
        cd /data/local/tmp/cppllama-bundle/llama.cpp
        export LD_LIBRARY_PATH=$PWD/build/bin
        
        # Run llama-cli with -n 5 tokens (matching host_harness.py)
        # -no-cnv flag prevents conversation mode
        FULL_OUTPUT=$(./build/bin/llama-cli -n 5 -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p "$prompt" -no-cnv 2>&1)
        
        # Extract generated text between prompt echo and [end of text]
        # This mirrors the Python logic: find prompt, capture until end marker
        RESULT=$(echo "$FULL_OUTPUT" | sed -n "/$prompt/,/\[end of text\]/p" | sed '1d;$d' | tr '\n' ' ')
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Complete. Result: ${RESULT:0:100}..." >> "$LOG_FILE"
        
        # Send to orchestrator (matches signature in send_result_to_orchestrator)
        send_result_to_orchestrator "$orchestrator_device" "CPU" "$RESULT"
    ) &
}
```

**Explanation:**
- `sed -n "/$prompt/,/\[end of text\]/p"` - Extract lines from prompt to end marker
- `sed '1d;$d'` - Delete first (prompt line) and last ([end of text] line)
- `tr '\n' ' '` - Join all lines with spaces (like Python's `" ".join()`)

### Option 2: More robust with temp file

```bash
execute_cpu_prompt() {
    local prompt="$1"
    local orchestrator_device="$2"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Starting..." >> "$LOG_FILE"
    
    (
        cd /data/local/tmp/cppllama-bundle/llama.cpp
        export LD_LIBRARY_PATH=$PWD/build/bin
        
        # Capture full output to temp file for easier processing
        TEMP_OUT="/sdcard/mesh_network/cpu_output.tmp"
        ./build/bin/llama-cli -n 5 -m models/llama-3.2-3b-instruct-q4_k_m.gguf -p "$prompt" -no-cnv > "$TEMP_OUT" 2>&1
        
        # Extract: skip until we find prompt, then capture until [end of text]
        RESULT=$(awk -v p="$prompt" '
            $0 ~ p { found=1; next }
            found && /\[end of text\]/ { exit }
            found && NF > 0 { printf "%s ", $0 }
        ' "$TEMP_OUT")
        
        rm -f "$TEMP_OUT"
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$DEVICE_NAME] [CPU EXEC] Complete" >> "$LOG_FILE"
        send_result_to_orchestrator "$orchestrator_device" "CPU" "$RESULT"
    ) &
}
```

## Key Differences from NPU Execution

**NPU (genie-t2t-run):**
- Different prompt format (Llama 3.2 chat template)
- Different executable path
- Manages `npu_free` flag

**CPU (llama-cli):**
- Simple prompt (no special formatting)
- Uses llama.cpp executable
- No special flags to manage
- Must parse output to extract just the generated text

## Why This Matters

Without proper parsing, the result would include:
- Startup messages from llama-cli
- The echoed prompt
- Performance stats
- The `[end of text]` marker

With proper parsing (matching host_harness.py), we get:
- ONLY the generated text
- Clean, ready to send to orchestrator

This ensures the orchestrator receives useful results, not debug output.
