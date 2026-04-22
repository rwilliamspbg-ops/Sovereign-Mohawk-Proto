#!/bin/bash
# Validate development environment prerequisites
# Status: PHASE 1 - CRITICAL FIXES
# Purpose: Automated prerequisite checker to prevent configuration errors

set -e

echo "🔍 Validating Sovereign-Mohawk Development Environment..."
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    ((ERRORS++))
else
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓ Docker installed${NC}: $DOCKER_VERSION"
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
fi

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ Docker daemon is running${NC}"
fi

# Check required files
REQUIRED_FILES=(
    "docker-compose.yml"
    "cmd/orchestrator/main.go"
    "sdk/python"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        echo -e "${GREEN}✓ Found $file${NC}"
    else
        echo -e "${RED}❌ Missing $file${NC}"
        ((ERRORS++))
    fi
done

# Check environment file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ No .env file found - will use defaults${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ .env file found${NC}"
fi

# Check available disk space (require 5GB)
DISK_AVAILABLE=$(df . | awk 'NR==2 {print $4}')
DISK_REQUIRED=$((5 * 1024 * 1024)) # 5GB in KB

if [ "$DISK_AVAILABLE" -lt "$DISK_REQUIRED" ]; then
    echo -e "${YELLOW}⚠ Low disk space: $(($DISK_AVAILABLE / 1024 / 1024))GB available, 5GB recommended${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ Sufficient disk space${NC}"
fi

# Check available memory (require 4GB)
if command -v free &> /dev/null; then
    MEM_AVAILABLE=$(free -h | awk '/^Mem:/ {print $7}')
    echo -e "${GREEN}✓ Available memory: $MEM_AVAILABLE${NC}"
fi

# Check Go installation (optional for development)
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    echo -e "${GREEN}✓ Go installed${NC}: $GO_VERSION"
else
    echo -e "${YELLOW}⚠ Go not found (optional for development)${NC}"
    ((WARNINGS++))
fi

# Check Python installation (optional for Python SDK development)
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python3 installed${NC}: $PYTHON_VERSION"
else
    echo -e "${YELLOW}⚠ Python3 not found (optional for SDK development)${NC}"
    ((WARNINGS++))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All required dependencies found!${NC}"
else
    echo -e "${RED}❌ Found $ERRORS critical issue(s)${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s)${NC}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -gt 0 ]; then
    exit 1
fi

exit 0
