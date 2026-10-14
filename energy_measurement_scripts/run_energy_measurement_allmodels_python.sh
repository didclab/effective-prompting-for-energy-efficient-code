#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 --num-runs <num> --path <path_to_files> --output <output_dir>"
    exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --num-runs) NUM_RUNS="$2"; shift 2;;
        --path) BASE_DIR="$2"; shift 2;;
        --output) OUTPUT_BASE_DIR="$2"; shift 2;;
        *) echo "Unknown parameter: $1"; usage;;
    esac
done

# Validate arguments
if [[ -z "$NUM_RUNS" || -z "$BASE_DIR" || -z "$OUTPUT_BASE_DIR" ]]; then
    echo "Error: --num-runs, --path, and --output must be specified."
    usage
fi

# Ensure the path exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory '$BASE_DIR' does not exist!"
    exit 1
fi

# Check if the output folder already exists (to prevent overwriting)
if [ -d "$OUTPUT_BASE_DIR" ]; then
    echo "Error: Output directory '$OUTPUT_BASE_DIR' already exists! Choose a different name or delete the existing folder."
    exit 1
fi

# Create the output directory
mkdir -p "$OUTPUT_BASE_DIR"

# Create a log file with a timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="experiment_${TIMESTAMP}.log"

echo "Logging all output to $LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect stdout & stderr to log file

NUM_ITERATIONS=30                  
RUN_IDLE=3
RUN_COOLDOWN=3

echo "Running experiment with NUM_RUNS=$NUM_RUNS, FILES_PATH=$BASE_DIR, and OUTPUT_DIR=$OUTPUT_BASE_DIR"

for model_dir in "$BASE_DIR"/*; do
    if [ -d "$model_dir" ]; then
        echo "Processing model directory: $model_dir"
        model_dir_name=$(basename "$model_dir")
        for prompt_dir in "$model_dir"/*; do
            if [ -d "$prompt_dir" ]; then
                echo "Processing prompt directory: $prompt_dir"
                prompt_dir_name=$(basename "$prompt_dir")
                # Iterate over each problem number directory
                for problem_dir in "$prompt_dir"/*; do
                    if [ -d "$problem_dir" ]; then
                        problem_dir_name=$(basename "$problem_dir")
                        output_path="$OUTPUT_BASE_DIR/${model_dir_name}/${prompt_dir_name}/${problem_dir_name}"
                        mkdir -p "$output_path"
#                        echo "Measuring idle energy for 30 before running files in directory '$problem_dir'..."
#                        sudo perf stat -a -e power/energy-pkg/ -e power/energy-ram/ -e cache-misses -e cpu-clock sleep "$RUN_COOLDOWN" 2> "$output_path/idle.txt"

                        echo "Running all Python files in: $problem_dir, $NUM_RUNS time(s)"
                        for ((i = 1; i <= NUM_RUNS; i++)); do
                            echo "Run $i/$NUM_RUNS"
                            # Iterate over each .py file in the problem directory
                            shuf -e "$problem_dir"/*.py | while IFS= read -r py_file; do
                                if [ -f "$py_file" ]; then
                                    filename_no_ext="$(basename "$py_file" .py)"
                                    echo "Running cooldown for '$RUN_COOLDOWN' to stabilise the system"
                                    sleep $RUN_COOLDOWN
                                    echo "Measuring idle energy for '$RUN_IDLE' before running files in directory '$problem_dir'..."
                                    sudo perf stat -a -e power/energy-pkg/ -e power/energy-ram/ -e cache-misses -e cpu-clock sleep "$RUN_IDLE" 2> "$output_path/${filename_no_ext}_run_${i}_idle.txt"
                                    echo "Running '$py_file' for $NUM_ITERATIONS iterations..."
                                    #echo "Output base dir: $OUTPUT_BASE_DIR, prompt_dir_name: $prompt_dir_name, problem_dir_name:$problem_dir_name, Filename: $filename_no_ext"
                                    sudo perf stat -a -e power/energy-pkg/ -e power/energy-ram/ -e cache-misses -e cpu-clock -- \
                                        bash -c "for ((i=1; i<=$NUM_ITERATIONS; i++)); do python3 '$py_file'; done" 2> "$output_path/${filename_no_ext}_run_${i}_perf.txt"

                                fi
                            done
                        done
                    fi
                done
                echo "Completed energy measurements for prompt dir: $prompt_dir"
            fi
        done
    fi
done



