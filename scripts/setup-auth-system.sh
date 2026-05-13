#!/bin/bash

#################################################################
# Auth System Setup & Diagnostics Script
# 
# This script helps you:
# 1. Generate Grafana API token
# 2. Configure environment variables
# 3. Run diagnostics on auth configuration
# 4. Validate connectivity
#################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-docker-compose.yml}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Auth System Setup & Diagnostics                         ║${NC}"
echo -e "${BLUE}║ Unified Identity & Observability Layer                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

#################################################################
# Helper Functions
#################################################################

log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

section() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

#################################################################
# Phase 1: Check Prerequisites
#################################################################

section "PHASE 1: Checking Prerequisites"

log_info "Checking required tools..."

if ! command -v docker &> /dev/null; then
  log_error "Docker not found. Please install Docker."
  exit 1
fi
log_success "Docker found"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  log_error "docker-compose not found. Please install Docker Compose."
  exit 1
fi
log_success "docker-compose found"

if ! command -v curl &> /dev/null; then
  log_error "curl not found. Please install curl."
  exit 1
fi
log_success "curl found"

#################################################################
# Phase 2: Generate/Retrieve Grafana Token
#################################################################

section "PHASE 2: Grafana API Token Management"

log_info "Current Grafana URL: $GRAFANA_URL"

# Check if Grafana is running
if curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
  log_success "Grafana is accessible"
  
  # Try to create API token
  log_info "Attempting to create new API token..."
  
  # Check if we can use docker exec (if Grafana is in Docker)
  if docker ps 2>/dev/null | grep -q grafana; then
    log_info "Found Grafana container, using docker exec..."
    
    TOKEN=$(docker exec grafana grafana-cli admin create-api-token \
      --name "ops-assistant" --role Admin 2>/dev/null | grep -oE '[a-f0-9]{32}' || echo "")
    
    if [ -n "$TOKEN" ]; then
      log_success "Generated new Grafana API token"
      echo ""
      echo -e "${YELLOW}⚠  Important: Save this token safely${NC}"
      echo -e "GRAFANA_API_TOKEN=$TOKEN"
      echo ""
    else
      log_warning "Could not generate token via docker. Checking for existing auth..."
    fi
  else
    log_warning "Grafana container not found. Using local HTTP API..."
    
    # Try using default credentials
    log_info "Attempting with default admin credentials..."
    TOKEN=$(curl -s -u admin:admin "$GRAFANA_URL/api/auth/keys" \
      -H "Content-Type: application/json" \
      -d '{"name":"ops-assistant","role":"Admin"}' | grep -o '"key":"[^"]*' | cut -d'"' -f4 || echo "")
    
    if [ -n "$TOKEN" ]; then
      log_success "Generated new Grafana API token"
      echo ""
      echo -e "${YELLOW}⚠  Important: Save this token safely${NC}"
      echo -e "GRAFANA_API_TOKEN=$TOKEN"
      echo ""
    fi
  fi
else
  log_warning "Grafana is not accessible at $GRAFANA_URL"
  log_info "Make sure Grafana is running: docker-compose up grafana -d"
fi

#################################################################
# Phase 3: Environment Configuration
#################################################################

section "PHASE 3: Environment Configuration"

log_info "Checking .env file..."

if [ -f ".env" ]; then
  log_success ".env file exists"
  
  if grep -q "GRAFANA_API_TOKEN" .env; then
    log_success "GRAFANA_API_TOKEN is configured in .env"
  else
    log_warning "GRAFANA_API_TOKEN not found in .env"
    log_info "Add this line to .env:"
    echo "  GRAFANA_API_TOKEN=<your_token_here>"
  fi
else
  log_warning ".env file not found"
  log_info "Creating .env file..."
  
  cat > .env << 'EOF'
# Operations Assistant Configuration
PROMETHEUS_URL=http://prometheus:9090
GRAFANA_URL=http://grafana:3000
GRAFANA_API_TOKEN=<set-your-token-here>
CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173
NODE_ENV=production
PORT=3000
EOF
  
  log_success ".env file created (update GRAFANA_API_TOKEN)"
fi

