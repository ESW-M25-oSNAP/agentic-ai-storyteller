#!/system/bin/sh
set -eu

# primitive_agent.sh (Android POSIX-compatible)
# Usage:
#   ./primitive_agent.sh single    # process all SNPE outputs and feed to Genie
#   ./primitive_agent.sh query "Your query"
#   ./primitive_agent.sh loop      # interactive mode\
#   ./primitive_agent.sh dual "Your query"
#   ./primitive_agent.sh

SNPE_DIR="/data/local/tmp/snpe-bundle"
GENIE_DIR="/data/local/tmp/genie-bundle"
LABELS="$SNPE_DIR/imagenet_slim_labels.txt"
POSTPROCESS_BIN="$SNPE_DIR/postprocess"   # must be compiled for aarch64 Android
OUTPUT_DIR="$SNPE_DIR/output"
GENIE_CFG="$GENIE_DIR/genie_config.json"

# Android-safe environment
export LD_LIBRARY_PATH="$SNPE_DIR:${LD_LIBRARY_PATH:-}"
export ADSP_LIBRARY_PATH="$GENIE_DIR/hexagon-v75/unsigned"

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
        echo "[agent] Postprocessing index $idx -> $rawfile" >&2
        if [ ! -f "$rawfile" ]; then
            echo "[agent] MISSING: $rawfile" >&2
            pp_out="0.0 -1 missing_file"
        else
            pp_out=$( "$POSTPROCESS_BIN" "$rawfile" "$LABELS" 2>/dev/null || echo "0.0 -1 missing_file" )
        fi

        maxval=$(echo "$pp_out" | awk '{print $1}')
        maxidx=$(echo "$pp_out" | awk '{print $2}')
        label=$(echo "$pp_out" | cut -d' ' -f3-)
        echo "[agent] $rawfile -> $label (idx=$maxidx, score=$maxval)" >&2
        labels="${labels}${label}; "
        idx=$((idx+1))
    done
    # print only the final label list to stdout
    echo "$labels"
}

