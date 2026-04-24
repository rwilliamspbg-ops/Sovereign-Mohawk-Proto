# Sovereign-Mohawk Development Commands
# Status: PHASE 1 - CRITICAL FIXES
# Purpose: Simplified common development tasks

.PHONY: help validate setup start stop status logs restart clean test build lint black format push
.PHONY: artifact-summary sandbox-up sandbox-down forensics-drill forensics-drill-down validate-formal-tooling-tests

help:
	@echo "Sovereign-Mohawk Development Commands"
	@echo "========================================"
	@echo ""
	@echo "Setup & Validation:"
	@echo "  make validate        - Check development prerequisites"
	@echo "  make setup           - Interactive environment configuration"
	@echo "  make quick-start     - One-command startup (5 minutes)"
	@echo ""
	@echo "Service Management:"
	@echo "  make start           - Start all services"
	@echo "  make start-core      - Start core services only"
	@echo "  make stop            - Stop all services"
	@echo "  make restart         - Restart all services"
	@echo "  make status          - Show service status"
	@echo ""
	@echo "Logs & Debugging:"
	@echo "  make logs            - View all service logs"
	@echo "  make logs-orch       - View orchestrator logs"
	@echo "  make logs-api        - View API logs"
	@echo "  make logs-node       - View node logs"
	@echo "  make logs-metrics    - View metrics exporter logs"
	@echo "  make info            - Show service connection info"
	@echo ""
	@echo "Development & Quality:"
	@echo "  make test            - Run all tests"
	@echo "  make build           - Build all images"
	@echo "  make artifact-summary - Regenerate captured artifact summary and manifest"
	@echo "  make lint            - Check code with linters (ruff)"
	@echo "  make black           - Check code formatting (black)"
	@echo "  make format          - Auto-format with Black and Ruff"
	@echo "  make clean           - Remove containers and volumes"
	@echo ""

# Setup & Validation
validate:
	@bash scripts/validate-dev-environment.sh

setup:
	@bash scripts/configure-dev-env.sh

quick-start:
	@bash scripts/quick-start-dev.sh

# Service Management
start:
	@docker-compose up -d

start-core:
	@docker-compose up -d runtime-secrets-init orchestrator api

stop:
	@docker-compose down

restart:
	@docker-compose restart

status:
	@docker-compose ps

# Logs & Debugging
logs:
	@docker-compose logs -f

logs-orch:
	@docker-compose logs -f orchestrator

logs-api:
	@docker-compose logs -f api

logs-node:
	@docker-compose logs -f node

logs-metrics:
	@docker-compose logs -f metrics-exporter

info:
	@bash scripts/docker-compose-info.sh

# Development
test:
	@docker-compose exec orchestrator go test ./...

build:
	@docker-compose build

artifact-summary:
	@bash scripts/manage_artifacts.sh --summary --apply

lint:
	@echo "Running linters (ruff)..."
	@cd sdk/python && python -m ruff check . || true
	@echo "✓ Lint complete"

black:
	@echo "Checking code formatting (black)..."
	@cd sdk/python && python -m black . --check || true
	@echo "✓ Black check complete"

format:
	@echo "Formatting Python code..."
	@cd sdk/python && python -m black . && echo "✓ Formatted with Black"
	@cd sdk/python && python -m ruff check . --fix && echo "✓ Fixed with Ruff"

clean:
	@docker-compose down -v
	@echo "✓ Cleaned: stopped containers and removed volumes"

# CI compatibility targets
sandbox-up:
	@bash scripts/launch_sandbox.sh --no-build

sandbox-down:
	@bash scripts/launch_sandbox.sh --down

forensics-drill:
	@bash scripts/extract_byzantine_forensics.sh --since 30m --output results/forensics/byzantine_rejections_report.md --metrics-json results/forensics/byzantine_rejections_metrics.json
	@bash scripts/quantum_kex_rotation_drill.sh --dry-run

forensics-drill-down:
	@bash scripts/launch_sandbox.sh --down || true

validate-formal-tooling-tests:
	@python3 tests/scripts/ci/test_formal_validation_container_runner.py
	@python3 tests/scripts/ci/test_formal_validation_report_e2e.py
	@python3 tests/scripts/ci/test_formal_verification_bundle_e2e.py
	@python3 tests/scripts/ci/test_tamper_evident_bundle_e2e.py

# Shortcuts
.PHONY: h v s st r c l lo li

h: help
v: validate
s: start
st: status
r: restart
c: clean
l: logs
lo: logs-orch
li: info
