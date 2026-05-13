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
