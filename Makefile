# Sovereign-Mohawk Development Commands
# Status: PHASE 1 - CRITICAL FIXES
# Purpose: Simplified common development tasks

.PHONY: help validate setup start stop status logs restart clean test build lint black format push
.PHONY: artifact-summary build-python-lib audit verify
.PHONY: sandbox-up sandbox-down forensics-drill forensics-drill-down forensics-rehearsal validate-formal-tooling-tests
.PHONY: go-live-gate go-live-gate-strict go-live-gate-advisory golden-path-e2e failure-injection-latency-check
.PHONY: tpm-attestation-closure-check tpm-closure-summary ga-tag-ready-check release-performance-evidence
.PHONY: openapi-spec capability-dashboard-matrix mainnet-one-click

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
	@echo "  make build-python-lib - Build the Python SDK shared library"
	@echo "  make verify          - Run repository verification checks"
	@echo "  make artifact-summary - Regenerate captured artifact summary and manifest"
	@echo "  make openapi-spec    - Generate the OpenAPI spec artifact"
	@echo "  make capability-dashboard-matrix - Generate dashboard matrix evidence"
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

build-python-lib:
	@echo "Building MOHAWK Go C-shared library for Python SDK..."
	@bash -c 'source scripts/ensure_go_toolchain.sh && go build -o libmohawk.so -buildmode=c-shared internal/pyapi/api.go'

audit:
	@chmod +x scripts/audit_proofs.sh
	@./scripts/audit_proofs.sh

verify:
	@echo "Running repository verification checks..."
	@bash -c 'source scripts/ensure_go_toolchain.sh && go test ./...'
	@$(MAKE) audit

fips-regression:
	@bash -lc 'source scripts/ensure_go_toolchain.sh && GODEBUG=fips140=on MOHAWK_REQUIRE_FIPS_MODE_FOR_TESTS=true go test ./test -run "^TestFIPSRegression$$"'

artifact-summary:
	@bash scripts/manage_artifacts.sh --summary --apply

openapi-spec:
	@python3 scripts/generate_openapi_spec.py --output results/api/openapi.json --server-url https://localhost:8080

capability-dashboard-matrix:
	@python3 scripts/generate_capability_dashboard_matrix.py --output results/go-live/capability_dashboard_matrix.md

release-performance-evidence:
	@python3 scripts/generate_release_performance_evidence.py

go-live-gate:
	@python3 scripts/validate_go_live_gates.py

go-live-gate-strict:
	@python3 scripts/validate_go_live_gates.py --host-preflight-mode strict

go-live-gate-advisory:
	@python3 scripts/validate_go_live_gates.py --host-preflight-mode advisory

failure-injection-latency-check:
	@python3 scripts/validate_failure_injection_latency.py

tpm-attestation-closure-check:
	@python3 scripts/validate_tpm_attestation_closure.py

tpm-closure-summary:
	@python3 scripts/generate_tpm_closure_summary.py

ga-tag-ready-check:
	@python3 scripts/enforce_ga_tag_safety.py --tag v1.0.0

mainnet-one-click:
	@chmod +x scripts/mainnet_one_click.sh
	@./scripts/mainnet_one_click.sh

golden-path-e2e:
	@bash scripts/golden_path_e2e.sh

forensics-rehearsal:
	@echo "Running compact forensics rehearsal (drill + cleanup)..."
	@set -e; \
	cleanup() { ./scripts/launch_sandbox.sh --down >/dev/null 2>&1 || true; }; \
	trap cleanup EXIT; \
	$(MAKE) forensics-drill

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
	@echo "Running local Byzantine forensics drill..."
	@./scripts/launch_sandbox.sh --no-build || ./scripts/launch_sandbox.sh
	@bash scripts/extract_byzantine_forensics.sh --since 15m --output results/forensics/byzantine_rejections_local.md --metrics-json results/forensics/byzantine_forensics_metrics_local.json
	@bash scripts/quantum_kex_rotation_drill.sh --dry-run
	@echo "✓ Forensics artifacts written to results/forensics/"

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
