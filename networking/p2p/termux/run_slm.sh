#!/data/data/com.termux/files/usr/bin/bash
# SLM Execution Wrapper for Genie Bundle
# This script runs the Genie Bundle SLM and captures output

set -e

# Configuration
GENIE_DIR="/data/local/tmp/genie-bundle"
OUTPUT_DIR="/data/local/tmp/mesh/outputs"
LOG_DIR="/data/local/tmp/mesh/logs"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Initialize directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] [$level] $msg${NC}" | tee -a "$LOG_DIR/slm_execution.log"
}

# Check if Genie Bundle exists
check_genie_bundle() {
    # Check for the actual genie-t2t-run executable
    local genie_executable="/data/local/tmp/genie-bundle/genie-t2t-run"
    local genie_config="/data/local/tmp/genie-bundle/genie_config.json"
    
    if [ -f "$genie_executable" ] && [ -f "$genie_config" ]; then
        GENIE_SCRIPT="$genie_executable"
        GENIE_DIR="/data/local/tmp/genie-bundle"
        log "INFO" "Found Genie Bundle at: $GENIE_DIR"
        return 0
    fi
    
    log "ERROR" "Genie Bundle not found in standard location"
    return 1
}

# Run Genie Bundle with prompt
run_genie_slm() {
    local prompt_file="$1"
    local output_file="$2"
    
    if [ ! -f "$prompt_file" ]; then
        echo "ERROR: Prompt file not found: $prompt_file"
        return 1
    fi
    
    local prompt=$(cat "$prompt_file")
    log "INFO" "Running Genie SLM with prompt: ${prompt:0:100}..."
    
    # Change to Genie directory
    cd "$GENIE_DIR" || {
        echo "ERROR: Cannot access Genie directory: $GENIE_DIR"
        return 1
    }
    
    # Set required environment variables
    export LD_LIBRARY_PATH="$GENIE_DIR"
    export ADSP_LIBRARY_PATH="$GENIE_DIR/hexagon-v75/unsigned/"
    
    # Format the prompt with the required template
    local formatted_prompt="<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n${prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
    
    log "INFO" "Executing Genie with formatted prompt"
    
    # Capture output and errors
    local start_time=$(date +%s)
    
    # Run with timeout (5 minutes max)
    timeout 300 ./genie-t2t-run -c genie_config.json -p "$formatted_prompt" > "$output_file" 2>&1
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        log "INFO" "SLM execution completed in ${duration}s"
        echo -e "\n--- Execution Time: ${duration}s ---" >> "$output_file"
        return 0
    elif [ $exit_code -eq 124 ]; then
        echo "ERROR: SLM execution timed out after 300s" | tee -a "$output_file"
        return 1
    else
        echo "ERROR: SLM execution failed with code $exit_code" | tee -a "$output_file"
        return 1
    fi
}

# Main execution
main() {
    local prompt_file="${1:-}"
    
    if [ -z "$prompt_file" ]; then
        echo "Usage: $0 <prompt_file>"
        echo "Example: $0 /path/to/prompt.txt"
        exit 1
    fi
    
    log "START" "================================"
    log "START" "SLM Execution Starting"
    log "START" "================================"
    
    # Check for Genie Bundle
    if ! check_genie_bundle; then
        log "ERROR" "Genie Bundle not found. Please install it first."
        
        cat << EOF

Genie Bundle Installation Instructions:
1. Download Genie Bundle from Qualcomm
2. Extract to /data/local/tmp/genie-bundle/
3. Ensure the following files exist:
   - /data/local/tmp/genie-bundle/genie-t2t-run
   - /data/local/tmp/genie-bundle/genie_config.json
   - /data/local/tmp/genie-bundle/hexagon-v75/unsigned/
4. Ensure execution permissions: chmod +x /data/local/tmp/genie-bundle/genie-t2t-run
5. Test manually:
   cd /data/local/tmp/genie-bundle
   export LD_LIBRARY_PATH=\$PWD
   export ADSP_LIBRARY_PATH=\$PWD/hexagon-v75/unsigned/
   ./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nHello<|eot_id|><|start_header_id|>assistant<|end_header_id|>"

EOF
        exit 1
    fi
    
    # Generate output filename
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="$OUTPUT_DIR/slm_output_${timestamp}.txt"
    
    # Run the SLM
    if run_genie_slm "$prompt_file" "$output_file"; then
        log "SUCCESS" "SLM output saved to: $output_file"
        
        # Display the output
        echo -e "\n${GREEN}=== SLM OUTPUT ===${NC}"
        cat "$output_file"
        echo -e "${GREEN}=================${NC}\n"
        
        # Return the output for the mesh network
        cat "$output_file"
        exit 0
    else
        log "ERROR" "SLM execution failed"
        
        if [ -f "$output_file" ]; then
            echo -e "\n${RED}=== ERROR OUTPUT ===${NC}"
            cat "$output_file"
            echo -e "${RED}====================${NC}\n"
        fi
        
        exit 1
    fi
}

# Run main
main "$@"