#################################################################
# Phase 4: Connectivity Diagnostics
#################################################################

section "PHASE 4: Connectivity Diagnostics"

log_info "Testing Prometheus connectivity..."
if curl -s "$PROMETHEUS_URL/-/healthy" > /dev/null 2>&1; then
  log_success "Prometheus is accessible"
  
  # Check for metrics
  METRIC_COUNT=$(curl -s "$PROMETHEUS_URL/api/v1/targets" | grep -o '"health":"up"' | wc -l)
  if [ "$METRIC_COUNT" -gt 0 ]; then
    log_success "Found $METRIC_COUNT active Prometheus targets"
  else
    log_warning "No active Prometheus targets"
  fi
else
  log_error "Prometheus is not accessible at $PROMETHEUS_URL"
  log_info "Make sure Prometheus is running: docker-compose up prometheus -d"
fi

echo ""
log_info "Testing Grafana connectivity..."
if curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
  log_success "Grafana is accessible"
  
  # Get Grafana version
  VERSION=$(curl -s "$GRAFANA_URL/api/health" | grep -o '"version":"[^"]*' | cut -d'"' -f4)
  if [ -n "$VERSION" ]; then
    log_success "Grafana version: $VERSION"
  fi
else
  log_error "Grafana is not accessible at $GRAFANA_URL"
  log_info "Make sure Grafana is running: docker-compose up grafana -d"
fi

#################################################################
# Phase 5: Docker Compose Status
#################################################################

section "PHASE 5: Docker Compose Status"

log_info "Checking docker-compose services..."

if docker-compose ps 2>/dev/null | grep -q ops-assistant; then
  log_success "ops-assistant container is running"
  
  # Check healthcheck
  HEALTH=$(docker inspect ops-assistant --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
  case $HEALTH in
    "healthy")
      log_success "ops-assistant is healthy"
      ;;
    "starting")
      log_warning "ops-assistant is starting..."
      ;;
    "unhealthy")
      log_error "ops-assistant is unhealthy"
      log_info "Checking logs..."
      docker logs ops-assistant | tail -20
      ;;
    *)
      log_info "ops-assistant health status: $HEALTH"
      ;;
  esac
else
  log_warning "ops-assistant container is not running"
  log_info "Start it with: docker-compose up ops-assistant -d"
fi

#################################################################
# Phase 6: Run Auth Diagnostics API
#################################################################

section "PHASE 6: Authentication Diagnostics"

OPS_ASSISTANT_URL="http://localhost:3001"
log_info "Testing diagnostics API at $OPS_ASSISTANT_URL..."

if curl -s "$OPS_ASSISTANT_URL/api/diagnostics" > /dev/null 2>&1; then
  log_success "Diagnostics API is accessible"
  
  log_info "Retrieving authentication status..."
  curl -s "$OPS_ASSISTANT_URL/api/auth/status" | jq '.'
  
  echo ""
  log_info "Retrieving detailed diagnostics..."
  curl -s "$OPS_ASSISTANT_URL/api/diagnostics" | jq '.auth'
else
  log_warning "Diagnostics API not accessible. Make sure ops-assistant is running."
  log_info "Start with: docker-compose up ops-assistant -d"
fi

#################################################################
# Phase 7: Recommendations
#################################################################

section "PHASE 7: Recommendations"

echo ""
log_info "Based on the diagnostics, here are the recommended next steps:"
echo ""
echo "1. Set GRAFANA_API_TOKEN environment variable:"
echo "   export GRAFANA_API_TOKEN=<your_token_here>"
echo ""
echo "2. Start/restart all services:"
echo "   docker-compose down"
echo "   docker-compose up -d"
echo ""
echo "3. Verify ops-assistant is healthy:"
echo "   curl http://localhost:3001/api/health"
echo ""
echo "4. Check authentication status:"
echo "   curl http://localhost:3001/api/auth/status | jq"
echo ""
echo "5. Test Grafana integration:"
echo "   curl http://localhost:3001/api/grafana/dashboards"
echo ""
echo "6. Monitor logs:"
echo "   docker logs -f ops-assistant"
echo ""

log_success "Diagnostics complete!"
