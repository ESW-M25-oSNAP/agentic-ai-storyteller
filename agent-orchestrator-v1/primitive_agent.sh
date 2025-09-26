#!/system/bin/sh
set -eu

# primitive_agent.sh (Android POSIX-compatible)
# Usage:
#   ./primitive_agent.sh single    # process all SNPE outputs and feed to Genie
#   ./primitive_agent.sh query "Your query"
#   ./primitive_agent.sh loop      # interactive mode\
#   ./primitive_agent.sh dual "Your query"

SNPE_DIR="/data/local/tmp/snpe-bundle"
GENIE_DIR="/data/local/tmp/genie-bundle"
LABELS="$SNPE_DIR/imagenet_slim_labels.txt"
POSTPROCESS_BIN="$SNPE_DIR/postprocess"   # must be compiled for aarch64 Android
OUTPUT_DIR="$SNPE_DIR/output"
GENIE_CFG="$GENIE_DIR/genie_config.json"

# Android-safe environment
export LD_LIBRARY_PATH="$SNPE_DIR:${LD_LIBRARY_PATH:-}"
export ADSP_LIBRARY_PATH="$SNPE_DIR/hexagon-v75/unsigned/:${ADSP_LIBRARY_PATH:-}"

run_inception() {
    echo "[agent] Running InceptionV3 (SNPE)..."
    ( cd "$SNPE_DIR" && \
      ./snpe-net-run \
        --container "./inception_v3.dlc" \
        --input_list "./target_raw_list.txt" \
        --output_dir "$OUTPUT_DIR" \
        --use_dsp )
}

postprocess_all() {
    idx=0
    labels=""
    for result_dir in "$OUTPUT_DIR"/Result_*; do
        rawfile="$result_dir/InceptionV3/Predictions/Reshape_1:0.raw"
        echo "[agent] Postprocessing index $idx -> $rawfile"
        if [ ! -f "$rawfile" ]; then
            echo "[agent] MISSING: $rawfile"
            pp_out="0.0 -1 missing_file"
        else
            pp_out=$( "$POSTPROCESS_BIN" "$rawfile" "$LABELS" 2>/dev/null || echo "0.0 -1 missing_file" )
        fi

        maxval=$(echo "$pp_out" | awk '{print $1}')
        maxidx=$(echo "$pp_out" | awk '{print $2}')
        label=$(echo "$pp_out" | cut -d' ' -f3-)
        echo "[agent] $rawfile -> $label (idx=$maxidx, score=$maxval)"
        labels="${labels}${label}; "
        idx=$((idx+1))
    done
    echo "$labels"
}

run_genie() {
    QUERY="$1"
    export LD_LIBRARY_PATH="$GENIE_DIR"
    export ADSP_LIBRARY_PATH="$GENIE_DIR/hexagon-v75/unsigned"
    ( cd "$GENIE_DIR" && \
      ./genie-t2t-run -c "$GENIE_CFG" -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n${QUERY}<|eot_id|><|start_header_id|>assistant<|end_header_id|>" )
}

mode="${1:-single}"

if [ "$mode" = "single" ]; then
    echo "[agent] Mode: single batch run"
    run_inception
    labels=$(postprocess_all)
    QUERY="Write a short story that includes these objects: ${labels}"
    echo "[agent] Feeding query to Genie: $QUERY"
    run_genie "$QUERY"
    exit 0
fi

if [ "$mode" = "query" ]; then
    shift
    QUERY="$*"
    echo "[agent] Running Genie for query: $QUERY"
    run_genie "$QUERY"
    exit 0
fi

if [ "$mode" = "loop" ]; then
    echo "[agent] Interactive loop mode. Type 'quit' to exit."
    while true; do
        printf "> "
        read cmd rest
        if [ "$cmd" = "quit" ]; then
            echo "[agent] Exiting loop."
            break
        elif [ "$cmd" = "run" ]; then
            echo "[agent] Running SNPE + postprocess + Genie..."
            run_inception
            labels=$(postprocess_all)
            QUERY="Write a short story that includes these objects: ${labels}"
            run_genie "$QUERY"
        elif [ "$cmd" = "query" ]; then
            if [ -z "$rest" ]; then
                echo "Usage: query <text>"
            else
                QUERY="$rest"
                run_genie "$QUERY"
            fi
        else
            echo "Unknown command: $cmd"
            echo "Commands: run | query <text> | quit"
        fi
    done
    exit 0
fi

if [ "$mode" = "dual" ]; then
    shift
    QUERY="$*"
    echo "[agent] Mode: dual: SNPE + Genie"
    run_inception
    labels=$(postprocess_all)
    QUERYY="$QUERY $labels"
    echo "[agent] Running Genie for query: $QUERYY"
    run_genie "$QUERYY"
    exit 0
fi

echo "Usage: $0 {single | query \"text\" | loop}"
exit 2

