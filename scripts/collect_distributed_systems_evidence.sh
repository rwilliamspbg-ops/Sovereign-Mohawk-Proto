#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"

LOCAL_ECHO_JSON="$(mktemp)"
RELAY_FLOW_JSON="$(mktemp)"
LISTEN_JSON="$(mktemp)"
DIAL_JSON="$(mktemp)"
LISTEN_LOG="$(mktemp)"
DIAL_LOG="$(mktemp)"
trap 'rm -f "$LOCAL_ECHO_JSON" "$RELAY_FLOW_JSON" "$LISTEN_JSON" "$DIAL_JSON" "$LISTEN_LOG" "$DIAL_LOG"' EXIT

go run ./cmd/transport-probe local-echo > "$LOCAL_ECHO_JSON"
go run ./cmd/transport-probe relay-flow > "$RELAY_FLOW_JSON"
go run ./cmd/transport-probe listen > "$LISTEN_LOG" 2>&1 &
LISTENER_PID=$!
sleep 2
python3 - "$LISTEN_LOG" "$LISTEN_JSON" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = log_path.read_text(encoding='utf-8', errors='replace')
for line in text.splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'listen':
        out_path.write_text(json.dumps(payload), encoding='utf-8')
        break
else:
    raise SystemExit('no listen payload found')
PY

PEER_ID="$(python3 - "$LISTEN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    payload = json.load(fh)
print(payload['peer_id'])
PY
)"
PEER_ADDR="$(python3 - "$LISTEN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    payload = json.load(fh)
print(payload['addresses'][0])
PY
)"

# MSYS2_ARG_CONV_EXCL: $PEER_ADDR is a raw libp2p multiaddr (e.g.
# "/ip4/.../tcp/..."), which Git Bash on Windows otherwise auto-converts
# as if it were a Unix path argument, corrupting it before the dial
# subcommand ever parses it.
MSYS2_ARG_CONV_EXCL="/ip4" go run ./cmd/transport-probe dial "$PEER_ID" "$PEER_ADDR" > "$DIAL_LOG" 2>&1
wait "$LISTENER_PID" || true
python3 - "$DIAL_LOG" "$DIAL_JSON" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = log_path.read_text(encoding='utf-8', errors='replace')
for line in text.splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'dial':
        out_path.write_text(json.dumps(payload), encoding='utf-8')
        break
else:
    raise SystemExit('no dial payload found')
PY

DETECTED_OS="$(uname -a 2>/dev/null || echo unknown)"
DETECTED_DOCKER="$(docker --version 2>/dev/null || echo unavailable)"
DETECTED_GO="$(go version 2>/dev/null || echo unavailable)"
TPM_DEVICES_JSON="$(python3 -c "import json,glob; print(json.dumps(sorted(glob.glob('/dev/tpm*'))))")"

cat > "$OUT_DIR/distributed_systems_transport_evidence_2026-08-10.json" <<EOF
{
  "generated_at_utc": "2026-08-10T16:25:00Z",
  "environment": {
    "os": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$DETECTED_OS"),
    "docker": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$DETECTED_DOCKER"),
    "go": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$DETECTED_GO"),
    "tpm_devices": $TPM_DEVICES_JSON
  },
  "tests": {
    "local_echo": $(cat "$LOCAL_ECHO_JSON"),
    "relay_flow": $(cat "$RELAY_FLOW_JSON"),
    "listener": $(cat "$LISTEN_JSON"),
    "dialer": $(cat "$DIAL_JSON")
  },
  "notes": {
    "scope": "This session exercised the repository's real libp2p transport stack with relay and hole-punching settings enabled. It does not claim WAN or multi-site reachability; it is a single-host transport-path probe only.",
    "tpm": $(python3 -c "
import json
devices = json.loads('$TPM_DEVICES_JSON')
if devices:
    print(json.dumps('TPM device(s) present but not exercised by this probe: ' + ', '.join(devices)))
else:
    print(json.dumps('No /dev/tpm* device was present on this host, so TPM attestation was scoped out of this round.'))
")
  }
}
EOF

echo "$OUT_DIR/distributed_systems_transport_evidence_2026-08-10.json"
