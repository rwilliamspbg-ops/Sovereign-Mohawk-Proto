#!/usr/bin/env bash
set -euo pipefail

REGIONAL_SHARD="local-us-east"
METRICS_PROFILE="global-testnet"
NODE_MODE="single"

usage() {
  cat <<'EOF'
Usage: ./genesis-launch.sh [--regional-shard NAME] [--metrics-profile NAME] [--all-nodes]

Options:
  --regional-shard   Set MOHAWK_REGIONAL_SHARD (default: local-us-east)
  --metrics-profile  Set MOHAWK_METRICS_PROFILE (default: global-testnet)
  --all-nodes        Start node-agent-1..3 instead of only node-agent-1
  -h, --help         Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --regional-shard)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --regional-shard" >&2
        usage
        exit 1
      fi
      REGIONAL_SHARD="$2"
      shift 2
      ;;
    --metrics-profile)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --metrics-profile" >&2
        usage
        exit 1
      fi
      METRICS_PROFILE="$2"
      shift 2
      ;;
    --all-nodes)
      NODE_MODE="all"
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

export MOHAWK_REGIONAL_SHARD="$REGIONAL_SHARD"
export MOHAWK_METRICS_PROFILE="$METRICS_PROFILE"
export IPFS_API_ENDPOINT="${IPFS_API_ENDPOINT:-http://localhost:5001}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_CMD="$ROOT_DIR/scripts/docker-compose-wrapper.sh"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker daemon is not reachable" >&2
  exit 1
fi

mkdir -p runtime-secrets

TOKEN_PATH="runtime-secrets/mohawk_api_token"
TPM_CERT_PATH="runtime-secrets/mohawk_tpm_ca_cert.pem"
TPM_KEY_PATH="runtime-secrets/mohawk_tpm_ca_key.pem"

