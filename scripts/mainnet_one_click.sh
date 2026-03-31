#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
COMPOSE_CMD="$ROOT_DIR/scripts/docker-compose-wrapper.sh"

REPORT_JSON="results/readiness/one-click-pipeline-report.json"
REPORT_MD="results/readiness/one-click-pipeline-report.md"
STEP_LOG="results/readiness/one-click-steps.log"
PIPELINE_STATUS="running"
CURRENT_STEP="bootstrap"
PIPELINE_STARTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p runtime-secrets results/readiness chaos-reports
: > "$STEP_LOG"

finalize_report() {
  local finished_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local go_version="unknown"
  local compile_version="unknown"
  local goroot_value="unknown"
  if command -v go >/dev/null 2>&1; then
    go_info="$(bash -c 'gv="$(scripts/go_with_toolchain.sh go env GOVERSION 2>/dev/null || true)"; gr="$(scripts/go_with_toolchain.sh go env GOROOT 2>/dev/null || true)"; td="$(scripts/go_with_toolchain.sh go env GOTOOLDIR 2>/dev/null || true)"; cv=""; if [[ -n "$td" && -x "$td/compile" ]]; then cv="$($td/compile -V=full 2>/dev/null | grep -o "go[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?" | head -n1 || true)"; fi; printf "%s|%s|%s" "$gv" "$gr" "$cv"')"
    go_version="$(printf '%s' "$go_info" | cut -d'|' -f1)"
    goroot_value="$(printf '%s' "$go_info" | cut -d'|' -f2)"
    compile_version="$(printf '%s' "$go_info" | cut -d'|' -f3)"
  fi

  export REPORT_JSON REPORT_MD STEP_LOG PIPELINE_STATUS PIPELINE_STARTED_AT CURRENT_STEP
  export GO_VERSION_VALUE="$go_version"
  export COMPILE_VERSION_VALUE="$compile_version"
  export GOROOT_VALUE="$goroot_value"
  export FINISHED_AT_VALUE="$finished_at"

  python3 - <<'PY'
import json
import os
from pathlib import Path

report_json = Path(os.environ["REPORT_JSON"])
report_md = Path(os.environ["REPORT_MD"])
step_log = Path(os.environ["STEP_LOG"])

steps = []
if step_log.exists():
  for line in step_log.read_text(encoding="utf-8").splitlines():
    if not line.strip():
      continue
    parts = line.split("|", 4)
    if len(parts) != 5:
      continue
    steps.append(
      {
        "index": int(parts[0]),
        "name": parts[1],
        "status": parts[2],
        "duration_seconds": float(parts[3]),
        "command": parts[4],
      }
    )

payload = {
  "ok": os.environ["PIPELINE_STATUS"] == "pass",
  "status": os.environ["PIPELINE_STATUS"],
  "started_at": os.environ["PIPELINE_STARTED_AT"],
  "finished_at": os.environ["FINISHED_AT_VALUE"],
  "failed_step": None if os.environ["PIPELINE_STATUS"] == "pass" else os.environ["CURRENT_STEP"],
  "go": {
    "go_version": os.environ.get("GO_VERSION_VALUE", ""),
    "compile_version": os.environ.get("COMPILE_VERSION_VALUE", ""),
    "goroot": os.environ.get("GOROOT_VALUE", ""),
    "toolchain_aligned": bool(os.environ.get("GO_VERSION_VALUE", "")) and os.environ.get("GO_VERSION_VALUE", "") == os.environ.get("COMPILE_VERSION_VALUE", ""),
  },
  "artifacts": {
    "readiness_report": "results/readiness/readiness-report.json",
    "readiness_digest": "results/readiness/readiness-digest.md",
    "chaos_summary": "chaos-reports/tpm-metrics-summary.json",
  },
  "steps": steps,
}

report_json.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

lines = [
  "# One-Click Pipeline Report",
  "",
  f"- Status: **{payload['status'].upper()}**",
  f"- Started: {payload['started_at']}",
  f"- Finished: {payload['finished_at']}",
  f"- Failed step: {payload['failed_step']}",
  "",
  "## Go Toolchain",
  "",
  f"- Go version: `{payload['go']['go_version']}`",
  f"- Compile version: `{payload['go']['compile_version']}`",
  f"- GOROOT: `{payload['go']['goroot']}`",
  f"- Aligned: `{payload['go']['toolchain_aligned']}`",
  "",
  "## Steps",
  "",
]
for step in steps:
  lines.append(f"- [{step['status']}] {step['index']}. {step['name']} ({step['duration_seconds']:.2f}s)")
lines.extend([
  "",
  "## Artifacts",
  "",
  f"- {payload['artifacts']['readiness_report']}",
  f"- {payload['artifacts']['chaos_summary']}",
  f"- {payload['artifacts']['readiness_digest']}",
])
report_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

trap 'if [[ "$PIPELINE_STATUS" == "running" ]]; then PIPELINE_STATUS="fail"; fi; finalize_report' EXIT

run_step() {
  local step_index="$1"
  local step_name="$2"
  local step_cmd="$3"
  CURRENT_STEP="$step_name"
  printf '\n[%s/9] %s\n' "$step_index" "$step_name"
  local start_ts="$(date +%s.%N)"
  set +e
  bash -c "$step_cmd"
  local rc=$?
  set -e
  local end_ts="$(date +%s.%N)"
  local duration
  duration="$(python3 - <<PY
start = float("$start_ts")
end = float("$end_ts")
print(max(0.0, end - start))
PY
)"
  if [[ $rc -ne 0 ]]; then
  echo "${step_index}|${step_name}|FAIL|${duration}|${step_cmd}" >> "$STEP_LOG"
  PIPELINE_STATUS="fail"
  return $rc
  fi
  echo "${step_index}|${step_name}|PASS|${duration}|${step_cmd}" >> "$STEP_LOG"
}

