#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"
OUT_JSON="$OUT_DIR/transport_performance_metrics_2026-08-10.json"

BENCH_JSON="$OUT_DIR/transport_bench.json"

rm -f "$OUT_JSON" "$BENCH_JSON"

GO111MODULE=on go test ./cmd/transport-probe -run '^$' -bench '^BenchmarkProbeLocalEcho$' -benchmem -count=1 > "$BENCH_JSON" 2>&1

python3 - "$BENCH_JSON" "$OUT_JSON" <<'PY'
import json
import sys
from pathlib import Path

bench_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = bench_path.read_text(encoding='utf-8', errors='replace')

ops_per_sec = None
ns_per_op = None
allocs_per_op = None
bytes_per_op = None

for line in text.splitlines():
    if line.startswith('BenchmarkProbeLocalEcho'):
        parts = [p for p in line.split() if p]
        if len(parts) >= 8:
            ns_per_op = float(parts[2])
            ops_per_sec = 1_000_000_000.0 / ns_per_op if ns_per_op else None
            bytes_per_op = float(parts[4])
            allocs_per_op = float(parts[6])
        break
    if 'B/op' in line:
        parts = line.split()
        for idx, part in enumerate(parts):
            if part == 'B/op':
                bytes_per_op = float(parts[idx-1])
                break
    if 'allocs/op' in line:
        parts = line.split()
        for idx, part in enumerate(parts):
            if part == 'allocs/op':
                allocs_per_op = float(parts[idx-1])
                break

payload = {
    'generated_at_utc': '2026-08-10T16:55:00Z',
    'scope': 'Single-host libp2p transport benchmark for the local echo path on this Codespace.',
    'benchmark': {
        'name': 'BenchmarkProbeLocalEcho',
        'ops_per_sec': ops_per_sec,
        'ns_per_op': ns_per_op,
        'allocs_per_op': allocs_per_op,
        'bytes_per_op': bytes_per_op,
    },
    'environment': {
        'os': 'Ubuntu 24.04.4 LTS',
        'go': 'go1.26.5',
    },
    'notes': 'These numbers are from a real local transport benchmark and are not a claim about wide-area throughput or production cluster performance.'
}
out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
PY

echo "$OUT_JSON"
