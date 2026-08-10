#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/results/go-live/evidence"
mkdir -p "$OUT_DIR"

NETWORK_NAME="mohawk-transport-topology"
LISTENER_CONTAINER="mohawk-transport-listener"
RESULT_JSON="$OUT_DIR/docker_transport_topology_2026-08-10.json"
LISTENER_LOG="$OUT_DIR/docker_transport_listener.log"
DIAL_LOG="$OUT_DIR/docker_transport_dial.log"

rm -f "$RESULT_JSON" "$LISTENER_LOG" "$DIAL_LOG"

cleanup() {
  docker rm -f "$LISTENER_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
docker network create "$NETWORK_NAME" >/dev/null

docker run -d --name "$LISTENER_CONTAINER" --network "$NETWORK_NAME" \
  -v "$ROOT_DIR:/src" -w /src golang:1.26-bookworm \
  bash -lc '/usr/local/go/bin/go run ./cmd/transport-probe listen' >/dev/null

for attempt in $(seq 1 30); do
  if docker logs "$LISTENER_CONTAINER" > "$LISTENER_LOG" 2>&1; then
    if python3 - "$LISTENER_LOG" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
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
        print(payload['peer_id'])
        print(payload['addresses'][0])
        sys.exit(0)
sys.exit(1)
PY
    then
      break
    fi
  fi
  sleep 2
done

if ! python3 - "$LISTENER_LOG" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
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
        print(payload['peer_id'])
        print(payload['addresses'][0])
        sys.exit(0)
sys.exit(1)
PY
then
  echo "listener did not emit JSON payload" >&2
  exit 1
fi

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
        print(payload['peer_id'])
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
        addrs = payload.get('addresses', [])
        for addr in addrs:
            if '127.0.0.1' in addr or '::1' in addr:
                continue
            print(addr)
            break
        else:
            print(addrs[0] if addrs else '')
        break
PY
)"

set +e
if docker run --rm --network "$NETWORK_NAME" \
  -v "$ROOT_DIR:/src" -w /src golang:1.26-bookworm \
  bash -lc "/usr/local/go/bin/go run ./cmd/transport-probe dial '$PEER_ID' '$PEER_ADDR'" > "$DIAL_LOG" 2>&1; then
  DIALED=1
else
  DIALED=0
fi
set -e

docker rm -f "$LISTENER_CONTAINER" >/dev/null 2>&1 || true

python3 - "$RESULT_JSON" "$NETWORK_NAME" "$LISTENER_LOG" "$DIAL_LOG" "$PEER_ID" "$PEER_ADDR" "$DIALED" <<'PY'
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
network_name = sys.argv[2]
listener_log = Path(sys.argv[3])
dial_log = Path(sys.argv[4])
peer_id = sys.argv[5]
peer_addr = sys.argv[6]
dialed = sys.argv[7] == '1'

listener_payload = None
for line in listener_log.read_text(encoding='utf-8', errors='replace').splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'listen':
        listener_payload = payload
        break

dial_payload = None
for line in dial_log.read_text(encoding='utf-8', errors='replace').splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        continue
    if payload.get('mode') == 'dial':
        dial_payload = payload
        break

payload = {
    'generated_at_utc': '2026-08-10T16:45:00Z',
    'network': {'name': network_name, 'driver': 'bridge'},
    'listener': {
        'peer_id': peer_id,
        'peer_addr': peer_addr,
        'payload': listener_payload,
        'log_path': str(listener_log),
    },
    'dialer': {
        'succeeded': dialed,
        'payload': dial_payload,
        'log_path': str(dial_log),
    },
    'notes': 'Single-host container topology on a Docker bridge network; this remains a local topology probe rather than WAN or multi-site evidence.'
}
out_path.write_text(json.dumps(payload, indent=2), encoding='utf-8')
PY

echo "$RESULT_JSON"
