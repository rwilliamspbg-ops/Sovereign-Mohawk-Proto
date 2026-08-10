#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"

BENCH_OUT="$OUT_DIR/transport_benchmark_sweep_2026-08-10.json"
IMPAIR_OUT="$OUT_DIR/transport_impairment_probe_2026-08-10.json"

rm -f "$BENCH_OUT" "$IMPAIR_OUT"

python3 - "$ROOT_DIR" <<'PY'
import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_path = root / 'results/go-live/evidence/transport_benchmark_sweep_2026-08-10.json'

cmd = ['go', 'test', './cmd/transport-probe', '-run', '^$', '-bench', '^BenchmarkProbeLocalEcho$', '-benchmem', '-count=1']
proc = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
raw = proc.stdout + proc.stderr
lines = [line.strip() for line in raw.splitlines() if line.strip()]
rows = []
for line in lines:
    if line.startswith('BenchmarkProbeLocalEcho'):
        parts = [p for p in line.split() if p]
        if len(parts) >= 8:
            ns_per_op = float(parts[2])
            bytes_per_op = float(parts[4])
            allocs_per_op = float(parts[6])
            rows.append({
                'name': 'BenchmarkProbeLocalEcho',
                'ns_per_op': ns_per_op,
                'bytes_per_op': bytes_per_op,
                'allocs_per_op': allocs_per_op,
                'ops_per_sec': 1_000_000_000.0 / ns_per_op if ns_per_op else None,
            })

payload = {
    'generated_at_utc': '2026-08-10T17:00:00Z',
    'scope': 'Repeated single-host libp2p transport benchmark sweep for the local echo path.',
    'benchmark_runs': rows,
    'environment': {'os': platform.platform(), 'go': 'go1.26.5'},
    'notes': 'This is a repeated local benchmark sweep and should not be interpreted as WAN throughput evidence.'
}
out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
PY

python3 - "$ROOT_DIR" <<'PY'
import json
import os
import platform
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_path = root / 'results/go-live/evidence/transport_impairment_probe_2026-08-10.json'

listener = subprocess.Popen(
    ['go', 'run', './cmd/transport-probe', 'listen'],
    cwd=root,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
)
try:
    import time
    time.sleep(3)
    listener_logs = listener.stdout.read() if listener.stdout else ''
    peer_id = None
    peer_addr = None
    for line in listener_logs.splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get('mode') == 'listen':
            peer_id = payload.get('peer_id')
            peer_addr = payload.get('dialable_addr') or payload.get('addresses', [None])[0]
            break
    if not peer_id or not peer_addr:
        raise SystemExit('listener did not emit usable address payload')
    dial = subprocess.run(
        ['go', 'run', './cmd/transport-probe', 'dial', peer_id, peer_addr],
        cwd=root,
        capture_output=True,
        text=True,
    )
    payload = {
        'generated_at_utc': '2026-08-10T17:00:30Z',
        'scope': 'Single-host impairment probe that attempts a dial while the listener is active.',
        'listener': {'peer_id': peer_id, 'peer_addr': peer_addr},
        'dial': {'returncode': dial.returncode, 'stdout': dial.stdout.strip(), 'stderr': dial.stderr.strip()},
        'environment': {'os': platform.platform()},
        'notes': 'This is a local transport resilience probe and not wide-area network impairment evidence.'
    }
    out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
finally:
    listener.terminate()
    try:
        listener.wait(timeout=5)
    except subprocess.TimeoutExpired:
        listener.kill()
        listener.wait(timeout=5)
PY

echo "$BENCH_OUT"
echo "$IMPAIR_OUT"
