# Improving the Energy-Efficiency of LLM-generated code through Effective Prompting
Prompting strategies, energy measurement scripts and experimental results for paper: https://arxiv.org/abs/2610.02571

## Directory Structure

The repository is organized into three main directories:

### 1. Data

The `data/` directory contains the prompting strategies and datasets used in the initial and final analyses.

#### Initial Analysis

The `initial_analysis/` directory contains the prompts and datasets used in the preliminary experiments. This analysis was conducted exclusively for Python and evaluated **21 prompting strategies** for 110 problems.

It also includes the `prompt_example_format/` directory, which provides json files for each of the prompting strategy illustrating how they are structured for sample problem: LeetCode 40- Combination Sum II .

#### Final Analysis

The `final_analysis/` directory contains the prompts and datasets used in the final experiments. This analysis evaluates **8 prompting strategies** for energy-efficient code generation in Python and C++.

### 2. Energy Measurement Scripts

The `energy_measurement_scripts/` directory contains the scripts used to capture, adjust, and aggregate energy measurements for LLM-generated solutions.

The measurement pipeline includes:

1. Capturing idle and execution energy measurements.
2. Adjusting measurements to account for idle energy consumption and normalizing by the number of execution iterations.
3. Generating CSV files for each prompting strategy containing per-problem energy and runtime summaries.

For detailed instructions, command-line arguments, and the complete measurement workflow, refer to the [`energy_measurement_scripts/README.md`](energy_measurement_scripts/README.md) file.

### 3. Results

The `results/` directory contains the experimental measurements and analysis results for the evaluated models in both Python and C++.

The results are organized to support analysis at multiple levels:

- **Prompt-level results:** CSV files containing measurements for individual problems for the respective prompting strategy, including runtime and energy consumption.
- **Algorithm-level analysis:** Graph showing aggregated results grouped by algorithm categories for each model.
- **Difficulty-level analysis:** Graph showing aggregated results grouped by problem difficulty categories for each model.


## Collaborators

This project was conducted in collaboration with the following contributors:

- **[Dr. Tevfik Kosar](https://cse.buffalo.edu/faculty/tkosar/)** - University at Buffalo, Buffalo, NY, USA
- **[Dr. Bing Zhang](https://github.com/bingzhang)** - National Center for Supercomputing Applications, Urbana, IL, USA
- **[Md Arman Islam]()** -University at Buffalo, Buffalo, NY, USA
- **[Jaya Krishna Pasham](https://github.com/jayakrishna855)** - University at Buffalo, Buffalo, NY, USA
- **[Yeswanth Chitturi](https://github.com/s1th883)** - University at Buffalo, Buffalo, NY, USA
- **[Akshay Paramesha]()** - University at Buffalo, Buffalo, NY, USA
- **[Isha Valiveti](https://github.com/isha912)** - University at Buffalo, Buffalo, NY, USA
- **[Dr. Asif Imran](https://asif33.github.io/)** - University at Buffalo, Buffalo, NY, USA
- **Dr. Bekir Turkkan** - IBM Research, Yorktown Heights, NY, USA
