#!/bin/bash
# Docker Compose service information display
# Status: PHASE 1 - CRITICAL FIXES
# Purpose: Show status and connection info for all services

set -e

COMPOSE_CMD=$(command -v docker-compose >/dev/null 2>&1 && echo "docker-compose" || echo "docker compose")

echo "🔍 Sovereign-Mohawk Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get running services
$COMPOSE_CMD ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No services running"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Service Information:"
echo ""

# Orchestrator
if $COMPOSE_CMD ps orchestrator 2>/dev/null | grep -q "Up"; then
    echo "▸ Orchestrator"
    echo "   Status: ✓ Running"
    echo "   Port: 8090 (default)"
    echo "   Logs: docker-compose logs -f orchestrator"
    echo ""
fi

# API
if $COMPOSE_CMD ps api 2>/dev/null | grep -q "Up"; then
    echo "▸ API Server"
    echo "   Status: ✓ Running"
    echo "   Port: 8080 (default)"
    echo "   Metrics: 8081 (default)"
    echo "   Logs: docker-compose logs -f api"
    echo ""
fi

# Node
if $COMPOSE_CMD ps node 2>/dev/null | grep -q "Up"; then
    echo "▸ Node"
    echo "   Status: ✓ Running"
    echo "   Port: 9080 (default)"
    echo "   Logs: docker-compose logs -f node"
    echo ""
fi

# Metrics Exporter
if $COMPOSE_CMD ps metrics-exporter 2>/dev/null | grep -q "Up"; then
    echo "▸ Metrics Exporter"
    echo "   Status: ✓ Running"
    echo "   Port: 9090 (default)"
    echo "   Logs: docker-compose logs -f metrics-exporter"
    echo ""
fi

echo "📚 Quick Commands:"
echo "   View all logs:     $COMPOSE_CMD logs -f"
echo "   Stop services:     $COMPOSE_CMD down"
echo "   Restart service:   $COMPOSE_CMD restart <service>"
echo "   Shell access:      $COMPOSE_CMD exec <service> /bin/bash"
echo ""
