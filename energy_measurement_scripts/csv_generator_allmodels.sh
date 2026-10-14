#!/usr/bin/env bash

set -euo pipefail

MAX_JOBS=20

# --------------------------------------------------
# Worker: process one experiment-type (prompt) folder
# --------------------------------------------------
process_exptype() {
    local exptype="$1"
    local model_dir
    local exptype_name
    local csv_file

    model_dir=$(dirname "$exptype")
    exptype_name=$(basename "$exptype")
    csv_file="${model_dir}/${exptype_name}.csv"

    echo "[$BASHPID] Processing: $model_dir/$exptype_name"

    # Prepare CSV header
    local header="problem_number"
    local sol

    for sol in {1..10}; do
        header="${header},runtime_sol${sol},total_energy_sol${sol}"
    done

    header="${header},num_values,highest_energy,lowest_energy,average_total_energy,coefficient_of_variability"
    echo "$header" > "$csv_file"

    # Process every problem folder
    while IFS= read -r -d '' problem_dir; do
        local problem_number
        problem_number=$(basename "$problem_dir")

        local row="$problem_number"
        local -a total_energy_values=()
        local max=""
        local min=""

        for sol in {1..10}; do
            local -a json_files=()

            mapfile -d '' -t json_files < <(
                find "$problem_dir" -type f \
                    -name "${sol}_run_*_adjusted.json" -print0 |
                    sort -z
            )

            if [[ ${#json_files[@]} -gt 0 ]]; then
                local runtime_sum=0
                local energy_pkg_sum=0
                local energy_ram_sum=0
                local count=0

                local json_file
                for json_file in "${json_files[@]}"; do
                    local runtime energy_pkg energy_ram

                    read -r runtime energy_pkg energy_ram < <(
                        jq -r '[
                            .runtime_1_run,
                            .adjusted_energy_pkg_for_1_run,
                            .adjusted_energy_ram_for_1_run
                        ] | @tsv' "$json_file"
                    )

                    runtime_sum=$(echo "$runtime_sum + $runtime" | bc -l)
                    energy_pkg_sum=$(echo "$energy_pkg_sum + $energy_pkg" | bc -l)
                    energy_ram_sum=$(echo "$energy_ram_sum + $energy_ram" | bc -l)
                    ((count += 1))
                done

                local avg_runtime avg_energy_pkg avg_energy_ram total_energy

                avg_runtime=$(echo "scale=10; $runtime_sum / $count" | bc -l)
                avg_energy_pkg=$(echo "scale=10; $energy_pkg_sum / $count" | bc -l)
                avg_energy_ram=$(echo "scale=10; $energy_ram_sum / $count" | bc -l)

                total_energy=$(echo "$avg_energy_pkg + $avg_energy_ram" | bc -l)

                row="${row},${avg_runtime},${total_energy}"
                total_energy_values+=("$total_energy")

                if [[ -z "$min" ]] || [[ $(echo "$total_energy < $min" | bc -l) -eq 1 ]]; then
                    min=$total_energy
                fi

                if [[ -z "$max" ]] || [[ $(echo "$total_energy > $max" | bc -l) -eq 1 ]]; then
                    max=$total_energy
                fi
            else
                row="${row},,"
                total_energy_values+=("")
            fi
        done

        # Calculate aggregate statistics
        local sum=0
        local num_values=0
        local val

        for val in "${total_energy_values[@]}"; do
            if [[ -n "$val" ]]; then
                sum=$(echo "$sum + $val" | bc -l)
                ((num_values += 1))
            fi
        done

        local avg="" sd="" cv=""

        if (( num_values > 0 )); then
            avg=$(echo "scale=10; $sum / $num_values" | bc -l)

            local sum_sq_diff=0
            for val in "${total_energy_values[@]}"; do
                if [[ -n "$val" ]]; then
                    local diff sq_diff

                    diff=$(echo "$val - $avg" | bc -l)
                    sq_diff=$(echo "$diff * $diff" | bc -l)
                    sum_sq_diff=$(echo "$sum_sq_diff + $sq_diff" | bc -l)
                fi
            done

            # Population standard deviation, matching the original script
            sd=$(echo "scale=10; sqrt($sum_sq_diff / $num_values)" | bc -l)

            if [[ $(echo "$avg != 0" | bc -l) -eq 1 ]]; then
                cv=$(echo "scale=4; ($sd / $avg) * 100" | bc -l)
            fi
        fi

        row="${row},${num_values},${max},${min},${avg},${cv}"
        echo "$row" >> "$csv_file"

    done < <(
        find "$exptype" -mindepth 1 -maxdepth 1 \
            -type d -print0 | sort -z
    )

    echo "[$BASHPID] Created: $csv_file"
}

# --------------------------------------------------
# Worker mode: process a single prompt folder
# --------------------------------------------------
if [[ "${1:-}" == "--worker" ]]; then
    process_exptype "$2"
    exit $?
fi

# --------------------------------------------------
# Main mode: validate input and dispatch parallel jobs
# --------------------------------------------------
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path_to_base_folder>"
    exit 1
fi

base_dir="$1"

if [[ ! -d "$base_dir" ]]; then
    echo "Error: directory '$base_dir' does not exist."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1 ||
   ! command -v bc >/dev/null 2>&1; then
    echo "Error: both jq and bc must be installed."
    exit 1
fi

if ! command -v xargs >/dev/null 2>&1; then
    echo "Error: xargs is required."
    exit 1
fi

# Resolve script path so child workers can invoke this script.
script_path=$(realpath "$0")

echo "Base directory: $base_dir"
echo "Maximum concurrent prompt folders: $MAX_JOBS"

# Find model directories, then each model's prompt directories.
# Each prompt folder is dispatched as an independent job.
find "$base_dir" -mindepth 2 -maxdepth 2 -type d -print0 |
    xargs -0 -r -P "$MAX_JOBS" -I '{}' \
        bash "$script_path" --worker '{}'

status=$?

if [[ $status -eq 0 ]]; then
    echo "All prompt-folder jobs completed."
else
    echo "Warning: one or more worker jobs failed."
fi

exit "$status"
