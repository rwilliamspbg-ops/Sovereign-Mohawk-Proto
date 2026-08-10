#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"
OUT_JSON="$OUT_DIR/transport_delay_probe_2026-08-10.json"

rm -f "$OUT_JSON"

LISTENER_LOG="$OUT_DIR/transport_delay_listener.log"
DIAL_LOG="$OUT_DIR/transport_delay_dial.log"
rm -f "$LISTENER_LOG" "$DIAL_LOG"

set +e
(go run ./cmd/transport-probe listen > "$LISTENER_LOG" 2>&1) &
LISTENER_PID=$!
sleep 3

PEER_ID="$(python3 - "$LISTENER_LOG" <<'PY'
import json
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
for line in text.splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'listen':
        print(payload.get('peer_id'))
        break
PY
)"
PEER_ADDR="$(python3 - "$LISTENER_LOG" <<'PY'
import json
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
for line in text.splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'listen':
        print(payload.get('dialable_addr') or payload.get('addresses', [''])[0])
        break
PY
)"

if [ -n "$PEER_ID" ] && [ -n "$PEER_ADDR" ]; then
  go run ./cmd/transport-probe dial "$PEER_ID" "$PEER_ADDR" > "$DIAL_LOG" 2>&1
  DIAL_RC=$?
else
  DIAL_RC=2
fi
set -e

wait "$LISTENER_PID" || true

python3 - "$OUT_JSON" "$PEER_ID" "$PEER_ADDR" "$LISTENER_LOG" "$DIAL_LOG" "$DIAL_RC" <<'PY'
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
peer_id = sys.argv[2]
peer_addr = sys.argv[3]
listener_log = sys.argv[4]
dial_log = sys.argv[5]
dial_rc = int(sys.argv[6])
output_text = Path(dial_log).read_text(encoding='utf-8', errors='replace').strip()
payload = {
    'generated_at_utc': '2026-08-10T17:10:00Z',
    'scope': 'Single-host local delay probe for the libp2p listener/dialer path.',
    'listener': {
        'peer_id': peer_id,
        'peer_addr': peer_addr,
        'log_path': listener_log,
    },
    'dial': {
        'returncode': dial_rc,
        'log_path': dial_log,
        'output': output_text,
    },
    'environment': {'os': 'Ubuntu 24.04.4 LTS'},
    'notes': 'This is a local transport impairment probe and not WAN or production-network evidence.'
}
out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
PY

echo "$OUT_JSON"
