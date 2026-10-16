# Improving the Energy-Efficiency of LLM-generated code through Effective Prompting
Prompting strategies, datasets, energy measurement scripts and experimental results for paper: https://arxiv.org/abs/2610.02571

## Directory Structure

The repository is organized into four main directories:

### 1. Data

The `data/` directory contains the datasets used in the initial and final analyses.

### 2. Energy Measurement Scripts

The `energy_measurement_scripts/` directory contains the scripts used to capture, adjust, and aggregate energy measurements for LLM-generated solutions.

The measurement pipeline includes:

1. Capturing idle and execution energy measurements.
2. Adjusting measurements to account for idle energy consumption and normalizing by the number of execution iterations.
3. Generating CSV files for each prompting strategy containing per-problem energy and runtime summaries.

For detailed instructions, command-line arguments, and the complete measurement workflow, refer to the [`energy_measurement_scripts/README.md`](energy_measurement_scripts/README.md) file.

### 3. Prompts
This folder contains the prompts used in the initial and final analyses along with their sample usage. For detailed information about the prompts, please refer to [`prompts/README.md`](./prompts/README.md) file.

### 4. Results

The `results/` directory contains the experimental measurements and analysis results for the evaluated models in both Python and C++.

The results are organized to support analysis at multiple levels:

- **Prompt-level results:** CSV files containing measurements for individual problems for the respective prompting strategy, including runtime and energy consumption.
- **Algorithm-level analysis:** Graph showing aggregated results grouped by algorithm categories for each model.
- **Difficulty-level analysis:** Graph showing aggregated results grouped by problem difficulty categories for each model.


## Collaborators

This project was conducted in collaboration with the following contributors:

- **[Dr. Tevfik Kosar](https://cse.buffalo.edu/faculty/tkosar/)** - University at Buffalo, Buffalo, NY, USA
- **[Dr. Bing Zhang](https://github.com/bingzhang)** - National Center for Supercomputing Applications, Urbana, IL, USA
- **[Md Arman Islam](https://github.com/armanbishal)** -University at Buffalo, Buffalo, NY, USA
- **[Jaya Krishna Pasham](https://github.com/jayakrishna855)** - University at Buffalo, Buffalo, NY, USA
- **[Yeswanth Chitturi](https://github.com/s1th883)** - University at Buffalo, Buffalo, NY, USA
- **[Akshay Paramesha](https://github.com/Akshay-2001)** - University at Buffalo, Buffalo, NY, USA
- **[Isha Valiveti](https://github.com/isha912)** - University at Buffalo, Buffalo, NY, USA
- **[Dr. Asif Imran](https://asif33.github.io/)** - University at Buffalo, Buffalo, NY, USA
- **Dr. Bekir Turkkan** - IBM Research, Yorktown Heights, NY, USA
