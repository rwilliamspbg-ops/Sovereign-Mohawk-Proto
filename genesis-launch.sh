#!/usr/bin/env bash
set -euo pipefail

REGIONAL_SHARD="local-us-east"
METRICS_PROFILE="global-testnet"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --regional-shard)
      REGIONAL_SHARD="$2"
      shift 2
      ;;
    --metrics-profile)
      METRICS_PROFILE="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

export MOHAWK_REGIONAL_SHARD="$REGIONAL_SHARD"
export MOHAWK_METRICS_PROFILE="$METRICS_PROFILE"
export IPFS_API_ENDPOINT="${IPFS_API_ENDPOINT:-http://localhost:5001}"

echo "Launching regional shard: $MOHAWK_REGIONAL_SHARD"
echo "Metrics profile: $MOHAWK_METRICS_PROFILE"
docker compose up -d orchestrator shard-us-east node-agent-1 tpm-metrics prometheus grafana ipfs