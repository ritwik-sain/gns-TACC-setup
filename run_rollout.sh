#!/usr/bin/env bash
# run_rollout.sh — sets rollout mode and runs a rollout using model-file.
set -euo pipefail

CONFIG="/workspace/gns/config.yaml"
SETPROG="/workspace/tacc-setup/set_config.py"

MODELFILE=""
OUTNAME="rollout"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODELFILE="$2"; shift 2 ;;
    --outname) OUTNAME="$2"; shift 2 ;;
    --data_path) edit "data.path" "$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

cp "${CONFIG}" "${CONFIG}.bak.$(date +%Y%m%dT%H%M%S)"
python3 "${SETPROG}" "${CONFIG}" "mode" "rollout"

if [ -n "${MODELFILE}" ]; then
  python3 "${SETPROG}" "${CONFIG}" "model.file" "${MODELFILE}"
fi
python3 "${SETPROG}" "${CONFIG}" "output.filename" "${OUTNAME}"
python3 "${SETPROG}" "${CONFIG}" "output.path" "/workspace/rollout/"

mkdir -p /workspace/rollout
chmod u+rw /workspace/rollout

echo "Running rollout..."
python3 -m gns.train --config-path /workspace/gns --config-name config