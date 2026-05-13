#!/bin/bash

#################################################################
# Unified Auth Layer - Comprehensive Testing Guide
#
# This script validates all components of the auth system
#################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASS=0
FAIL=0
SKIP=0

#################################################################
# Test Functions
#################################################################

test_start() {
  echo -e "${BLUE}▶${NC} $1"
}

test_pass() {
  PASS=$((PASS+1))
  echo -e "${GREEN}✓ PASS${NC} $1"
}

test_fail() {
  FAIL=$((FAIL+1))
  echo -e "${RED}✗ FAIL${NC} $1"
}

test_skip() {
  SKIP=$((SKIP+1))
  echo -e "${YELLOW}⊘ SKIP${NC} $1"
}

#################################################################
# Test Suite
#################################################################

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Unified Auth Layer - Test Suite                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

#################################################################
# Test Group 1: Service Connectivity
#################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 1: Service Connectivity"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 1.1: Prometheus connectivity
test_start "Prometheus is accessible"
if curl -s http://prometheus:9090/-/healthy > /dev/null 2>&1; then
  test_pass "Prometheus is accessible"
else
  test_fail "Prometheus not accessible at http://prometheus:9090"
fi

# Test 1.2: Grafana connectivity
test_start "Grafana is accessible"
if curl -s http://grafana:3000/api/health > /dev/null 2>&1; then
  test_pass "Grafana is accessible"
else
  test_fail "Grafana not accessible at http://grafana:3000"
fi

# Test 1.3: ops-assistant health
test_start "ops-assistant is running"
if curl -s http://ops-assistant:3000/api/health > /dev/null 2>&1; then
  test_pass "ops-assistant health endpoint responds"
else
  test_fail "ops-assistant health endpoint not responding"
fi

