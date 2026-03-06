#!/usr/bin/env bash
# enter_container.sh — starts an apptainer shell with canonical binds (reads env vars).
# Usage: ./enter_container.sh
set -euo pipefail

# Verify that required environment variables are set
for var in GNS_REPO_DIR GNS_SIF_FILE GNS_DATA_DIR GNS_MODELS_DIR; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set. Please configure the required environment variables as documented in README.md."
    exit 1
  fi
done

echo "Using:"
echo "  REPO = ${GNS_REPO_DIR}"
echo "  SIF  = ${GNS_SIF_FILE}"
echo "  DATA = ${GNS_DATA_DIR}"
echo "  MODELS = ${GNS_MODELS_DIR}"
echo

if [ ! -d "${GNS_REPO_DIR}" ]; then
  echo "Error: repository directory not found: ${GNS_REPO_DIR}"
  echo "Please clone the gns repo to that path or set GNS_REPO_DIR to the clone location."
  exit 2
fi

if [ ! -f "${GNS_SIF_FILE}" ]; then
  echo "Error: SIF image not found at ${GNS_SIF_FILE}"
  echo "Either run bootstrap.sh on a node with apptainer or copy a SIF to that path."
  exit 3
fi

if [ ! -d "${GNS_DATA_DIR}" ]; then
  echo "Warning: data dir not found: ${GNS_DATA_DIR}"
  echo "Please place the WaterDropSample dataset there (metadata.json, train/valid/test .npz)."
  read -p "Continue anyway? (y/n) " ans
  case "$ans" in [Yy]*) ;; *) echo "Aborting"; exit 4 ;; esac
fi

# Construct bind string
# Bind gns repo, dataset, models, and this script directory (for run_train.sh, run_rollout.sh, set_config.py)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIND="${GNS_REPO_DIR}:/workspace/gns,${GNS_DATA_DIR}:/workspace/dataset,${GNS_MODELS_DIR}:/workspace/models,${SCRIPT_DIR}:/workspace/tacc-setup"

echo "Starting Apptainer shell with binds:"
echo "  ${BIND}"
echo

apptainer shell --nv --bind "${BIND}" "${GNS_SIF_FILE}"