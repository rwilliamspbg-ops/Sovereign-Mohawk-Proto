#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export MOHAWK_TRANSPORT_KEX_MODE="${MOHAWK_TRANSPORT_KEX_MODE:-x25519-mlkem768-hybrid}"
export MOHAWK_TPM_IDENTITY_SIG_MODE="${MOHAWK_TPM_IDENTITY_SIG_MODE:-xmss}"
export MOHAWK_PQC_MIGRATION_ENABLED="${MOHAWK_PQC_MIGRATION_ENABLED:-true}"
export MOHAWK_PQC_LOCK_LEGACY_TRANSFERS="${MOHAWK_PQC_LOCK_LEGACY_TRANSFERS:-true}"
export MOHAWK_PQC_MIGRATION_ETA="${MOHAWK_PQC_MIGRATION_ETA:-2027-12-31T00:00:00Z}"
export MOHAWK_API_AUTH_MODE="${MOHAWK_API_AUTH_MODE:-file-only}"
export MOHAWK_API_ENFORCE_ROLES="${MOHAWK_API_ENFORCE_ROLES:-true}"

RUNTIME_ACCELERATOR_BACKEND="${MOHAWK_ACCELERATOR_BACKEND:-auto}"
RUNTIME_GRADIENT_FORMAT="${MOHAWK_GRADIENT_FORMAT:-int8}"

mkdir -p runtime-secrets results/readiness chaos-reports
mkdir -p runtime-secrets
if [[ ! -s runtime-secrets/mohawk_api_token ]]; then
  python3 - <<'PY'
import secrets
from pathlib import Path

path = Path("runtime-secrets/mohawk_api_token")
path.write_text(secrets.token_hex(24), encoding="utf-8")
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

printf '\n[1/8] Host kernel network preflight\n'
./scripts/validate_host_network_tuning.sh

printf '\n[2/8] Static gates (capabilities + PQC contract readiness)\n'
python3 scripts/validate_capabilities.py
python3 scripts/validate_pqc_contract_ready.py

printf '\n[3/8] Build + tests + strict auth smoke\n'
unset MOHAWK_ACCELERATOR_BACKEND || true
unset MOHAWK_GRADIENT_FORMAT || true
make production-readiness

printf '\n[4/8] Python SDK regression\n'
unset MOHAWK_API_AUTH_MODE || true
unset MOHAWK_API_TOKEN_FILE || true
unset MOHAWK_API_ENFORCE_ROLES || true
unset MOHAWK_API_BRIDGE_ALLOWED_ROLES || true
unset MOHAWK_API_HYBRID_ALLOWED_ROLES || true
cd sdk/python
pytest tests/test_client.py
cd "$ROOT_DIR"

printf '\n[5/8] Boot observability and control plane stack\n'
export MOHAWK_ACCELERATOR_BACKEND="$RUNTIME_ACCELERATOR_BACKEND"
export MOHAWK_GRADIENT_FORMAT="$RUNTIME_GRADIENT_FORMAT"
docker compose up -d orchestrator tpm-metrics prometheus grafana ipfs
docker compose up -d node-agent-1 node-agent-2 node-agent-3
docker compose up -d pyapi-metrics-exporter

printf '\n[6/8] Mainnet readiness gate\n'
python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 > results/readiness/readiness-report.json
cat results/readiness/readiness-report.json

printf '\n[7/8] Chaos readiness drill\n'
./scripts/chaos_readiness_drill.sh tpm-metrics chaos-reports

printf '\n[8/8] Readiness digest generation\n'
python3 scripts/generate_readiness_digest.py \
  --readiness-report results/readiness/readiness-report.json \
  --chaos-dir chaos-reports \
  --output results/readiness/readiness-digest.md

printf '\n✅ MAINNET ONE-CLICK READY\n'
printf 'Report: results/readiness/readiness-report.json\n'
printf 'Chaos : chaos-reports/tpm-metrics-summary.json\n'
printf 'Digest: results/readiness/readiness-digest.md\n'
