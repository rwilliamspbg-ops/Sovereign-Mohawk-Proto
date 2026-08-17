#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPLICAS_LIST="${REPLICAS_LIST:-100,300,500}"
NAMESPACE="${NAMESPACE:-scale-test}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/results/go-live/evidence}"
WINDOW_SECONDS="${WINDOW_SECONDS:-30}"

export REPLICAS_LIST NAMESPACE OUT_DIR WINDOW_SECONDS

bash "$ROOT_DIR/scripts/run_kind_scale_matrix.sh"
bash "$ROOT_DIR/scripts/collect_kind_scale_latency.sh"

echo "[scale-evidence] completed. Outputs under $ROOT_DIR/results/go-live/evidence"
