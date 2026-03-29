#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
COMPOSE_CMD="$ROOT_DIR/scripts/docker-compose-wrapper.sh"

usage() {
  cat <<'EOF'
Usage: scripts/quantum_kex_rotation_drill.sh [--mode MODE] [--services CSV] [--dry-run]

Performs a staged KEX policy rotation drill with rolling service restarts.
This drill is designed to avoid global drops by restarting one service at a time.

Options:
  --mode MODE      Target KEX mode (x25519 | x25519-mlkem768-hybrid)
                   Default: x25519-mlkem768-hybrid
  --services CSV   Comma-separated service list for rolling restart order.
                   Default: node-agent-1,node-agent-2,node-agent-3,orchestrator
  --dry-run        Print planned actions without executing docker compose commands
  -h, --help       Show this help

Notes:
  - Runtime currently enforces strict mode matching, so mixed-mode windows should be brief.
  - This script performs operational drill sequencing, not cryptographic key material migration.
EOF
}

TARGET_MODE="x25519-mlkem768-hybrid"
SERVICES_CSV="node-agent-1,node-agent-2,node-agent-3,orchestrator"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --mode" >&2
        exit 1
      fi
      TARGET_MODE="$2"
      shift 2
      ;;
    --services)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --services" >&2
        exit 1
      fi
      SERVICES_CSV="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
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

case "$TARGET_MODE" in
  x25519|x25519-mlkem768-hybrid)
    ;;
  *)
    echo "unsupported mode: $TARGET_MODE" >&2
    echo "supported values: x25519, x25519-mlkem768-hybrid" >&2
    exit 1
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "docker daemon is not reachable" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for post-rotation health checks" >&2
  exit 1
fi

IFS=',' read -r -a services <<<"$SERVICES_CSV"
if [[ ${#services[@]} -eq 0 ]]; then
  echo "no services provided" >&2
  exit 1
fi

check_prometheus() {
  curl -fsS http://localhost:9090/-/healthy >/dev/null 2>&1
}

print_ratio_snapshot() {
  local query
  query='(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="failure"}[5m]))/clamp_min(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit"}[5m])),1e-9))'
  curl -fsSG http://localhost:9090/api/v1/query --data-urlencode "query=${query}" 2>/dev/null || true
}

echo "starting KEX rotation drill"
echo "target mode: $TARGET_MODE"
echo "restart order: ${services[*]}"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "dry run enabled; no changes will be applied"
fi

if ! check_prometheus; then
  echo "warning: prometheus health endpoint is not available; ratio snapshots will be skipped" >&2
fi

echo "pre-rotation failure ratio snapshot:"
print_ratio_snapshot

for svc in "${services[@]}"; do
  svc="$(echo "$svc" | xargs)"
  if [[ -z "$svc" ]]; then
    continue
  fi

  echo "rolling restart: $svc"
  if [[ $DRY_RUN -eq 0 ]]; then
    MOHAWK_TRANSPORT_KEX_MODE="$TARGET_MODE" "$COMPOSE_CMD" up -d --no-deps "$svc"

    attempts=0
    until [[ $attempts -ge 30 ]]; do
      if docker ps --format '{{.Names}} {{.Status}}' | grep -E "^${svc} .*\bUp\b" >/dev/null 2>&1; then
        break
      fi
      attempts=$((attempts + 1))
      sleep 2
    done

    if [[ $attempts -ge 30 ]]; then
      echo "service $svc did not become healthy in time" >&2
      exit 1
    fi
  fi

  echo "post-restart failure ratio snapshot for $svc:"
  print_ratio_snapshot

done

echo "final validation"
if [[ $DRY_RUN -eq 0 ]]; then
  if ! docker ps --format '{{.Names}}' | grep -Fx 'orchestrator' >/dev/null 2>&1; then
    echo "orchestrator container is not running after rotation" >&2
    exit 1
  fi

  node_agents_up="$(docker ps --format '{{.Names}}' | grep -Ec '^node-agent-[0-9]+$' || true)"
  if [[ "$node_agents_up" -lt 1 ]]; then
    echo "no node-agent containers are running after rotation" >&2
    exit 1
  fi

  if ! curl -kfsS https://localhost:8080/p2p/info >/dev/null 2>&1; then
    echo "warning: unauthenticated /p2p/info probe failed (expected in strict mTLS setups); container health checks passed"
  fi
fi

echo "KEX rotation drill complete"
