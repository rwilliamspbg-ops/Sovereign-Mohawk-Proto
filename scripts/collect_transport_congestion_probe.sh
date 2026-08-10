#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"
OUT_JSON="$OUT_DIR/transport_congestion_probe_2026-08-10.json"

rm -f "$OUT_JSON"

python3 - "$OUT_JSON" <<'PY'
import json
import subprocess
import sys
import time
from pathlib import Path

out_path = Path(sys.argv[1])
root = Path('/workspaces/Sovereign-Mohawk-Proto')

listener = subprocess.Popen(
    ['go', 'run', './cmd/transport-probe', 'listen'],
    cwd=root,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
)
try:
    time.sleep(3)
    payload_text = listener.stdout.read() if listener.stdout else ''
    peer_id = None
    peer_addr = None
    for line in payload_text.splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get('mode') == 'listen':
            peer_id = payload.get('peer_id')
            peer_addr = payload.get('dialable_addr') or payload.get('addresses', [''])[0]
            break
    if not peer_id or not peer_addr:
        raise SystemExit('listener did not emit usable address data')

    dial_results = []
    for _ in range(3):
        proc = subprocess.run(
            ['go', 'run', './cmd/transport-probe', 'dial', peer_id, peer_addr],
            cwd=root,
            capture_output=True,
            text=True,
        )
        dial_results.append({
            'returncode': proc.returncode,
            'stdout': proc.stdout.strip(),
            'stderr': proc.stderr.strip(),
        })

    payload = {
        'generated_at_utc': '2026-08-10T17:30:00Z',
        'scope': 'Three-pass local congestion-style probe for the libp2p listener/dialer path.',
        'listener': {'peer_id': peer_id, 'peer_addr': peer_addr},
        'dial_results': dial_results,
        'environment': {'os': 'Ubuntu 24.04.4 LTS'},
        'notes': 'This is a bounded local congestion-style probe and not a claim about wide-area network congestion.'
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

echo "$OUT_JSON"
