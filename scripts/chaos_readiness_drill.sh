#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-tpm-metrics}"
REPORT_DIR="${2:-chaos-reports}"
RECOVERY_LATENCY_MAX_SECONDS="${RECOVERY_LATENCY_MAX_SECONDS:-90}"

case "$SCENARIO" in
  tpm-metrics|orchestrator|prometheus|grafana)
    ;;
  *)
    echo "unsupported scenario: $SCENARIO" >&2
    echo "supported scenarios: tpm-metrics | orchestrator | prometheus | grafana" >&2
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
  prometheus)
    TARGET_INSTANCE=""
    ;;
  grafana)
    TARGET_INSTANCE=""
    ;;
esac

mkdir -p "$REPORT_DIR"

BASELINE_REPORT="$REPORT_DIR/${SCENARIO}-baseline.json"
FAILURE_REPORT="$REPORT_DIR/${SCENARIO}-failure.json"
RECOVERY_REPORT="$REPORT_DIR/${SCENARIO}-recovery.json"
SUMMARY_REPORT="$REPORT_DIR/${SCENARIO}-summary.json"

run_gate() {
  local output_path="$1"
  shift
  python3 scripts/mainnet_readiness_gate.py \
    --min-bridge-transfers 1 \
    --min-proof-verifications 1 \
    --min-hybrid-verifications 1 \
    "$@" > "$output_path"
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

wait_prometheus_health() {
  local desired="$1"
  local deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    if curl -fsS http://localhost:9090/-/healthy >/dev/null 2>&1; then
      if [[ "$desired" == "up" ]]; then
        return 0
      fi
    else
      if [[ "$desired" == "down" ]]; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

wait_grafana_health() {
  local desired="$1"
  local deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    if curl -fsS http://localhost:3000/api/health >/dev/null 2>&1; then
      if [[ "$desired" == "up" ]]; then
        return 0
      fi
    else
      if [[ "$desired" == "down" ]]; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

echo "[chaos] scenario=$SCENARIO baseline check"
wait_grafana_health up
wait_target_state "orchestrator:9091" up
wait_target_state "tpm-metrics:9102" up
wait_target_state "pyapi-metrics-exporter:9104" up
if ! run_gate "$BASELINE_REPORT" --retries 60 --delay 2; then
  cat "$BASELINE_REPORT"
  echo "baseline readiness check failed" >&2
  exit 1
fi
cat "$BASELINE_REPORT"

echo "[chaos] scenario=$SCENARIO injecting outage"
docker compose stop "$SCENARIO"
if [[ "$SCENARIO" == "prometheus" ]]; then
  wait_prometheus_health down
elif [[ "$SCENARIO" == "grafana" ]]; then
  wait_grafana_health down
else
  wait_target_state "$TARGET_INSTANCE" down
fi

echo "[chaos] scenario=$SCENARIO expecting readiness failure"
if run_gate "$FAILURE_REPORT" --retries 6 --delay 1; then
  echo "readiness gate unexpectedly passed during outage" >&2
  cat "$FAILURE_REPORT"
  exit 1
fi
cat "$FAILURE_REPORT"

echo "[chaos] scenario=$SCENARIO recovering service"
recovery_start_epoch="$(date +%s)"
docker compose start "$SCENARIO"
if [[ "$SCENARIO" == "prometheus" ]]; then
  wait_prometheus_health up
  wait_target_state "orchestrator:9091" up
  wait_target_state "tpm-metrics:9102" up
  wait_target_state "pyapi-metrics-exporter:9104" up
elif [[ "$SCENARIO" == "grafana" ]]; then
  wait_grafana_health up
else
  wait_target_state "$TARGET_INSTANCE" up
fi

echo "[chaos] scenario=$SCENARIO validating recovery"
run_gate "$RECOVERY_REPORT" --retries 60 --delay 2
cat "$RECOVERY_REPORT"

recovery_end_epoch="$(date +%s)"
recovery_latency_seconds="$((recovery_end_epoch - recovery_start_epoch))"
recovery_latency_ok=true
if (( recovery_latency_seconds > RECOVERY_LATENCY_MAX_SECONDS )); then
  recovery_latency_ok=false
fi

cat > "$SUMMARY_REPORT" <<EOF
{
  "scenario": "$SCENARIO",
  "recovery_latency_seconds": $recovery_latency_seconds,
  "recovery_latency_threshold_seconds": $RECOVERY_LATENCY_MAX_SECONDS,
  "recovery_latency_ok": $recovery_latency_ok
}
EOF

cat "$SUMMARY_REPORT"
if [[ "$recovery_latency_ok" != true ]]; then
  echo "recovery latency exceeded threshold" >&2
  exit 1
fi

echo "[chaos] scenario=$SCENARIO completed"
