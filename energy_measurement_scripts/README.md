# Energy Measurements

This directory contains scripts for measuring and processing the energy consumption of LLM-generated Python and C++ solutions. The pipeline consists of three stages: capturing raw energy measurements, adjusting measurements to account for idle energy consumption, and generating per-prompt CSV summaries.

## Overview

The energy measurement pipeline follows these steps:

1. **Capture energy measurements:** Collect idle and execution energy measurements for the generated solutions.
2. **Adjust energy measurements:** Subtract idle energy consumption and normalize the measurements by the number of iterations.
3. **Generate CSV summaries:** Aggregate the adjusted measurements for each problem and prompt within each model directory.

---

## 1. Capture Energy Measurements

The first stage captures idle and execution energy measurements using the `run_energy_measurements_allmodels_<language>.sh` scripts. Separate scripts are used for Python and C++ because their generated solutions follow different directory structures.

### Directory Structure

**Python solutions**

Python solutions are organized by problem, with each generated solution stored in a separate file:

```text
<problem>/
├── <model_generation_number>.py
├── <model_generation_number>.py
└── ...
```

**C++ solutions**

C++ solutions are organized by problem and model generation, with compiled executables stored for individual test cases:

```text
<problem>/
└── <model_generation_number>/
    ├── <test_case_number>.out
    ├── <test_case_number>.out
    └── ...
```

In our experiments, `model_generation_number` is from `1`-`10`. 

### Usage

Run the appropriate script for the target language:

```bash
bash run_energy_measurements_allmodels_<language>.sh \
    -num-runs <number_of_energy_measurements> \
    --path <path_to_all_models_solutions> \
    --output <output_directory>
```

**Arguments**

| Argument | Description |
|---|---|
| `-num-runs` | Number of energy measurement runs to capture. |
| `--path` | Path containing the generated solutions for all models. |
| `--output` | Directory in which the energy measurement results will be stored. |

Replace `<language>` with the appropriate language identifier supported by the scripts, such as `python` or `cpp`.

**Output:** Raw energy measurements, including idle and execution measurements, for subsequent processing.

---

## 2. Adjust Energy Measurements

After capturing the raw measurements, run `adjusted_measurements_allmodels.sh` to calculate the adjusted energy consumption for each solution.

This stage accounts for idle energy consumption and normalizes the measurements by the number of iterations performed for each solution.

### Calculation

For each measurement run, the adjusted energy consumption per iteration is calculated as:

`Adjusted Energy = (Execution Energy - Idle Energy) / Number of Iterations`

This calculation is performed separately for CPU package energy (`energy-pkg`) and DRAM energy (`energy-ram`).

### Usage

```bash
bash adjusted_measurements_allmodels.sh \
    --base_dir <energy_measurements_directory> \
    --num_iter <number_of_iterations>
```

**Arguments**

| Argument | Description |
|---|---|
| `--base_dir` | Directory containing the raw energy measurements. |
| `--num_iter` | Number of iterations used to execute each solution. |

### Experimental Configuration

The number of iterations depends on the programming language:

| Language | Iterations per solution |
|---|---:|
| Python | 30 |
| C++ | 40 |

These iteration counts correspond to the configuration used in our experiments.

**Output:** Adjusted energy measurements json files with idle energy consumption removed and energy normalized per iteration for each energy measurement run.

---

## 3. Generate CSV Summaries

The final stage generates CSV summary files using `csv_generator_allmodels.sh`.

The script processes the adjusted measurements and generates a CSV file for each prompt within each model directory. Each CSV summarizes the energy consumption and runtime of the correct generated solutions for every problem.

### Usage

```bash
bash csv_generator_allmodels.sh <path_to_energy_measurements_directory>
```

**Argument**

| Argument | Description |
|---|---|
| `<path_to_energy_measurements_directory>` | Path to the directory containing the energy measurements to process. |

**Output:** A CSV summary file for each prompt under the corresponding model directory.

### CSV Schema

Each generated CSV contains the following columns:

| Column | Description |
|---|---|
| `problem_number` | Identifier of the problem. |
| `runtime_sol<sol_number>` | Runtime associated with a generated solution. |
| `total_energy_sol<sol_number>` | Total adjusted energy consumption associated with a generated solution. |
| `num_values` | Number of correct generated solutions available for the problem and prompt. |
| `highest_energy` | Highest total energy consumption among the included solutions. |
| `lowest_energy` | Lowest total energy consumption among the included solutions. |
| `average_total_energy` | Average total energy consumption across the included solutions. |
| `coefficient_of_variability` | Relative variability in the total energy measurements, as calculated by the script. |

The CSV contains ten runtime columns and ten corresponding total-energy columns, one pair for each solution slot, followed by the summary columns.

The number of valid measurements can vary across problems and prompts because not every generated solution is correct. The `num_values` column records the number of correct generations available for the corresponding problem and prompt.

---

## Complete Workflow

Execute the scripts in the following order:

```text
1. Capture raw energy measurements
   └── run_energy_measurements_allmodels_<language>.sh

2. Adjust energy measurements
   └── adjusted_measurements_allmodels.sh

3. Generate per-prompt CSV summaries
   └── csv_generator_allmodels.sh
```

Ensure that the energy measurement stage has completed before running the adjustment script, and that the adjusted measurements are available before generating the CSV summaries.