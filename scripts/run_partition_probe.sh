#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"

LISTEN_LOG="$OUT_DIR/partition_listener.log"
DIAL_LOG="$OUT_DIR/partition_dial.log"
RESULT_JSON="$OUT_DIR/partition_probe_2026-08-10.json"

rm -f "$LISTEN_LOG" "$DIAL_LOG" "$RESULT_JSON"

set +e
(go run ./cmd/transport-probe listen > "$LISTEN_LOG" 2>&1) &
LISTENER_PID=$!
sleep 3
python3 - "$LISTEN_LOG" <<'PY'
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
        print(payload['peer_id'])
        print(payload['addresses'][0])
        break
else:
    raise SystemExit('listener did not emit JSON')
PY
PEER_ID="$(python3 - "$LISTEN_LOG" <<'PY'
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
        print(payload['peer_id'])
        break
PY
)"
PEER_ADDR="$(python3 - "$LISTEN_LOG" <<'PY'
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
        print(payload['addresses'][0])
        break
PY
)"
set -e

# MSYS2_ARG_CONV_EXCL: $PEER_ADDR is a raw libp2p multiaddr (e.g.
# "/ip4/.../tcp/..."), which Git Bash on Windows otherwise auto-converts
# as if it were a Unix path argument, corrupting it before the dial
# subcommand ever parses it.
if MSYS2_ARG_CONV_EXCL="/ip4" go run ./cmd/transport-probe dial "$PEER_ID" "$PEER_ADDR" > "$DIAL_LOG" 2>&1; then
  DIALED=1
else
  DIALED=0
fi
wait "$LISTENER_PID" || true

cat > "$RESULT_JSON" <<EOF
{
  "generated_at_utc": "2026-08-10T16:30:00Z",
  "listener_pid": "$LISTENER_PID",
  "dial_result": {
    "succeeded": $DIALED,
    "log_path": "$DIAL_LOG"
  },
  "listener_log_path": "$LISTEN_LOG"
}
EOF

echo "$RESULT_JSON"
