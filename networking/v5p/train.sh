#!/bin/bash
#
# pretrain.sh: Pre-trains LinUCB A and b matrices from a dataset.
#
# This script implements the "offline-training" formulas:
# A_start = I + sum(x_i * x_i_transpose)
# b_start = sum(x_i * y_i)
#
# It is designed to read a CSV file.
#

# --- Configuration (ADJUST THESE TO MATCH YOUR DATA) ---
DATASET_FILE="dataset.csv"   # The input file with your 3000 data points (assuming .csv)
STATE_A="linucb_A.dat"       # Output file for the A matrix
STATE_B="linucb_B.dat"       # Output file for the b vector

# --- Column Mapping (1-based index) ---
# Based on header: cpu_load,ram_load,ram_kb,tokens,prompt_length,ttft_sec,stream_speed_tps
COL_CPU_LOAD=1   # Column index for 'cpu_load'
COL_RAM_LOAD=2   # Column index for 'ram_load'
COL_TOKENS=4     # Column index for 'tokens'
COL_PLEN=5       # Column index for 'prompt_length'
COL_SPEED=7      # Column index for 'stream_speed_tps'

# --- Script Configuration ---
DIMENSIONS=4     # 4 features: [c, cpu_load, ram_load, plen]
BC_SCALE=10      # Precision for 'bc' calculator
CONSTANT_C="1" # The hardcoded value for the constant 'c'

# --- Helper function for floating point math ---
calc() {
    echo "scale=$BC_SCALE; $@" | bc
}

# --- Check if dataset file exists ---
if [ ! -f "$DATASET_FILE" ]; then
    echo "Error: Dataset file not found at '$DATASET_FILE'" >&2
    echo "Please update the DATASET_FILE variable in this script." >&2
    exit 1
fi

echo "Starting pre-training from '$DATASET_FILE'..."
echo "Using constant c = $CONSTANT_C"
echo "Features: [c, cpu_load(col $COL_CPU_LOAD), ram_load(col $COL_RAM_LOAD), plen(col $COL_PLEN)]"
echo "Latency (y): [tokens(col $COL_TOKENS) * stream_speed_tps(col $COL_SPEED)]"
echo "Output will be '$STATE_A' and '$STATE_B'."

# --- 1. Initialize A = Identity (in-memory) ---
# We use a 1D array to store the 4x4 matrix
declare -a A_arr
d=$DIMENSIONS
for ((i=0; i<d; i++)); do
    for ((j=0; j<d; j++)); do
        idx=$((i * d + j))
        if [ $i -eq $j ]; then
            A_arr[$idx]="1.0"
        else
            A_arr[$idx]="0.0"
        fi
    done
done

# --- 2. Initialize b = Zeros (in-memory) ---
declare -a b_arr
for ((i=0; i<d; i++)); do
    b_arr[$i]="0.0"
done

# --- 3. Process the dataset line by line ---
line_count=0
# Read the file line by line, setting IFS to comma for 'read'
# This will handle CSV data and read columns into the 'cols' array.
while IFS=, read -r -a cols; do
    # Skip empty lines (e.g., a blank line at EOF)
    if [ ${#cols[@]} -eq 0 ]; then
        continue
    fi

    # Skip header line (assumes first line is header)
    if (( line_count == 0 )); then
        line_count=$((line_count + 1))
        echo "Skipping header line: ${cols[*]}" >&2
        continue
    fi

    # x_c is the constant
    x_c="$CONSTANT_C"
    
    # x_cpu_load = original_cpu_load
    x_cpu_load=${cols[$((COL_CPU_LOAD-1))]}
    
    # x_ram_load = original_ram_load
    x_ram_load=${cols[$((COL_RAM_LOAD-1))]}
    
    # x_plen = original_plen
    x_plen=${cols[$((COL_PLEN-1))]}
    
    # --- Extract and SCALE latency (y) ---
    tokens=${cols[$((COL_TOKENS-1))]}
    speed=${cols[$((COL_SPEED-1))]}
    
    # Ensure numeric defaults to avoid bc syntax errors when fields are empty
    tokens=${tokens:-0}
    speed=${speed:-0}
    x_cpu_load=${x_cpu_load:-0}
    x_ram_load=${x_ram_load:-0}
    x_plen=${x_plen:-0}

    # Calculate y_original = tokens * speed
    y_original=$(calc "$tokens * $speed")

    # y = y_original (assign string, do not try to execute it)
    y="$y_original"
    
    # Create the feature vector 'x' in the specified order:
    # [c, cpu_load, ram_load, prompt_length]
    x=($x_c $x_cpu_load $x_ram_load $x_plen)

    # --- Update A: A = A + (x * x_transpose) ---
    for ((i=0; i<d; i++)); do
        for ((j=0; j<d; j++)); do
            idx=$((i * d + j))
            x_i=${x[i]}
            x_j=${x[j]}
            
            # x_outer = x[i] * x[j]
            x_outer=$(calc "$x_i * $x_j")
            a_old=${A_arr[$idx]}
            
            # A_arr[i,j] = A_old[i,j] + x_outer
            A_arr[$idx]=$(calc "$a_old + $x_outer")
        done
    done

    # --- Update b: b = b + (x * y) ---
    for ((i=0; i<d; i++)); do
        x_i=${x[i]}
        
        # x_scaled = x[i] * y
        x_scaled=$(calc "$x_i * $y")
        b_old=${b_arr[i]}
        
        # b_arr[i] = b_old[i] + x_scaled
        b_arr[$i]=$(calc "$b_old + $x_scaled")
    done

    # --- Progress Update ---
    line_count=$((line_count + 1))
    if (( (line_count - 1) % 500 == 0 && line_count > 1 )); then # -1 to account for header
        echo "Processed $((line_count - 1)) data lines..." >&2
    fi

# Pipe the file through 'tr' to remove any '\r' (Windows) characters
done < <(tr -d '\r' < "$DATASET_FILE")

echo "Processing complete. Processed $((line_count - 1)) total data lines." >&2

# --- 4. Write final matrices to state files ---
rm -f "$STATE_A"
for ((i=0; i<d; i++)); do
    line=""
    for ((j=0; j<d; j++)); do
        # Note: ${A_arr[((i*d+j))]} ensures correct arithmetic evaluation for index
        line+="${A_arr[((i*d+j))]} "
    done
    echo "$line" >> "$STATE_A"
done

rm -f "$STATE_B"
for ((i=0; i<d; i++)); do
    echo "${b_arr[i]}" >> "$STATE_B"
done

echo "Pre-trained matrices saved successfully."
echo "A matrix ($STATE_A):"
cat "$STATE_A"
echo
echo "b vector ($STATE_B):"
cat "$STATE_B"