if [[ ! -s "$TOKEN_PATH" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    umask 077
    openssl rand -hex 24 > "$TOKEN_PATH"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
from pathlib import Path
Path('runtime-secrets/mohawk_api_token').write_text(secrets.token_hex(24), encoding='utf-8')
PY
  else
    echo "cannot create $TOKEN_PATH (need openssl or python3)" >&2
    exit 1
  fi
fi

if [[ ! -s "$TPM_CERT_PATH" || ! -s "$TPM_KEY_PATH" ]]; then
  if ! command -v openssl >/dev/null 2>&1; then
    echo "cannot create TPM CA secrets (openssl is required)" >&2
    exit 1
  fi
  openssl req -x509 -newkey rsa:3072 \
    -keyout "$TPM_KEY_PATH" \
    -out "$TPM_CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
fi

echo "Launching regional shard: $MOHAWK_REGIONAL_SHARD"
echo "Metrics profile: $MOHAWK_METRICS_PROFILE"

CORE_SERVICES=(
  orchestrator
  shard-us-east
  shard-eu-west
  federated-router
  tpm-metrics
  pyapi-metrics-exporter
  accelerator-detect
  prometheus
  alertmanager
  grafana
  ops-assistant
  ipfs
)

"$COMPOSE_CMD" up -d "${CORE_SERVICES[@]}"

for i in {1..45}; do
  if docker logs orchestrator 2>&1 | grep -q "orchestrator listening with mTLS on :8080"; then
    break
  fi
  sleep 2
done

for i in {1..30}; do
  if [[ "$(docker inspect -f '{{.State.Health.Status}}' federated-router 2>/dev/null || true)" == "healthy" ]]; then
    break
  fi
  sleep 2
done

if [[ "$(docker inspect -f '{{.State.Health.Status}}' federated-router 2>/dev/null || true)" != "healthy" ]]; then
  echo "federated-router did not become healthy" >&2
  "$COMPOSE_CMD" ps
  exit 1
fi

for i in {1..30}; do
  if [[ "$(docker inspect -f '{{.State.Health.Status}}' ops-assistant 2>/dev/null || true)" == "healthy" ]]; then
    break
  fi
  sleep 2
done

if [[ "$NODE_MODE" == "all" ]]; then
  "$COMPOSE_CMD" up -d node-agent-1 node-agent-2 node-agent-3
  expected_nodes=3
else
  "$COMPOSE_CMD" up -d node-agent-1
  expected_nodes=1
fi

  check_runtime_secrets() {
    # ensure host runtime-secrets exist and look populated before starting node agents
    missing=0
    if [[ ! -s "$TOKEN_PATH" ]]; then
      echo "missing or empty token at $TOKEN_PATH" >&2
      missing=1
    fi
    if [[ ! -s "$TPM_CERT_PATH" ]]; then
      echo "missing or empty TPM cert at $TPM_CERT_PATH" >&2
      missing=1
    fi
    if [[ ! -s "$TPM_KEY_PATH" ]]; then
      echo "missing or empty TPM key at $TPM_KEY_PATH" >&2
      missing=1
    fi
    return $missing
  }

  for attempt in {1..6}; do
    if check_runtime_secrets; then
      break
    fi
    echo "Waiting for runtime-secrets to be created by runtime-secrets-init (attempt $attempt/6)" >&2
    sleep 2
  done

  # If secrets still missing, attempt to run the init service once to populate them.
  if ! check_runtime_secrets; then
    echo "runtime-secrets missing after initial wait — running runtime-secrets-init to generate secrets" >&2
    # Run the init job in the compose context to ensure files are created on the host
    if ! "$COMPOSE_CMD" run --rm runtime-secrets-init; then
      echo "Warning: runtime-secrets-init run failed; continuing to wait but startup may fail" >&2
    else
      echo "runtime-secrets-init completed, re-checking secrets" >&2
    fi

    for attempt in {1..6}; do
      if check_runtime_secrets; then
        break
      fi
      echo "Waiting for runtime-secrets after forced init (attempt $attempt/6)" >&2
      sleep 2
    done
  fi

  for i in {1..30}; do
    running_nodes="$(docker ps --format '{{.Names}}' | grep -Ec '^node-agent-[1-3]$' || true)"
    if [[ "$running_nodes" -ge "$expected_nodes" ]]; then
      break
    fi
    sleep 2
  done

running_nodes="$(docker ps --format '{{.Names}}' | grep -Ec '^node-agent-[1-3]$' || true)"
if [[ "$running_nodes" -lt "$expected_nodes" ]]; then
  echo "expected $expected_nodes node-agent containers, found $running_nodes" >&2
  "$COMPOSE_CMD" ps
  echo "--- recent node-agent logs (tail 200) ---" >&2
  for n in $(seq 1 $expected_nodes); do
    name="node-agent-$n"
    echo "===== logs: $name =====" >&2
    docker logs "$name" --tail 200 2>&1 || true
  done
  exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Genesis Launch Complete: Sovereign Mohawk Stack Ready        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Core Services:"
echo "  • Orchestrator:        https://localhost:8080"
echo "  • Federated Router:    http://localhost:8087"
echo "  • Grafana:             http://localhost:3000 (admin/admin)"
echo "  • Prometheus:          http://localhost:9090"
echo "  • IPFS:                http://localhost:5001"
echo ""
echo "AI Operations Assistant:"
echo "  • CopilotKit Ops:      http://localhost:3001 ✨"
echo "    → Ask about metrics, dashboards, and incident analysis"
echo ""
echo "Cluster Status:"
echo "  • Orchestrator:        Ready (1 primary)"
echo "  • Federated Router:    Ready (1 instance)"
echo "  • Node Agents:         Running ($running_nodes instance(s))"
echo ""
echo "Quick Start:"
echo "  1. Open http://localhost:3001 to access the AI Operations Assistant"
echo "  2. Ask: 'What is the current gradient throughput?'"
echo "  3. Ask: 'Generate an incident summary from the last 30 minutes'"
echo "  4. Ask: 'Explain the v2-10-ops-overview dashboard'"
echo ""