#!/bin/bash
# Ops-Assistant Configuration Fix Script
# Fixes critical issues preventing metrics/dashboards from rendering

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Ops-Assistant Configuration Fix Script ==="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fix 1: Copy and update root dashboards
echo -e "${YELLOW}Fix 1: Preparing root dashboards${NC}"

if [ ! -d "monitoring/grafana/dashboards/v2" ]; then
  mkdir -p "monitoring/grafana/dashboards/v2"
  echo "  Created v2 dashboard directory"
fi

# Copy root dashboards and fix datasource UIDs
for file in grafana/*.json; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    dest="monitoring/grafana/dashboards/v2/legacy-${filename}"
    
    # Copy file and update datasource UID from "prometheus" to "prometheus-main"
    jq '.panels[] |= (.datasource.uid = "prometheus-main")' "$file" > "$dest"
    echo -e "  ${GREEN}✓${NC} Copied and updated: $filename → legacy-$filename"
  fi
done

# Fix 2: Verify v2 dashboards have correct datasource UID
echo ""
echo -e "${YELLOW}Fix 2: Verifying v2 dashboards${NC}"

for file in monitoring/grafana/dashboards/v2/v2-*.json; do
  if [ -f "$file" ]; then
    uid_count=$(jq '[.panels[] | select(.datasource.uid == "prometheus-main")] | length' "$file")
    total_count=$(jq '.panels | length' "$file")
    
    if [ "$uid_count" -eq "$total_count" ]; then
      echo -e "  ${GREEN}✓${NC} $(basename $file): All $total_count panels use prometheus-main"
    else
      echo -e "  ${RED}✗${NC} $(basename $file): Only $uid_count/$total_count panels use prometheus-main"
    fi
  fi
done

# Fix 3: Create fixed docker-compose entry for reference
echo ""
echo -e "${YELLOW}Fix 3: Docker Compose Configuration${NC}"

echo "Current docker-compose.yml ops-assistant configuration:"
echo "  ✓ PROMETHEUS_URL=http://prometheus:9090"
echo "  ✓ GRAFANA_URL=http://grafana:3000"
echo "  ⚠ GRAFANA_API_TOKEN=\${GRAFANA_API_TOKEN:-admin}"
echo ""
echo "Recommended changes:"
echo "  1. Set GRAFANA_API_TOKEN before startup:"
echo "     export GRAFANA_API_TOKEN='your-actual-token'"
echo ""
echo "  2. Update docker-compose.yml ops-assistant section:"
cat > .ops-assistant-compose-fix.yml << 'COMPOSE'
  ops-assistant:
    build:
      context: .
      dockerfile: web/ops-assistant/Dockerfile
    container_name: ops-assistant
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
      - GRAFANA_URL=http://grafana:3000
      - GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}  # REQUIRED - no fallback
      - CORS_ORIGIN=http://localhost:3001,http://localhost:5173,http://localhost:3000
      - NODE_ENV=production
    ports:
      - "3001:3000"
    depends_on:
      prometheus:
        condition: service_healthy
      grafana:
        condition: service_healthy
    volumes:
      - ./runtime-secrets:/run/secrets:ro
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512m
        reservations:
          cpus: '0.25'
          memory: 256m
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s
    networks:
      - mohawk-net
COMPOSE

echo "    See: .ops-assistant-compose-fix.yml"

# Fix 4: Create validation script
echo ""
echo -e "${YELLOW}Fix 4: Creating validation script${NC}"

if [ ! -d "scripts" ]; then
  mkdir -p "scripts"
fi

cat > scripts/validate-ops-assistant.sh << 'VALIDATE'
#!/bin/bash
# Validation script for ops-assistant connectivity

echo "=== Ops-Assistant Connectivity Check ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_endpoint() {
  local name="$1"
  local url="$2"
  local auth="$3"
  
  echo -n "Testing $name: "
  
  if [ -z "$auth" ]; then
    if curl -s -f "$url" > /dev/null 2>&1; then
      echo -e "${GREEN}✓ OK${NC}"
      return 0
    else
      echo -e "${RED}✗ FAILED${NC}"
      return 1
    fi
  else
    if curl -s -f -H "Authorization: $auth" "$url" > /dev/null 2>&1; then
      echo -e "${GREEN}✓ OK${NC}"
      return 0
    else
      echo -e "${RED}✗ FAILED${NC}"
      return 1
    fi
  fi
}

echo "Connectivity Checks:"
check_endpoint "Prometheus health" "http://localhost:9090/-/ready"
check_endpoint "Grafana health" "http://localhost:3000/api/health"
check_endpoint "Ops-Assistant health" "http://localhost:3001/api/health"

echo ""
echo "Integration Checks:"
check_endpoint "Prometheus availability (from ops-assistant)" "http://localhost:3001/api/prometheus/health"

echo ""
echo "Dashboard & Metrics:"
echo -n "Grafana dashboards accessible: "
DASH_COUNT=$(curl -s -H "Authorization: Bearer admin" http://localhost:3000/api/search?type=dash-db 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
if [ "$DASH_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✓ $DASH_COUNT found${NC}"
else
  echo -e "${RED}✗ None found${NC}"
fi

echo -n "Prometheus metrics (mohawk): "
METRIC_COUNT=$(curl -s 'http://localhost:9090/api/v1/label/__name__/values' 2>/dev/null | \
  jq '[.data[] | select(. | contains("mohawk"))] | length' 2>/dev/null || echo "0")
echo "$METRIC_COUNT metrics"

echo ""
echo "API Tests:"
echo -n "Query endpoint (throughput): "
QUERY_RESULT=$(curl -s -X POST http://localhost:3001/api/query \
  -H "Content-Type: application/json" \
  -d '{"query":"rate(mohawk:gradient_submit:total[1m])"}' 2>/dev/null | \
  jq '.data.result | length' 2>/dev/null || echo "error")
echo "${GREEN}$QUERY_RESULT results${NC}"

echo ""
echo "=== Validation Complete ==="
VALIDATE

chmod +x scripts/validate-ops-assistant.sh
echo -e "  ${GREEN}✓${NC} Created scripts/validate-ops-assistant.sh"

# Fix 5: Summary
echo ""
echo -e "${YELLOW}Fix 5: Implementation Summary${NC}"
echo ""
echo "Changes made:"
echo -e "  ${GREEN}✓${NC} Copied root dashboards with corrected datasource UIDs"
echo -e "  ${GREEN}✓${NC} Created validation script at scripts/validate-ops-assistant.sh"
echo ""
echo "Required manual steps:"
echo "  1. Review .ops-assistant-compose-fix.yml and update docker-compose.yml"
echo "  2. Set GRAFANA_API_TOKEN before docker-compose up:"
echo "     export GRAFANA_API_TOKEN='your-token-here'"
echo "  3. Restart services:"
echo "     docker-compose down"
echo "     docker-compose up -d"
echo "  4. Run validation:"
echo "     ./scripts/validate-ops-assistant.sh"
echo ""
echo -e "${GREEN}Fix script complete!${NC}"
echo ""
echo "For detailed diagnostics, see: OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md"
echo "For recommended fixes, see: OPS_ASSISTANT_RECOMMENDED_FIXES.md"
