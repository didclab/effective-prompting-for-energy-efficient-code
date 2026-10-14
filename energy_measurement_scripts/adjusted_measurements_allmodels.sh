#!/usr/bin/env bash

set -euo pipefail

# Maximum number of prompt folders processed concurrently.
MAX_JOBS=20

# --------------------------------------------------
# Calculate idle baseline energy per second
# --------------------------------------------------
calculate_base_energy() {
    local idle_file="$1"
    local energy_pkg energy_ram time_elapsed

    if [[ ! -f "$idle_file" ]]; then
        echo "Error: Missing idle file: $idle_file" >&2
        return 1
    fi

    energy_pkg=$(awk '/energy-pkg/ {print $1; exit}' "$idle_file")
    energy_ram=$(awk '/energy-ram/ {print $1; exit}' "$idle_file")
    time_elapsed=$(grep -oP '[0-9]+(\.[0-9]+)? seconds time elapsed' \
        "$idle_file" | awk '{print $1; exit}')

    if [[ -z "$energy_pkg" || -z "$energy_ram" || -z "$time_elapsed" ]]; then
        echo "Error: Could not parse energy or elapsed time from $idle_file" >&2
        return 1
    fi

    if [[ $(echo "$time_elapsed > 0" | bc -l) -ne 1 ]]; then
        echo "Error: Invalid elapsed time in $idle_file" >&2
        return 1
    fi

    local pkg_per_second ram_per_second

    pkg_per_second=$(echo "$energy_pkg / $time_elapsed" | bc -l) || return 1
    ram_per_second=$(echo "$energy_ram / $time_elapsed" | bc -l) || return 1

    printf '%s %s\n' "$pkg_per_second" "$ram_per_second"
}

# --------------------------------------------------
# Process one perf file and write its adjusted JSON
# --------------------------------------------------
process_perf_file() {
    local perf_file="$1"
    local energy_pkg_base="$2"
    local energy_ram_base="$3"
    local num_iterations="$4"
    local output_file="$5"

    local runtime energy_pkg energy_ram
    runtime=$(grep -oP '[0-9]+(\.[0-9]+)? seconds time elapsed' \
        "$perf_file" | awk '{print $1; exit}')
    energy_pkg=$(awk '/energy-pkg/ {print $1; exit}' "$perf_file")
    energy_ram=$(awk '/energy-ram/ {print $1; exit}' "$perf_file")

    if [[ -z "$runtime" || -z "$energy_pkg" || -z "$energy_ram" ]]; then
        echo "Error: Could not parse perf measurements: $perf_file" >&2
        return 1
    fi

    local adjusted_energy_pkg adjusted_energy_ram
    local adjusted_energy_pkg_for_1_run adjusted_energy_ram_for_1_run
    local runtime_1_run

    adjusted_energy_pkg=$(echo "$energy_pkg - ($energy_pkg_base * $runtime)" | bc -l) || return 1
    adjusted_energy_ram=$(echo "$energy_ram - ($energy_ram_base * $runtime)" | bc -l) || return 1

    adjusted_energy_pkg_for_1_run=$(echo "$adjusted_energy_pkg / $num_iterations" | bc -l) || return 1
    adjusted_energy_ram_for_1_run=$(echo "$adjusted_energy_ram / $num_iterations" | bc -l) || return 1
    runtime_1_run=$(echo "$runtime / $num_iterations" | bc -l) || return 1

    # Write to a temporary file first so incomplete JSON is not left behind.
    local tmp_file="${output_file}.tmp.${BASHPID}"

    if ! printf '{
  "energy_pkg_base_per_second": %s,
  "energy_ram_base_per_second": %s,
  "energy-pkg": %s,
  "energy-ram": %s,
  "runtime": %s,
  "adjusted_energy_pkg": %s,
  "adjusted_energy_ram": %s,
  "num_iterations_per_file": %s,
  "runtime_1_run": %s,
  "adjusted_energy_pkg_for_1_run": %s,
  "adjusted_energy_ram_for_1_run": %s
}\n' \
        "$energy_pkg_base" \
        "$energy_ram_base" \
        "$energy_pkg" \
        "$energy_ram" \
        "$runtime" \
        "$adjusted_energy_pkg" \
        "$adjusted_energy_ram" \
        "$num_iterations" \
        "$runtime_1_run" \
        "$adjusted_energy_pkg_for_1_run" \
        "$adjusted_energy_ram_for_1_run" > "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    if ! mv -f -- "$tmp_file" "$output_file"; then
        rm -f "$tmp_file"
        return 1
    fi
}