run_genie() {
    QUERY="$1"
    export LD_LIBRARY_PATH="$GENIE_DIR"
    export ADSP_LIBRARY_PATH="$GENIE_DIR/hexagon-v75/unsigned"
    ( cd "$GENIE_DIR" && \
      ./genie-t2t-run -c "$GENIE_CFG" -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n${QUERY}<|eot_id|><|start_header_id|>assistant<|end_header_id|>" )
}

copy_latest_images() {
    num=$1
    # The below lines are to be changed based on the given file path. Currently it says ***/DCIM/Camera for Anil Nayak's phone 
    camera_dir="/storage/emulated/0/DCIM/Camera" 
    target_dir="../snpe-bundle/images"
    mkdir -p "$target_dir"

    latest_files=$(ls -t "$camera_dir"/*.jpg 2>/dev/null | head -n "$num")
    if [ -z "$latest_files" ]; then
        echo "[agent] No JPG images found in $camera_dir."
        return 1
    fi

    echo "[agent] Copying $num latest images to $target_dir..."
    for f in $latest_files; do
    	echo $f
        cp "$f" "$target_dir/"
    done
}

preprocess_and_run() {
    SNPE_BASE="../snpe-bundle"
    cd "$SNPE_BASE" || { echo "[agent] Failed to cd to $SNPE_BASE"; return 1; }

    # Clean old files
    rm -rf output preprocessed/* cropped/* target_raw_list.txt combined_labels.txt
    mkdir -p images preprocessed cropped output

    echo "[agent] Preprocessing images..."
    export LD_LIBRARY_PATH="$PWD"
    ./preprocess_android ./images ./preprocessed 299 bilinear || {
        echo "[agent] Preprocessing failed"
        return 1
    }

    # Move only the newly preprocessed files to cropped and add .raw to target_raw_list.txt
    > target_raw_list.txt
    if [ "$(ls -A preprocessed 2>/dev/null)" ]; then
        for img in preprocessed/*; do
            fname=$(basename "$img")
            mv "$img" "cropped/$fname"

            case "$fname" in
                *.raw)
                    echo "cropped/$fname" >> target_raw_list.txt
                    ;;
            esac
        done
    else
        echo "[agent] No files found in preprocessed/"
    fi

    echo "[agent] Running InceptionV3 model..."
    run_inception

    NUM_RESULTS=$1  

   # Find the latest Result_* directories by numeric suffix
   latest_results=$(ls -d "$OUTPUT_DIR"/Result_* 2>/dev/null | \
       sed 's/.*Result_//' | sort -n | tail -n "$NUM_RESULTS")

    for idx in $latest_results; do
        rawfile="$OUTPUT_DIR/Result_${idx}/InceptionV3/Predictions/Reshape_1:0.raw"
        if [ ! -f "$rawfile" ]; then
            echo "[agent] MISSING: $rawfile" >&2
            echo "0.0 -1 missing_file"
            continue
         fi

        echo "[debug] Running: $POSTPROCESS_BIN $rawfile $LABELS" >&2
        pp_out=$("$POSTPROCESS_BIN" "$rawfile" "$LABELS" 2>/dev/null || echo "0.0 -1 missing_file")
        echo "$pp_out"

        labels=$(echo "$pp_out" | cut -d' ' -f3-)
        echo "$labels" >> combined_labels.txt
     done
}

mode="${1:-}"

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
    echo "Commands: run | query <text> | dual | quit"
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
        elif [ "$cmd" = "dual" ]; then
            if [ -z "$rest" ]; then
                echo "Usage: dual <text>"
            else
               	run_inception
    		labels=$(postprocess_all)
    		QUERYY="$QUERY $labels"
    		echo "[agent] Running Genie for query: $QUERYY"
    		run_genie "$QUERYY"
            fi
        else
            echo "Unknown command: $cmd"
            echo "Commands: run | query <text> | dual | quit"
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

if [ "$mode" = "" ]; then
    echo "[agent] Interactive loop (default). Type 'quit' to exit."
    echo "Commands: query <text> | image <num> | both <num>:<text>| quit"
    while true; do
        printf "> "
        read cmd rest
        if [ "$cmd" = "quit" ]; then
            echo "[agent] Exiting loop."
            break
        elif [ "$cmd" = "query" ]; then
            if [ -z "$rest" ]; then
                echo "Usage: query <text>"
            else
                QUERY="$rest"
                echo "[agent] Running Genie for query: $QUERY"
                run_genie "$QUERY"
            fi
        elif [ "$cmd" = "image" ]; then
    		if [ -z "$rest" ]; then
        		echo "Usage: image <num>"
        		continue
    		fi	
    		copy_latest_images "$rest" || continue
    		preprocess_and_run "$rest"

    		labels=$(paste -s -d', ' combined_labels.txt)
    		QUERY="Write a short story that includes these objects: $labels"
    		echo "[agent] Feeding query to Genie: $QUERY"
    		run_genie "$QUERY"

	elif [ "$cmd" = "both" ]; then
    		IFS=':' read -r num USER_QUERY <<< "$rest"
    		if [ -z "$num" ] || [ -z "$USER_QUERY" ]; then
        		echo "Usage: both <num>:<text>"
        		continue
    		fi

    		copy_latest_images "$num" || continue
    		preprocess_and_run "$num"

    		labels=$(paste -s -d', ' combined_labels.txt)
    		QUERY="Write a short story that includes these objects: $labels. Additionally, incorporate this input: $USER_QUERY"
    		echo "[agent] Running Genie for combined query: $QUERY"
    		run_genie "$QUERY"
        else
            echo "Unknown command: $cmd"
            echo "Commands: query <text> | image | both <text> | quit"
        fi
    done
    exit 0
fi

echo "Usage: $0 {single | query \"text\" | loop}"
exit 2

