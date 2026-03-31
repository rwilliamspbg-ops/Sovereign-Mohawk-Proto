#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
COMPOSE_CMD="$ROOT_DIR/scripts/docker-compose-wrapper.sh"
COMPOSE_FILE="docker-compose.sandbox.yml"

usage() {
  cat <<'EOF'
Usage: scripts/launch_sandbox.sh [--down] [--no-build]

Launches Mini-Mohawk sandbox:
- orchestrator
- shard-us-east
- node-agent-1
- node-agent-2
- ipfs
- runtime-secrets-init
- wasm-hello-world-build

Options:
  --down      Stop and remove sandbox
  --no-build  Start without rebuilding images
  -h, --help  Show this help
EOF
}

MODE="up"
BUILD_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --down)
      MODE="down"
      shift
      ;;
    --no-build)
      BUILD_FLAG="--no-build"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker daemon is not reachable" >&2
  exit 1
fi

if [[ "$MODE" == "down" ]]; then
  "$COMPOSE_CMD" -f "$COMPOSE_FILE" down -v
  echo "sandbox stopped"
  exit 0
fi

mkdir -p runtime-secrets

TOKEN_PATH="runtime-secrets/mohawk_api_token"
TPM_CERT_PATH="runtime-secrets/mohawk_tpm_ca_cert.pem"
TPM_KEY_PATH="runtime-secrets/mohawk_tpm_ca_key.pem"

if [[ ! -s "$TOKEN_PATH" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    umask 077
    openssl rand -hex 24 > "$TOKEN_PATH"
    echo "created $TOKEN_PATH"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import os
import secrets
from pathlib import Path
path = Path('runtime-secrets/mohawk_api_token')
path.write_text(secrets.token_hex(24), encoding='utf-8')
os.chmod(path, 0o600)
print(f'created {path}')
PY
  else
    echo "cannot create $TOKEN_PATH (need openssl or python3)" >&2
    exit 1
  fi
fi

if [[ ! -s "$TPM_CERT_PATH" || ! -s "$TPM_KEY_PATH" ]]; then
  openssl req -x509 -newkey rsa:3072 \
    -keyout "$TPM_KEY_PATH" \
    -out "$TPM_CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
  echo "created runtime TPM CA secrets"
fi

export MOHAWK_TRANSPORT_KEX_MODE="${MOHAWK_TRANSPORT_KEX_MODE:-x25519-mlkem768-hybrid}"
export MOHAWK_TPM_IDENTITY_SIG_MODE="${MOHAWK_TPM_IDENTITY_SIG_MODE:-xmss}"

"$COMPOSE_CMD" -f "$COMPOSE_FILE" up -d ${BUILD_FLAG} runtime-secrets-init wasm-hello-world-build
"$COMPOSE_CMD" -f "$COMPOSE_FILE" up -d ${BUILD_FLAG} orchestrator shard-us-east ipfs node-agent-1 node-agent-2

for _ in $(seq 1 45); do
  running_count="$(docker ps --format '{{.Names}}' | grep -E '^(orchestrator|node-agent-1|node-agent-2|ipfs|shard-us-east)$' | wc -l | xargs)"
  if [[ "$running_count" == "5" ]]; then
    break
  fi
  sleep 2
done

running_count="$(docker ps --format '{{.Names}}' | grep -E '^(orchestrator|node-agent-1|node-agent-2|ipfs|shard-us-east)$' | wc -l | xargs)"
if [[ "$running_count" != "5" ]]; then
  echo "sandbox did not fully start; expected 5 running services, found $running_count" >&2
  docker ps --format 'table {{.Names}}\t{{.Status}}'
  exit 1
fi

echo "Mini-Mohawk sandbox is running"
echo "Services: orchestrator, shard-us-east, node-agent-1, node-agent-2, ipfs"
echo "Use: docker compose -f docker-compose.sandbox.yml ps"