# --------------------------------------------------
# Worker: process one prompt folder
# --------------------------------------------------
process_prompt_folder() {
    local prompt_dir="$1"
    local num_iterations="$2"

    echo "[$BASHPID] Processing prompt folder: $prompt_dir"

    local problem_dir perf_file idle_file output_json_file
    local filename exp_number run_number
    local energy_pkg_base energy_ram_base
    local -a baseline=()
    local failed=0
    local processed=0
    local skipped=0

    # Iterate through problem directories within this prompt.
    while IFS= read -r -d '' problem_dir; do

        # Process every matching perf file in the problem directory.
        for perf_file in "$problem_dir"/*_run_*_perf.txt; do
            [[ -f "$perf_file" ]] || continue

            filename=$(basename "$perf_file")

            # Extract experiment and run numbers from the filename.
            if [[ "$filename" =~ ^([0-9]+)_run_([0-9]+)_perf\.txt$ ]]; then
                exp_number="${BASH_REMATCH[1]}"
                run_number="${BASH_REMATCH[2]}"
            else
                echo "Warning: Unexpected filename: $perf_file" >&2
                ((skipped += 1))
                continue
            fi

            idle_file="${problem_dir}/${exp_number}_run_${run_number}_idle.txt"
            output_json_file="${problem_dir}/${exp_number}_run_${run_number}_adjusted.json"

            if [[ ! -f "$idle_file" ]]; then
                echo "Error: Missing idle file: $idle_file" >&2
                ((skipped += 1))
                failed=1
                continue
            fi

            # Get idle baseline for this exact run.
            if ! read -r energy_pkg_base energy_ram_base < <(
                calculate_base_energy "$idle_file"
            ); then
                echo "Error: Failed to calculate baseline for $idle_file" >&2
                ((skipped += 1))
                failed=1
                continue
            fi

            if process_perf_file \
                "$perf_file" \
                "$energy_pkg_base" \
                "$energy_ram_base" \
                "$num_iterations" \
                "$output_json_file"; then

                echo "[$BASHPID] Created: $output_json_file"
                ((processed += 1))
            else
                echo "Error: Failed to process $perf_file" >&2
                ((skipped += 1))
                failed=1
            fi

        done

    done < <(
        find "$prompt_dir" -mindepth 1 -maxdepth 1 \
            -type d -print0 | sort -z
    )

    echo "[$BASHPID] Finished: $prompt_dir (processed=$processed, skipped=$skipped)"

    return "$failed"
}

# --------------------------------------------------
# Worker mode: process a single prompt folder
# --------------------------------------------------
if [[ "${1:-}" == "--worker" ]]; then
    if [[ $# -ne 3 ]]; then
        echo "Usage: $0 --worker <prompt_dir> <num_iterations>" >&2
        exit 1
    fi

    process_prompt_folder "$2" "$3"
    exit $?
fi

# --------------------------------------------------
# Main mode: validate and launch parallel workers
# --------------------------------------------------
BASE_DIR=""
NUM_ITERATIONS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base_dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --num_iter)
            NUM_ITERATIONS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --base_dir <base_dir> --num_iter <num_iterations>"
            exit 1
            ;;
    esac
done

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Base directory does not exist: $BASE_DIR" >&2
    exit 1
fi

if [[ ! "$NUM_ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: num_iterations must be a positive integer." >&2
    exit 1
fi

if [[ ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: MAX_JOBS must be a positive integer." >&2
    exit 1
fi

for cmd in bc grep awk find xargs realpath; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command not found: $cmd" >&2
        exit 1
    fi
done

script_path=$(realpath "$0")

echo "Base directory: $BASE_DIR"
echo "Iterations per perf file: $NUM_ITERATIONS"
echo "Maximum concurrent prompt workers: $MAX_JOBS"

# Directory structure: BASE_DIR / MODEL / PROMPT / PROBLEM
find "$BASE_DIR" -mindepth 2 -maxdepth 2 \
    -type d -print0 |
    xargs -0 -r -P "$MAX_JOBS" -I '{}' \
        bash "$script_path" --worker '{}' "$NUM_ITERATIONS"

status=$?

if [[ $status -eq 0 ]]; then
    echo "All prompt-folder jobs completed successfully."
else
    echo "Warning: One or more prompt-folder jobs failed. Check the logs above."
fi

exit "$status"
