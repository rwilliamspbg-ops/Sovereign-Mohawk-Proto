#!/usr/bin/env bash
set -euo pipefail

# Prevents Git Bash's MSYS layer from mangling arguments that start with `/`
# (e.g. openssl's `-subj '/CN=.../O=...'` below) into Windows paths like
# `C:/Program Files/Git/CN=.../O=...`. Harmless outside Git Bash/MSYS -- the
# variable is simply unused there.
export MSYS_NO_PATHCONV=1

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_CMD="$SCRIPT_DIR/docker-compose-wrapper.sh"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker daemon is not reachable" >&2
  exit 1
fi

# docker-compose.yml requires GRAFANA_ADMIN_PASSWORD with no default (on
# purpose -- no insecure default). Previously nothing here created .env, so
# the very first docker compose command below would fail immediately with
# "required variable GRAFANA_ADMIN_PASSWORD is missing a value", with no
# indication that the fix is "create a .env file". Auto-create one from
# .env.example with a generated local password instead.
ENV_PATH="$ROOT_DIR/.env"
ENV_EXAMPLE_PATH="$ROOT_DIR/.env.example"
if [[ ! -f "$ENV_PATH" ]]; then
  if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
    echo ".env is missing and .env.example was not found; cannot proceed" >&2
    exit 1
  fi
  echo "No .env found -- creating one from .env.example with a generated local Grafana admin password." >&2
  cp "$ENV_EXAMPLE_PATH" "$ENV_PATH"
  if command -v openssl >/dev/null 2>&1; then
    GENERATED_GRAFANA_PW="$(openssl rand -hex 16)"
  else
    GENERATED_GRAFANA_PW="local-dev-$(date +%s)-$$"
  fi
  sed -i.bak "s/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${GENERATED_GRAFANA_PW}/" "$ENV_PATH"
  rm -f "${ENV_PATH}.bak"
  echo "Generated local Grafana admin password -- see GRAFANA_ADMIN_PASSWORD in $ENV_PATH." >&2
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

# Regenerate the CA if it's missing OR expired/about to expire (checked via
# `openssl x509 -checkend`, not just file existence). Previously this only
# checked existence, so a CA/leaf cert that quietly expired after its
# original --days window (observed in practice: a leaf cert generated with
# -days 30 in docker-compose.yml's runtime-secrets-init) was never
# regenerated -- the orchestrator crash-looped indefinitely on
# "certificate has expired" with no automatic recovery.
CA_NEEDS_REGEN=0
if [[ ! -s "$TPM_CERT_PATH" || ! -s "$TPM_KEY_PATH" ]]; then
  CA_NEEDS_REGEN=1
elif command -v openssl >/dev/null 2>&1 && ! openssl x509 -checkend 86400 -noout -in "$TPM_CERT_PATH" >/dev/null 2>&1; then
  echo "Existing TPM CA certificate at $TPM_CERT_PATH is expired (or expires within a day) -- regenerating." >&2
  CA_NEEDS_REGEN=1
fi

if [[ "$CA_NEEDS_REGEN" -eq 1 ]]; then
  if ! command -v openssl >/dev/null 2>&1; then
    echo "cannot create TPM CA secrets (openssl is required)" >&2
    exit 1
  fi
  openssl req -x509 -newkey rsa:3072 \
    -keyout "$TPM_KEY_PATH" \
    -out "$TPM_CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
  # Leaf certs issued by the previous CA no longer chain to this one --
  # clear them so runtime-secrets-init reissues fresh leaves against it.
  rm -f runtime-secrets/mohawk_tpm_orchestrator_cert.pem runtime-secrets/mohawk_tpm_orchestrator_key.pem \
        runtime-secrets/mohawk_tpm_client_cert.pem runtime-secrets/mohawk_tpm_client_key.pem \
        runtime-secrets/mohawk_tpm_ca_cert.srl
  rm -rf runtime-secrets/node-agent-certs
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

get_env_value() {
  grep -m1 "^$1=" "$ENV_PATH" 2>/dev/null | cut -d= -f2-
}

# ops-assistant requires a real Grafana API token to start -- a blank one
# makes it crash-loop on "No Grafana API token found". Generating one
# requires Grafana to already be up, so it can't be done ahead of time; do
# it now, once, if it hasn't already been set.
if [[ -z "$(get_env_value GRAFANA_API_TOKEN)" ]] && command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  GRAFANA_ADMIN_PW="$(get_env_value GRAFANA_ADMIN_PASSWORD)"
  if [[ -n "$GRAFANA_ADMIN_PW" ]]; then
    echo "No GRAFANA_API_TOKEN set -- bootstrapping one from the running Grafana instance..." >&2
    for i in {1..30}; do
      if curl -fsS -u "admin:$GRAFANA_ADMIN_PW" http://localhost:3000/api/health >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
    SA_ID="$(curl -fsS -u "admin:$GRAFANA_ADMIN_PW" -X POST http://localhost:3000/api/serviceaccounts \
      -H 'Content-Type: application/json' \
      -d '{"name":"ops-assistant-genesis","role":"Viewer"}' 2>/dev/null \
      | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin).get("id", ""))
except Exception:
    pass' 2>/dev/null || true)"
    NEW_TOKEN=""
    if [[ -n "$SA_ID" ]]; then
      NEW_TOKEN="$(curl -fsS -u "admin:$GRAFANA_ADMIN_PW" -X POST "http://localhost:3000/api/serviceaccounts/$SA_ID/tokens" \
        -H 'Content-Type: application/json' \
        -d '{"name":"ops-assistant-token"}' 2>/dev/null \
        | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin).get("key", ""))
except Exception:
    pass' 2>/dev/null || true)"
    fi
    if [[ -n "$NEW_TOKEN" ]]; then
      sed -i.bak "s#^GRAFANA_API_TOKEN=.*#GRAFANA_API_TOKEN=${NEW_TOKEN}#" "$ENV_PATH"
      rm -f "${ENV_PATH}.bak"
      echo "Generated a Grafana API token for ops-assistant; restarting it to pick it up." >&2
      "$COMPOSE_CMD" up -d ops-assistant >/dev/null 2>&1 || true
    else
      echo "warning: could not create a Grafana API token automatically; ops-assistant may not start (create one manually at http://localhost:3000/org/serviceaccounts and set GRAFANA_API_TOKEN in .env)" >&2
    fi
  fi
fi

for i in {1..15}; do
  if [[ "$(docker inspect -f '{{.State.Health.Status}}' ops-assistant 2>/dev/null || true)" == "healthy" ]]; then
    break
  fi
  sleep 2
done

if [[ "$(docker inspect -f '{{.State.Health.Status}}' ops-assistant 2>/dev/null || true)" != "healthy" ]]; then
  echo "warning: ops-assistant is not healthy yet; continuing with orchestrator and node agents" >&2
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Genesis Launch Complete: Sovereign Mohawk Stack Ready        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Core Services:"
echo "  • Orchestrator:        https://localhost:8080"
echo "  • Federated Router:    http://localhost:8087"
echo "  • Grafana:             http://localhost:3000 (admin / see GRAFANA_ADMIN_PASSWORD in .env)"
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