export MOHAWK_TRANSPORT_KEX_MODE="${MOHAWK_TRANSPORT_KEX_MODE:-x25519-mlkem768-hybrid}"
export MOHAWK_TPM_IDENTITY_SIG_MODE="${MOHAWK_TPM_IDENTITY_SIG_MODE:-xmss}"
export MOHAWK_PQC_MIGRATION_ENABLED="${MOHAWK_PQC_MIGRATION_ENABLED:-true}"
export MOHAWK_PQC_LOCK_LEGACY_TRANSFERS="${MOHAWK_PQC_LOCK_LEGACY_TRANSFERS:-true}"
export MOHAWK_PQC_MIGRATION_ETA="${MOHAWK_PQC_MIGRATION_ETA:-2027-12-31T00:00:00Z}"
export MOHAWK_PQC_MIGRATION_EPOCH="${MOHAWK_PQC_MIGRATION_EPOCH:-2027-12-31T00:00:00Z}"
export MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH="${MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH:-true}"
export MOHAWK_API_AUTH_MODE="${MOHAWK_API_AUTH_MODE:-file-only}"
export MOHAWK_API_ENFORCE_ROLES="${MOHAWK_API_ENFORCE_ROLES:-true}"
export MOHAWK_HOST_PREFLIGHT_MODE="${MOHAWK_HOST_PREFLIGHT_MODE:-strict}"

RUNTIME_ACCELERATOR_BACKEND="${MOHAWK_ACCELERATOR_BACKEND:-auto}"
RUNTIME_GRADIENT_FORMAT="${MOHAWK_GRADIENT_FORMAT:-int8}"

if [[ ! -s runtime-secrets/mohawk_api_token ]]; then
  python3 - <<'PY'
import os
import secrets
from pathlib import Path

path = Path("runtime-secrets/mohawk_api_token")
path.write_text(secrets.token_hex(24), encoding="utf-8")
os.chmod(path, 0o600)
print(f"created {path}")
PY
fi

if [[ ! -s runtime-secrets/mohawk_tpm_ca_cert.pem || ! -s runtime-secrets/mohawk_tpm_ca_key.pem ]]; then
  openssl req -x509 -newkey rsa:3072 \
    -keyout runtime-secrets/mohawk_tpm_ca_key.pem \
    -out runtime-secrets/mohawk_tpm_ca_cert.pem \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
  echo "created shared TPM CA cert/key under runtime-secrets/"
fi

run_step 1 "Go 1.25 toolchain alignment" "source scripts/ensure_go_toolchain.sh"
run_step 2 "Host kernel network preflight" "if [[ \"$MOHAWK_HOST_PREFLIGHT_MODE\" == \"strict\" ]]; then ./scripts/validate_host_network_tuning.sh; else ./scripts/validate_host_network_tuning.sh || echo '[host-preflight] advisory mode: continuing despite host tuning warnings'; fi"
run_step 3 "Static gates (capabilities + PQC contract)" "python3 scripts/validate_capabilities.py && python3 scripts/validate_pqc_contract_ready.py"
run_step 4 "Build + tests + strict auth smoke" "unset MOHAWK_ACCELERATOR_BACKEND MOHAWK_GRADIENT_FORMAT || true; make production-readiness"
run_step 5 "Python SDK regression" "unset MOHAWK_API_AUTH_MODE MOHAWK_API_TOKEN_FILE MOHAWK_API_ENFORCE_ROLES MOHAWK_API_BRIDGE_ALLOWED_ROLES MOHAWK_API_HYBRID_ALLOWED_ROLES || true; cd sdk/python && python3 -m pytest tests/test_client.py"
run_step 6 "Boot observability + control plane stack" "export MOHAWK_ACCELERATOR_BACKEND=\"$RUNTIME_ACCELERATOR_BACKEND\"; export MOHAWK_GRADIENT_FORMAT=\"$RUNTIME_GRADIENT_FORMAT\"; \"$COMPOSE_CMD\" up -d orchestrator tpm-metrics prometheus grafana ipfs && \"$COMPOSE_CMD\" up -d node-agent-1 node-agent-2 node-agent-3 && \"$COMPOSE_CMD\" up -d pyapi-metrics-exporter"
run_step 7 "Mainnet readiness gate" "python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 > results/readiness/readiness-report.json && cat results/readiness/readiness-report.json"
run_step 8 "Chaos readiness drill" "./scripts/chaos_readiness_drill.sh tpm-metrics chaos-reports"
run_step 9 "Readiness digest generation" "python3 scripts/generate_readiness_digest.py --readiness-report results/readiness/readiness-report.json --chaos-dir chaos-reports --output results/readiness/readiness-digest.md && python3 scripts/generate_capability_dashboard_matrix.py --output results/go-live/capability_dashboard_matrix.md"

PIPELINE_STATUS="pass"

printf '\n✅ MAINNET ONE-CLICK READY\n'
printf 'Report: results/readiness/readiness-report.json\n'
printf 'Chaos : chaos-reports/tpm-metrics-summary.json\n'
printf 'Digest: results/readiness/readiness-digest.md\n'
printf 'Pipeline JSON: %s\n' "$REPORT_JSON"
printf 'Pipeline MD  : %s\n' "$REPORT_MD"
