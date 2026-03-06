#!/usr/bin/env bash
# bootstrap.sh — create recommended directories and attempt to fetch the published Apptainer image.
set -euo pipefail

# Verify that required environment variables are set
for var in GNS_REPO_DIR GNS_SIF_DIR GNS_SIF_FILE GNS_DATA_DIR GNS_MODELS_DIR; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set. Please configure the required environment variables as documented in README.md."
    exit 1
  fi
done

echo "Bootstrap: using"
echo "  GNS_REPO_DIR = ${GNS_REPO_DIR}"
echo "  GNS_SIF_FILE = ${GNS_SIF_FILE}"
echo "  GNS_DATA_DIR = ${GNS_DATA_DIR}"
echo "  GNS_MODELS_DIR = ${GNS_MODELS_DIR}"
echo

mkdir -p "${GNS_SIF_DIR}" "${GNS_DATA_DIR}" "${GNS_MODELS_DIR}"
echo "Created directories (if missing)."

if command -v apptainer >/dev/null 2>&1; then
  if [ ! -f "${GNS_SIF_FILE}" ]; then
    echo "Apptainer available — pulling official GNS image to ${GNS_SIF_FILE}..."
    set +e
    apptainer pull "${GNS_SIF_FILE}" docker://ghcr.io/geoelements/gns:gpu
    RC=$?
    set -e
    if [ $RC -ne 0 ]; then
      echo "Warning: apptainer pull failed (RC=${RC}). Copy a SIF to ${GNS_SIF_FILE} manually if needed."
    else
      echo "Pulled SIF successfully."
    fi
  else
    echo "SIF already exists at ${GNS_SIF_FILE}."
  fi
else
  echo "Apptainer not found in PATH on this node. On compute nodes, load tacc-apptainer and run apptainer pull or copy a SIF into ${GNS_SIF_FILE}."
fi

echo
echo "Bootstrap complete. Place dataset files (metadata.json, train.npz, valid.npz, ...) in ${GNS_DATA_DIR}."
echo "Clone the gns repo into ${GNS_REPO_DIR} if not already present."