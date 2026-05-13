#!/bin/bash
set -e

cd /workspaces/Sovereign-Mohawk-Proto

echo "=== Ops-Assistant Complete Startup & Validation ==="
echo ""

# Step 1: Set token
echo "Step 1: Setting GRAFANA_API_TOKEN..."
export GRAFANA_API_TOKEN="admin"
echo "  Token: admin"

# Step 2: Start services
echo ""
echo "Step 2: Starting services..."
docker-compose up -d 2>&1 | grep -E "Creating|Running|Starting|Started|Warning" || true

# Step 3: Wait for services to be healthy
echo ""
echo "Step 3: Waiting for services to become healthy (this may take 30-60 seconds)..."
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
  PROM_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/ready 2>/dev/null || echo "000")
  GRAFANA_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
  
  if [ "$PROM_HEALTH" = "200" ] && [ "$GRAFANA_HEALTH" = "200" ]; then
    echo "  ✓ Services are healthy"
    break
  fi
  
  echo -n "."
  sleep 5
  WAITED=$((WAITED + 5))
done

# Step 4: Check service status
echo ""
echo "Step 4: Service Status"
docker-compose ps

# Step 5: Run validation
echo ""
echo "Step 5: Running Validation"
./scripts/validate-ops-assistant.sh

echo ""
echo "=== Complete ==="
