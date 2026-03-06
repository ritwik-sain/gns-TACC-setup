#!/usr/bin/env bash
# run_train.sh — wrapper that snapshots config, applies many possible edits via set_config.py, then runs training.
# Usage example:
#  ./scripts/run_train.sh --steps 50000 --save_steps 2000 --batch 2 --lr_init 1e-4 --lr_decay 0.1 --lr_decay_steps 50000 --noise_std 0.00067 --input_seq 6 --num_types 9 --kin_id 3 --model model-44000.pt --resume true
set -euo pipefail

CONFIG="/workspace/gns/config.yaml"
SETPROG="/workspace/tacc-setup/set_config.py"

if [ ! -f "${CONFIG}" ]; then
  echo "Config not found at ${CONFIG}"
  exit 2
fi

# helper function
edit() {
  local key="$1"; local val="$2"
  python3 "${SETPROG}" "${CONFIG}" "${key}" "${val}"
}

# default values (empty)
STEPS=""
SAVE_STEPS=""
BATCH=""
LR_INIT=""
LR_DECAY=""
LR_DECAY_STEPS=""
NOISE_STD=""
INPUT_SEQ=""
NUM_TYPES=""
KIN_ID=""
MODELFILE=""
MODELPATH=""
RESUME=""
DATA_PATH=""
OUTPUT_PATH=""
OUTPUT_FILENAME=""
CUDA_DEVICE=""
TENSORBOARD_DIR=""

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --steps) STEPS="$2"; shift 2 ;;
    --save_steps) SAVE_STEPS="$2"; shift 2 ;;
    --batch) BATCH="$2"; shift 2 ;;
    --lr_init) LR_INIT="$2"; shift 2 ;;
    --lr_decay) LR_DECAY="$2"; shift 2 ;;
    --lr_decay_steps) LR_DECAY_STEPS="$2"; shift 2 ;;
    --noise_std) NOISE_STD="$2"; shift 2 ;;
    --input_seq) INPUT_SEQ="$2"; shift 2 ;;
    --num_types) NUM_TYPES="$2"; shift 2 ;;
    --kin_id) KIN_ID="$2"; shift 2 ;;
    --model) MODELFILE="$2"; shift 2 ;;
    --model_path) MODELPATH="$2"; shift 2 ;;
    --resume) RESUME="$2"; shift 2 ;;
    --data_path) DATA_PATH="$2"; shift 2 ;;
    --output_path) OUTPUT_PATH="$2"; shift 2 ;;
    --output_filename) OUTPUT_FILENAME="$2"; shift 2 ;;
    --cuda_device) CUDA_DEVICE="$2"; shift 2 ;;
    --tensorboard_dir) TENSORBOARD_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# backup config
cp "${CONFIG}" "${CONFIG}.bak.$(date +%Y%m%dT%H%M%S)"
echo "Backed up config to ${CONFIG}.bak.*"

# apply edits (only when provided)
[ -n "${STEPS}" ] && edit "training.steps" "${STEPS}"
[ -n "${SAVE_STEPS}" ] && edit "training.save_steps" "${SAVE_STEPS}"
[ -n "${BATCH}" ] && edit "data.batch_size" "${BATCH}"
[ -n "${LR_INIT}" ] && edit "training.learning_rate.initial" "${LR_INIT}"
[ -n "${LR_DECAY}" ] && edit "training.learning_rate.decay" "${LR_DECAY}"
[ -n "${LR_DECAY_STEPS}" ] && edit "training.learning_rate.decay_steps" "${LR_DECAY_STEPS}"
[ -n "${NOISE_STD}" ] && edit "data.noise_std" "${NOISE_STD}"
[ -n "${INPUT_SEQ}" ] && edit "data.input_sequence_length" "${INPUT_SEQ}"
[ -n "${NUM_TYPES}" ] && edit "data.num_particle_types" "${NUM_TYPES}"
[ -n "${KIN_ID}" ] && edit "data.kinematic_particle_id" "${KIN_ID}"
[ -n "${MODELFILE}" ] && edit "model.file" "${MODELFILE}"
[ -n "${MODELPATH}" ] && edit "model.path" "${MODELPATH}"
[ -n "${RESUME}" ] && edit "training.resume" "${RESUME}"
[ -n "${DATA_PATH}" ] && edit "data.path" "${DATA_PATH}"
[ -n "${OUTPUT_PATH}" ] && edit "output.path" "${OUTPUT_PATH}"
[ -n "${OUTPUT_FILENAME}" ] && edit "output.filename" "${OUTPUT_FILENAME}"
[ -n "${CUDA_DEVICE}" ] && edit "hardware.cuda_device_number" "${CUDA_DEVICE}"
[ -n "${TENSORBOARD_DIR}" ] && edit "logging.tensorboard_dir" "${TENSORBOARD_DIR}"

echo "Starting training with updated config..."
python3 -m gns.train --config-path /workspace/gns --config-name config mode=train