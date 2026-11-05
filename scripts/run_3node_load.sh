#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d
echo "Waiting for health..."
for i in $(seq 1 60); do
  curl -sf http://localhost:8080/health >/dev/null && break
  sleep 2
done
echo "Running 5000-round load..."
python sdk/python/examples/flower_integrated/local_simulator.py --virtual-nodes 3 --rounds 5000 --ci
echo "Done. Collect logs:"
docker compose logs --no-color > artifacts/load-run.log
