#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/launch_full_stack_3_nodes.sh [--down] [--no-build]

Starts the full local network stack with orchestrator + 3 node agents:
- orchestrator
- shard-us-east
- node-agent-1, node-agent-2, node-agent-3
- tpm-metrics
- pyapi-metrics-exporter
- prometheus
- grafana
- ipfs

Options:
  --down      Stop and remove the stack (docker compose down)
  --no-build  Start without rebuilding images
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
  docker compose down
  echo "stack stopped"
  exit 0
fi

mkdir -p runtime-secrets

TOKEN_PATH="runtime-secrets/mohawk_api_token"
TPM_CERT_PATH="runtime-secrets/mohawk_tpm_ca_cert.pem"
TPM_KEY_PATH="runtime-secrets/mohawk_tpm_ca_key.pem"

if [[ -d "$TOKEN_PATH" ]]; then
  cat >&2 <<EOF
invalid path: $TOKEN_PATH is a directory

Fix:
  rm -rf "$TOKEN_PATH"
  ./scripts/launch_full_stack_3_nodes.sh --no-build
EOF
  exit 1
fi

if [[ -d "$TPM_CERT_PATH" || -d "$TPM_KEY_PATH" ]]; then
  cat >&2 <<EOF
invalid secret path type detected under runtime-secrets/

Expected files:
  $TPM_CERT_PATH
  $TPM_KEY_PATH

At least one path is currently a directory, which breaks Docker bind mounts.
Fix:
  rm -rf "$TPM_CERT_PATH" "$TPM_KEY_PATH"
  ./scripts/launch_full_stack_3_nodes.sh --no-build
EOF
  exit 1
fi

if [[ ! -s "$TOKEN_PATH" ]]; then
  if [[ -e "$TOKEN_PATH" && ! -w "$TOKEN_PATH" ]]; then
    chmod u+w "$TOKEN_PATH" 2>/dev/null || true
  fi

  if [[ -e "$TOKEN_PATH" && ! -w "$TOKEN_PATH" ]]; then
    cat >&2 <<EOF
cannot write $TOKEN_PATH

This commonly happens on Windows when the file is read-only or ACL-restricted.
Fix options:
  1) Remove the file and rerun:
     rm -f "$TOKEN_PATH"
  2) Or grant write permission to your user.
EOF
    exit 1
  fi

  if command -v openssl >/dev/null 2>&1; then
    umask 077
    openssl rand -hex 24 > "$TOKEN_PATH"
    echo "created $TOKEN_PATH"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
from pathlib import Path
path = Path('runtime-secrets/mohawk_api_token')
path.write_text(secrets.token_hex(24), encoding='utf-8')
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

docker compose up -d ${BUILD_FLAG} \
  orchestrator shard-us-east \
  tpm-metrics pyapi-metrics-exporter prometheus grafana ipfs

for i in {1..30}; do
  if curl -kfsS https://localhost:8080/p2p/info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker compose up -d ${BUILD_FLAG} node-agent-1 node-agent-2 node-agent-3

# Simple readiness checks to confirm orchestration and agent footprint.
for i in {1..30}; do
  if curl -fsS http://localhost:9090/-/healthy >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -fsS http://localhost:9090/-/healthy >/dev/null 2>&1; then
  echo "prometheus did not become healthy" >&2
  exit 1
fi

for i in {1..30}; do
  if curl -fsS http://localhost:3000/api/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

agent_count="$(docker ps --format '{{.Names}}' | grep -Ec '^node-agent-[1-3]$' || true)"
if [[ "$agent_count" -ne 3 ]]; then
  echo "expected 3 running node-agent containers, found $agent_count" >&2
  docker ps --format 'table {{.Names}}\t{{.Status}}'
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^orchestrator$'; then
  echo "orchestrator container is not running" >&2
  exit 1
fi

echo "full stack is running with orchestrator + 3 node agents"
echo "grafana: http://localhost:3000"
echo "prometheus: http://localhost:9090"
