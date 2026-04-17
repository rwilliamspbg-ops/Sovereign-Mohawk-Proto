#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dataset="${DATASET:-${1:-}}"
input_csv="${INPUT_CSV:-}"
label_column="${LABEL_COLUMN:-}"
output="${OUTPUT:-results/demo/synthesize_bio/training_report.json}"

if [[ -z "${dataset}" && -z "${input_csv}" ]]; then
	cat >&2 <<'EOF'
usage: DATASET=<dataset-url-or-uuid> [LABEL_COLUMN=name] [OUTPUT=path] ./scripts/run_synthesizebio_demo.sh
   or: INPUT_CSV=<path-to-export.csv> [LABEL_COLUMN=name] [OUTPUT=path] ./scripts/run_synthesizebio_demo.sh
EOF
	exit 1
fi

args=()
if [[ -n "${input_csv}" ]]; then
	args+=(--input-csv "${input_csv}")
else
	args+=("${dataset}")
fi

if [[ -n "${label_column}" ]]; then
	args+=(--label-column "${label_column}")
fi

args+=(--output "${output}")

cd "${repo_root}"
python3 scripts/train_synthesize_dataset.py "${args[@]}"
