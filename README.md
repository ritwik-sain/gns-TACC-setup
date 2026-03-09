# Setup and Deployment Guide for `geoelements/gns` on TACC

This repository provides utilities, initialization scripts, and wrapper functions to facilitate the deployment of the [`geoelements/gns`](https://github.com/geoelements/gns/tree/v2) training and inference workflows on TACC GPU systems.


## Overview
The system requires users to configure a minimal set of **environment variables** once per shell session (or persistently in `~/.bashrc`), allowing all scripts to utilize them automatically. This repo contains the following scripts:
- `bootstrap.sh` — initializes your environment by verifying environment variables and creating required directories. Run this once after configuring your environment variables.
- `enter_container.sh` — enters the Apptainer container with proper directory binds for GPU compute nodes. Run this on a compute node before executing training/inference.
- `set_config.py` — small Python utility to set nested keys in `config.yaml` programmatically.
- `run_train.sh` — wrapper that snapshots `config.yaml`, applies config edits, and starts training.
- `run_rollout.sh` — wrapper that prepares `config.yaml` for rollout/inference and runs it.

### Prerequisites

#### 1. Clone This Repository (gns-TACC-setup)
First, clone this repository to your workspace. This contains all the setup and wrapper scripts you'll need:

```bash
git clone https://github.com/ritwik-sain/gns-TACC-setup.git
cd gns-TACC-setup
```

**Important:** Keep track of where you cloned this repository—you will run `bootstrap.sh` and `enter_container.sh` from this directory. For convenience, you may want to set an environment variable:

```bash
export GNS_SETUP_DIR="$(pwd)"  # Run this from within the gns-TACC-setup directory
```

#### 2. Clone the GNS Repository
Next, clone the main `geoelements/gns` repository to the **v2-branch**:

```bash
git clone https://github.com/geoelements/gns.git
cd gns
git checkout v2
```

#### 3. Obtain a Dataset
Download a sample dataset from the **Citations** section in the [geoelements/gns README](https://github.com/geoelements/gns/tree/v2) to use for training or inference.

---

## Required Environment Variables

Configure the following variables in your shell or add them to `~/.bashrc` before using the scripts. The paths shown below are **exemplary**—you must modify them according to your system configuration and where you have cloned the repositories and stored your datasets:

```bash
# Configure these environment variables in your login shell or before running scripts
# IMPORTANT: Update the paths below to match your local directory structure

export GNS_SETUP_DIR="${HOME}/gns-TACC-setup"        # Location where you cloned this repo
export GNS_REPO_DIR="${HOME}/gns"                    # Location of the geoelements/gns repository
export GNS_SIF_DIR="${SCRATCH}/gns-sif"              # Directory for container image
export GNS_SIF_FILE="${GNS_SIF_DIR}/gns_gpu.sif"     # Full path to the GPU-enabled SIF file
export GNS_DATA_DIR="${SCRATCH}/gns-sample"          # Directory containing your dataset
export GNS_MODELS_DIR="${SCRATCH}/gns-models"        # Directory for model checkpoints and outputs
```

**Example Directory Structure:**
```
${HOME}/
├── gns-TACC-setup/              # This repo (GNS_SETUP_DIR)
│   ├── bootstrap.sh
│   ├── enter_container.sh
│   ├── run_train.sh
│   ├── run_rollout.sh
│   ├── set_config.py
│   └── README.md
└── gns/                         # geoelements/gns repo (GNS_REPO_DIR)
    ├── config.yaml
    ├── training/
    └── ...

${SCRATCH}/
├── gns-sif/                     # Container images (GNS_SIF_DIR)
│   └── gns_gpu.sif             # (GNS_SIF_FILE)
├── gns-sample/                  # Your dataset (GNS_DATA_DIR)
│   ├── metadata.json
│   ├── train.npz
│   ├── valid.npz
│   └── test.npz
└── gns-models/                  # Outputs (GNS_MODELS_DIR)
    ├── model-NNNN.pt           # Checkpoints
    └── rollout/                 # Rollout outputs
```

**Example Configuration:**
If you cloned gns-TACC-setup to `/work/user/gns-TACC-setup` and the gns repository to `/home/user/gns`, and your dataset is stored at `/scratch/user/datasets/WaterDropSample`, your environment variables would be:

```bash
export GNS_SETUP_DIR="/work/user/gns-TACC-setup"
export GNS_REPO_DIR="/home/user/gns"
export GNS_DATA_DIR="/scratch/user/datasets/WaterDropSample"
export GNS_MODELS_DIR="/scratch/user/gns-models"
export GNS_SIF_DIR="/scratch/user/gns-sif"
export GNS_SIF_FILE="${GNS_SIF_DIR}/gns_gpu.sif"
```

---

## Initial Setup: Getting the Container Image (One-Time Only)

**Note:** This section is required only for the initial setup. If you have already pulled the container image in a previous session, proceed directly to the "Setup: Running Bootstrap" section.

Before proceeding with bootstrap, you need to pull the Apptainer container image. This **one-time setup** requires `apptainer` to be available, which is only accessible on TACC compute nodes. **Ensure your environment variables are configured (see section above) before proceeding.**

1. **Request a compute node** on TACC
2. **Load the Apptainer module:**
   ```bash
   module load tacc-apptainer
   ```
3. **Pull the official GNS container image** (based on the [geoelements/gns Container Setup Guide](https://github.com/geoelements/gns/tree/v2)):
   ```bash
   cd ${GNS_REPO_DIR}  # Navigate to your cloned gns repository
   apptainer pull docker://ghcr.io/geoelements/gns:gpu
   ```
   This will create a `gns_gpu.sif` file in your current directory.

4. **Move the SIF file to the configured location:**
   ```bash
   mv gns_gpu.sif ${GNS_SIF_FILE}
   ```

5. **(Optional) Test the container:**
   ```bash
   apptainer shell --nv ${GNS_SIF_FILE}
   ```
   You can exit the container with `exit`.

---

## Setup: Running Bootstrap

After the container image is in place and environment variables are configured, run the bootstrap script **from your login node** and from within the gns-TACC-setup directory:

```bash
cd ${GNS_SETUP_DIR}  # Navigate to the gns-TACC-setup directory
./bootstrap.sh
```

The `bootstrap.sh` script will:
- Verify that all required environment variables are properly set.
- Create the necessary directories (`GNS_SIF_DIR`, `GNS_DATA_DIR`, `GNS_MODELS_DIR`).
- Verify the SIF file exists at `${GNS_SIF_FILE}` (or attempt to pull it if apptainer is available).

---

## Running Training or Inference Workflows

After bootstrap completes successfully, you are ready to run training or inference. To do so, you must request an interactive GPU compute node on the TACC supercomputer.

### Request an Interactive GPU Node

Request an interactive node allocation (example for H100 nodes on Stampede3):

```bash
idev -p h100 -N 1 -n 1 -t 01:00:00
```

Adjust the parameters as needed:
- `-p h100` — request H100 GPU nodes (or use a different partition available on your system)
- `-N 1` — request 1 node
- `-n 1` — request 1 task
- `-t 01:00:00` — request 1 hour of walltime (modify as needed for your job)

### Enter the Container

Once on the compute node, navigate to your gns-TACC-setup directory and enter the Apptainer container:

```bash
cd ${GNS_SETUP_DIR}  # Navigate to where you cloned gns-TACC-setup
./enter_container.sh
```

Inside the container, the following directories are bound and available:
- `/workspace/gns` — the cloned geoelements/gns repository (`${GNS_REPO_DIR}`)
- `/workspace/dataset` — your training dataset (`${GNS_DATA_DIR}`)
- `/workspace/models` — for model checkpoints and outputs (`${GNS_MODELS_DIR}`)
- `/workspace/tacc-setup` — this gns-TACC-setup repository (contains run_train.sh, run_rollout.sh, etc.)

### Running Training

To start a training job, use the `run_train.sh` script with your desired hyperparameters:

```bash
/workspace/tacc-setup/run_train.sh --steps 200 --save_steps 100 --batch 2
```

This script will:
- Modify the configuration in `/workspace/gns/config.yaml` based on your parameters
- Backup the original config (see config.bak.* files)
- Start training using the gns training module

Common parameters:
- `--steps` — total number of training steps
- `--save_steps` — save model checkpoint every N steps
- `--batch` — batch size
- `--model_path` — path to the models directory
- `--resume` — BOOLEAN for resuming training
- `--model` — model filename to resume training from
- `--output_path` — path to the rollout outputs directory
- `--output_filename` — rollout output filename
- Additional parameters are documented in the script

### Running Inference/Rollout

To run inference (rollout) on trained models, use the `run_rollout.sh` script:

```bash
/workspace/tacc-setup/run_rollout.sh --model model-44000.pt --outname rollout_44000
```

Parameters:
- `--model` — the trained model file to use (from `/workspace/models`)
- `--outname` — name for the output directory/file

Rollout output is written to `/workspace/rollout/` inside the container, which is bound to `${GNS_MODELS_DIR}` on the host system. You can reference trained models located in `/workspace/models`.

---

## Additional Information

### Workflow Summary

Here's the complete workflow from start to finish:

1. **Clone both repositories** (on your login node):
   ```bash
   git clone https://github.com/geoelements/gns-TACC-setup.git
   git clone https://github.com/geoelements/gns.git && cd gns && git checkout v2
   ```

2. **Configure environment variables** in `~/.bashrc`:
   ```bash
   export GNS_SETUP_DIR="${HOME}/gns-TACC-setup"
   export GNS_REPO_DIR="${HOME}/gns"
   export GNS_SIF_DIR="${SCRATCH}/gns-sif"
   export GNS_SIF_FILE="${GNS_SIF_DIR}/gns_gpu.sif"
   export GNS_DATA_DIR="${SCRATCH}/gns-data"
   export GNS_MODELS_DIR="${SCRATCH}/gns-models"
   ```

3. **Run bootstrap** (on compute node with apptainer, or on login node if SIF exists):
   ```bash
   cd ${GNS_SETUP_DIR}
   ./bootstrap.sh
   ```

4. **Request compute node** and enter container:
   ```bash
   idev -p h100 -N 1 -n 1 -t 01:00:00
   cd ${GNS_SETUP_DIR}
   ./enter_container.sh
   ```

5. **Run training or inference** (inside container):
   ```bash
   /workspace/tacc-setup/run_train.sh --steps 1000 --batch 2
   # or
   /workspace/tacc-setup/run_rollout.sh --model model-1000.pt --outname rollout
   ```

### Pre-Training Checklist

Before running training or inference:
1. ✓ **Clone both repositories** — gns-TACC-setup and geoelements/gns
2. ✓ **Configure environment variables** — update paths in `~/.bashrc`
3. ✓ **Populate your dataset** — download and place files (`metadata.json`, `train.npz`, `valid.npz`, etc.) into `${GNS_DATA_DIR}`
4. ✓ **Prepare configuration** — ensure `config.yaml` exists and is configured in `${GNS_REPO_DIR}` (see [geoelements/gns documentation](https://github.com/geoelements/gns/tree/v2))
5. ✓ **Run bootstrap** — initialize directories and container image via `${GNS_SETUP_DIR}/bootstrap.sh`

---

## Citation

If you use this code in published work, please cite:

```
Setup and Deployment Guide for geoelements/gns on TACC
https://github.com/ritwik-sain/gns-TACC-setup.git
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