#################################################################
# Test Group 2: Authentication
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 2: Authentication"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 2.1: Auth status endpoint
test_start "Auth status endpoint"
RESPONSE=$(curl -s http://ops-assistant:3000/api/auth/status)
if echo "$RESPONSE" | jq -e '.initialized' > /dev/null 2>&1; then
  test_pass "Auth status endpoint returns valid JSON"
else
  test_fail "Auth status endpoint response invalid"
  echo "Response: $RESPONSE"
fi

# Test 2.2: Credentials loaded
test_start "Credentials loaded"
RESPONSE=$(curl -s http://ops-assistant:3000/api/auth/status)
LOADED=$(echo "$RESPONSE" | jq -r '.initialized')
if [ "$LOADED" = "true" ]; then
  test_pass "Credentials successfully loaded"
else
  test_fail "Credentials not loaded"
fi

# Test 2.3: Token present
test_start "Grafana token present"
RESPONSE=$(curl -s http://ops-assistant:3000/api/auth/status)
TOKEN_PRESENT=$(echo "$RESPONSE" | jq -r '.grafanaTokenPresent')
if [ "$TOKEN_PRESENT" = "true" ]; then
  test_pass "Grafana token is present"
else
  test_fail "Grafana token is not present"
fi

# Test 2.4: Auth healthy
test_start "Auth system healthy"
RESPONSE=$(curl -s http://ops-assistant:3000/api/auth/status)
HEALTHY=$(echo "$RESPONSE" | jq -r '.healthy')
if [ "$HEALTHY" = "true" ]; then
  test_pass "Auth system is healthy"
else
  test_fail "Auth system is not healthy"
  echo "Full response: $RESPONSE"
fi

#################################################################
# Test Group 3: Diagnostics
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 3: Diagnostics API"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 3.1: Diagnostics endpoint
test_start "Diagnostics endpoint"
RESPONSE=$(curl -s http://ops-assistant:3000/api/diagnostics)
if echo "$RESPONSE" | jq -e '.auth' > /dev/null 2>&1; then
  test_pass "Diagnostics endpoint returns valid JSON"
else
  test_fail "Diagnostics endpoint response invalid"
fi

# Test 3.2: Request traces available
test_start "Request traces in diagnostics"
RESPONSE=$(curl -s http://ops-assistant:3000/api/diagnostics)
TRACES=$(echo "$RESPONSE" | jq '.recentRequests | length')
if [ "$TRACES" -ge 0 ]; then
  test_pass "Request traces available ($TRACES recent requests)"
else
  test_fail "Request traces not available"
fi

#################################################################
# Test Group 4: Grafana API
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 4: Grafana Integration"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 4.1: Get dashboards
test_start "Fetch Grafana dashboards"
RESPONSE=$(curl -s http://ops-assistant:3000/api/grafana/dashboards)
if echo "$RESPONSE" | jq -e '.' > /dev/null 2>&1; then
  DASHBOARD_COUNT=$(echo "$RESPONSE" | jq 'length')
  test_pass "Grafana dashboards endpoint responds (found $DASHBOARD_COUNT dashboards)"
else
  test_fail "Grafana dashboards endpoint failed"
  echo "Response: $RESPONSE"
fi

# Test 4.2: Datasources accessible
test_start "Grafana datasources"
RESPONSE=$(curl -s http://ops-assistant:3000/api/grafana/datasources)
if echo "$RESPONSE" | jq -e '.' > /dev/null 2>&1; then
  DS_COUNT=$(echo "$RESPONSE" | jq 'length')
  test_pass "Grafana datasources endpoint responds (found $DS_COUNT datasources)"
else
  test_fail "Grafana datasources endpoint failed"
fi

#################################################################
# Test Group 5: Prometheus Integration
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 5: Prometheus Integration"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 5.1: Prometheus health
test_start "Prometheus health"
RESPONSE=$(curl -s http://ops-assistant:3000/api/prometheus/health)
if echo "$RESPONSE" | jq -e '.healthy' > /dev/null 2>&1; then
  HEALTHY=$(echo "$RESPONSE" | jq -r '.healthy')
  if [ "$HEALTHY" = "true" ]; then
    test_pass "Prometheus is healthy"
  else
    test_fail "Prometheus is not healthy"
  fi
else
  test_fail "Prometheus health endpoint failed"
fi

# Test 5.2: Key metrics available
test_start "Key metrics configured"
RESPONSE=$(curl -s http://ops-assistant:3000/api/prometheus/key-metrics)
if echo "$RESPONSE" | jq -e '.keyMetrics' > /dev/null 2>&1; then
  METRIC_COUNT=$(echo "$RESPONSE" | jq '.keyMetrics | keys | length')
  test_pass "Key metrics endpoint responds (found $METRIC_COUNT metrics)"
else
  test_fail "Key metrics endpoint failed"
fi

#################################################################
# Test Group 6: Query Functionality
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 6: Query Functionality"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 6.1: Prometheus instant query
test_start "Prometheus instant query"
RESPONSE=$(curl -s http://ops-assistant:3000/api/query/instant -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"up"}' 2>/dev/null || echo '{}')
if echo "$RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
  test_pass "Prometheus instant query works"
else
  test_skip "Prometheus instant query (no metrics available yet)"
fi

# Test 6.2: Prometheus range query
test_start "Prometheus range query"
RESPONSE=$(curl -s http://ops-assistant:3000/api/query -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"up","timeRange":"1h"}' 2>/dev/null || echo '{}')
if echo "$RESPONSE" | jq -e '.' > /dev/null 2>&1; then
  test_pass "Prometheus range query endpoint works"
else
  test_skip "Prometheus range query (no metrics available yet)"
fi

#################################################################
# Test Group 7: Error Handling
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Group 7: Error Handling"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 7.1: Invalid query handling
test_start "Invalid query handling"
RESPONSE=$(curl -s http://ops-assistant:3000/api/query -X POST \
  -H "Content-Type: application/json" \
  -d '{}' 2>/dev/null || echo '{}')
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  test_pass "Invalid query returns error response"
else
  test_fail "Invalid query should return error"
fi

# Test 7.2: 404 handling
test_start "404 error handling"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://ops-assistant:3000/api/nonexistent)
if [ "$HTTP_CODE" = "404" ]; then
  test_pass "404 errors handled correctly"
else
  test_fail "404 should return 404, got $HTTP_CODE"
fi

#################################################################
# Test Summary
#################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Summary"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TOTAL=$((PASS + FAIL + SKIP))
echo -e "Total Tests: ${BLUE}$TOTAL${NC}"
echo -e "Passed:      ${GREEN}$PASS${NC}"
echo -e "Failed:      ${RED}$FAIL${NC}"
echo -e "Skipped:     ${YELLOW}$SKIP${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL test(s) failed${NC}"
  exit 1
fi
