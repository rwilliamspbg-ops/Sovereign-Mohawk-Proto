#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-tpm-metrics}"
REPORT_DIR="${2:-chaos-reports}"

case "$SCENARIO" in
  tpm-metrics|orchestrator)
    ;;
  *)
    echo "unsupported scenario: $SCENARIO" >&2
    echo "supported scenarios: tpm-metrics | orchestrator" >&2
    exit 2
    ;;
esac

TARGET_INSTANCE=""
case "$SCENARIO" in
  tpm-metrics)
    TARGET_INSTANCE="tpm-metrics:9102"
    ;;
  orchestrator)
    TARGET_INSTANCE="orchestrator:9091"
    ;;
esac

mkdir -p "$REPORT_DIR"

BASELINE_REPORT="$REPORT_DIR/${SCENARIO}-baseline.json"
FAILURE_REPORT="$REPORT_DIR/${SCENARIO}-failure.json"
RECOVERY_REPORT="$REPORT_DIR/${SCENARIO}-recovery.json"

run_gate() {
  local output_path="$1"
  shift
  python3 scripts/mainnet_readiness_gate.py "$@" > "$output_path"
}

wait_target_state() {
  local instance="$1"
  local desired_state="$2"
  python3 - "$instance" "$desired_state" <<'PY'
import json
import sys
import time
import urllib.request

instance = sys.argv[1]
desired = sys.argv[2]

deadline = time.time() + 180
while time.time() < deadline:
  try:
    with urllib.request.urlopen("http://localhost:9090/api/v1/targets", timeout=4) as response:
      payload = json.loads(response.read().decode("utf-8"))
    active = payload.get("data", {}).get("activeTargets", [])
    found = [
      target for target in active if target.get("labels", {}).get("instance") == instance
    ]
    if found and any(target.get("health") == desired for target in found):
      sys.exit(0)
  except Exception:
    pass
  time.sleep(2)

sys.exit(1)
PY
}

echo "[chaos] scenario=$SCENARIO baseline check"
wait_target_state "orchestrator:9091" up
wait_target_state "tpm-metrics:9102" up
if ! run_gate "$BASELINE_REPORT" --retries 60 --delay 2; then
  cat "$BASELINE_REPORT"
  echo "baseline readiness check failed" >&2
  exit 1
fi
cat "$BASELINE_REPORT"

echo "[chaos] scenario=$SCENARIO injecting outage"
docker compose stop "$SCENARIO"
wait_target_state "$TARGET_INSTANCE" down

echo "[chaos] scenario=$SCENARIO expecting readiness failure"
if run_gate "$FAILURE_REPORT" --retries 6 --delay 1; then
  echo "readiness gate unexpectedly passed during outage" >&2
  cat "$FAILURE_REPORT"
  exit 1
fi
cat "$FAILURE_REPORT"

echo "[chaos] scenario=$SCENARIO recovering service"
docker compose start "$SCENARIO"
wait_target_state "$TARGET_INSTANCE" up

echo "[chaos] scenario=$SCENARIO validating recovery"
run_gate "$RECOVERY_REPORT" --retries 60 --delay 2
cat "$RECOVERY_REPORT"

echo "[chaos] scenario=$SCENARIO completed"
