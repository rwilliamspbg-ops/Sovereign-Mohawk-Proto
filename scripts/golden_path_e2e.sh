#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/results/go-live"
JSON_REPORT="$REPORT_DIR/golden-path-report.json"
MD_REPORT="$REPORT_DIR/golden-path-report.md"

mkdir -p "$REPORT_DIR"

cd "$ROOT_DIR"

cleanup() {
  if [[ "${MOHAWK_KEEP_STACK_UP:-0}" != "1" ]]; then
    docker compose down -v >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[golden-path] ensuring runtime secrets"
mkdir -p runtime-secrets
if [[ ! -s runtime-secrets/mohawk_api_token ]]; then
  python3 -c 'import pathlib, secrets; pathlib.Path("runtime-secrets/mohawk_api_token").write_text(secrets.token_hex(24), encoding="utf-8")'
fi
if [[ ! -s runtime-secrets/mohawk_tpm_ca_cert.pem || ! -s runtime-secrets/mohawk_tpm_ca_key.pem ]]; then
  openssl req -x509 -newkey rsa:3072 \
    -keyout runtime-secrets/mohawk_tpm_ca_key.pem \
    -out runtime-secrets/mohawk_tpm_ca_cert.pem \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
fi

echo "[golden-path] starting stack"
docker compose up -d --build orchestrator prometheus tpm-metrics pyapi-metrics-exporter grafana ipfs node-agent-1 node-agent-2 node-agent-3 shard-us-east shard-eu-west

echo "[golden-path] waiting for monitoring endpoints"
healthy=0
for _ in $(seq 1 90); do
  if curl -fsS http://localhost:9090/-/healthy >/dev/null 2>&1 && curl -fsS http://localhost:3000/api/health >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "$healthy" -ne 1 ]]; then
  echo "[golden-path] monitoring stack did not become healthy in time"
  exit 1
fi

echo "[golden-path] readiness gate"
python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 --min-bridge-transfers 1 --min-proof-verifications 1 --min-hybrid-verifications 1 > results/readiness/readiness-report.json

echo "[golden-path] integration and runtime checks"
docker exec tpm-metrics sh -lc "cd /workspace && /usr/local/go/bin/go test ./internal -run 'TestProcessGradientBatchWithMultiKrum|TestProcessGradientBatchWithoutMultiKrum|TestMultiKrumSelect|TestMultiKrumAggregate' -count=1" >/tmp/mohawk_golden_internal_tests.log
docker exec tpm-metrics sh -lc "cd /workspace && /usr/local/go/bin/go test ./internal/tpm -run 'TestGetVerifiedQuoteLeaseCache' -count=1" >>/tmp/mohawk_golden_internal_tests.log
docker exec pyapi-metrics-exporter sh -lc "cd /workspace && /usr/local/go/bin/go test ./internal/pyapi -run 'TestAggregateUpdatesCore_ListPayload|TestAggregateUpdatesCore_WrappedPayloadWithMultiKrum|TestAggregateUpdatesCore_InvalidPayload|TestAggregateUpdatesCore_EmptyPayload' -count=1" >/tmp/mohawk_golden_pyapi_tests.log

echo "[golden-path] collecting metric assertions"
UP_QUERY=$(curl -fsSG http://localhost:9090/api/v1/query --data-urlencode 'query=sum(up)')
RATIO_QUERY=$(curl -fsSG http://localhost:9090/api/v1/query --data-urlencode 'query=min_over_time(mohawk_consensus_honest_ratio[10m])')
echo "$UP_QUERY" > /tmp/mohawk_up_query.json
echo "$RATIO_QUERY" > /tmp/mohawk_ratio_query.json

python3 <<'PY'
import json
from pathlib import Path

root = Path('.').resolve()
report_dir = root / 'results' / 'go-live'
json_report = report_dir / 'golden-path-report.json'
md_report = report_dir / 'golden-path-report.md'

up = json.loads(Path('/tmp/mohawk_up_query.json').read_text(encoding='utf-8')) if Path('/tmp/mohawk_up_query.json').exists() else None
ratio = json.loads(Path('/tmp/mohawk_ratio_query.json').read_text(encoding='utf-8')) if Path('/tmp/mohawk_ratio_query.json').exists() else None

up_ok = bool(up and up.get('status') == 'success' and up.get('data', {}).get('result'))
ratio_ok = bool(ratio and ratio.get('status') == 'success')

payload = {
  'ok': True,
    'checks': {
        'readiness_gate_ok': True,
        'internal_runtime_tests_ok': True,
        'pyapi_integration_tests_ok': True,
    'prometheus_up_query_ok': up_ok,
    'consensus_ratio_query_ok': ratio_ok,
    },
    'artifacts': {
        'readiness_report': 'results/readiness/readiness-report.json',
        'internal_test_log': '/tmp/mohawk_golden_internal_tests.log',
        'pyapi_test_log': '/tmp/mohawk_golden_pyapi_tests.log',
    },
}
payload['ok'] = all(payload['checks'].values())
json_report.write_text(json.dumps(payload, indent=2, sort_keys=True) + '\n', encoding='utf-8')

md = [
    '# Golden Path E2E Report',
    '',
    'The end-to-end golden path executed stack startup, readiness checks, integration tests, and metric assertions.',
    '',
    '| Check | Result |',
    '| --- | --- |',
]
for key, val in payload['checks'].items():
    md.append(f'| {key} | {"PASS" if val else "FAIL"} |')
md.extend([
    '',
    '## Artifacts',
    '',
    '- results/readiness/readiness-report.json',
    '- results/go-live/golden-path-report.json',
    '- /tmp/mohawk_golden_internal_tests.log',
    '- /tmp/mohawk_golden_pyapi_tests.log',
    '',
])
md_report.write_text('\n'.join(md), encoding='utf-8')
print(f'wrote {json_report}')
print(f'wrote {md_report}')
PY

if ! python3 - <<'PY'
import json
from pathlib import Path
report = json.loads(Path('results/go-live/golden-path-report.json').read_text(encoding='utf-8'))
raise SystemExit(0 if report.get('ok') else 1)
PY
then
  echo "[golden-path] report indicates failure"
  exit 1
fi

echo "[golden-path] complete"
