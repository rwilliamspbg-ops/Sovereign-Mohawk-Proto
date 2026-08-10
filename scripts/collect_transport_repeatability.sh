#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"
OUT_JSON="$OUT_DIR/transport_repeatability_2026-08-10.json"

rm -f "$OUT_JSON"

python3 - "$OUT_JSON" "$ROOT_DIR" <<'PY'
import json
import platform
import statistics
import subprocess
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
root = Path(sys.argv[2])
results = []
for _ in range(5):
    proc = subprocess.run(
        ['go', 'test', './cmd/transport-probe', '-run', '^$', '-bench', '^BenchmarkProbeLocalEcho$', '-benchmem', '-count=1'],
        cwd=root,
        capture_output=True,
        text=True,
    )
    text = proc.stdout + proc.stderr
    for line in text.splitlines():
        if line.startswith('BenchmarkProbeLocalEcho'):
            parts = [p for p in line.split() if p]
            if len(parts) >= 8:
                ns_per_op = float(parts[2])
                results.append({
                    'ops_per_sec': 1_000_000_000.0 / ns_per_op if ns_per_op else None,
                    'ns_per_op': ns_per_op,
                })
            break

payload = {
    'generated_at_utc': '2026-08-10T17:20:00Z',
    'scope': 'Five-run repeatability sweep for the local transport benchmark.',
    'runs': results,
    'summary': {
        'count': len(results),
        'median_ops_per_sec': statistics.median(r['ops_per_sec'] for r in results if r['ops_per_sec'] is not None),
        'median_ns_per_op': statistics.median(r['ns_per_op'] for r in results if r['ns_per_op'] is not None),
    },
    'environment': {'os': platform.platform(), 'go': 'go1.26.5'},
    'notes': 'This is a local repeatability sweep and not a WAN throughput claim.'
}
out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
PY

echo "$OUT_JSON"
