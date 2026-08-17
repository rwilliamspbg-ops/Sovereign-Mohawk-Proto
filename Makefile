# Sovereign-Mohawk Development Commands
# Status: PHASE 1 - CRITICAL FIXES
# Purpose: Simplified common development tasks

.PHONY: help validate setup start stop status logs restart clean test build lint black format push
.PHONY: artifact-summary build-python-lib audit verify
.PHONY: sandbox-up sandbox-down forensics-drill forensics-drill-down forensics-rehearsal validate-formal-tooling-tests
.PHONY: verify-formal-proofs refresh-formal-validation validate-formal validate-formal-container package-formal-verification-artifacts
.PHONY: go-live-gate go-live-gate-strict go-live-gate-advisory golden-path-e2e failure-injection-latency-check
.PHONY: tpm-attestation-closure-check tpm-closure-summary ga-tag-ready-check release-performance-evidence
.PHONY: openapi-spec capability-dashboard-matrix mainnet-one-click local-validation-scripts
.PHONY: simulate-fl-1k benchmarks-reproducibility deploy-to-kind cloud-template-scaffold run-kind-scale-test

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
	@echo "  make simulate-fl-1k  - Run zero-config local FL simulator (1k virtual nodes)"
	@echo "  make benchmarks-reproducibility - Build reproducibility benchmark artifacts"
	@echo "  make deploy-to-kind  - Deploy Helm chart to local kind cluster"
	@echo "  make run-kind-scale-test - Run the stronger local kind scale-test harness"
	@echo "  make run-kind-scale-matrix - Run staged local kind scale matrix (100/300/500)"
	@echo "  make collect-kind-scale-latency - Capture kind scale latency evidence"
	@echo "  make run-kind-scale-evidence - Run matrix + latency evidence together"
	@echo "  make check-test-host-prereqs - Validate local host tools for kind-based evidence"
	@echo "  make install-kind-prereqs-ubuntu - Install kind/kubectl/docker on Ubuntu/Debian"
	@echo "  make cloud-template-scaffold - Show cloud quickstart scaffold assets"
	@echo "  make lint            - Check code with linters (ruff)"
	@echo "  make black           - Check code formatting (black)"
	@echo "  make format          - Auto-format with Black and Ruff"
	@echo "  make local-validation-scripts - Run standalone validation scripts"
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
# Previously `docker-compose exec orchestrator go test ./...` -- this can
# never work: orchestrator's runtime image (cmd/orchestrator/Dockerfile,
# final stage `FROM alpine:latest`) only ever contains the compiled `./main`
# binary plus ca-certificates/libgcc, never a Go toolchain. Confirmed live:
# `go: executable file not found in $PATH` against a running, healthy
# orchestrator container. Matches what `verify:` below already does
# correctly (run on host, with the toolchain guard).
test:
	@bash -c 'source scripts/ensure_go_toolchain.sh && go test ./...'

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
	@bash -c 'source scripts/ensure_go_toolchain.sh && GODEBUG=fips140=on MOHAWK_REQUIRE_FIPS_MODE_FOR_TESTS=true go test ./test -run "^TestFIPSRegression$$"'

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

local-validation-scripts:
	@echo "Running standalone validation scripts..."
	@python3 scripts/validation_test.py || true
	@python3 scripts/comprehensive_local_tests.py || true
	@echo "✓ Standalone validation scripts completed (informational, non-gating)"

simulate-fl-1k:
	@echo "Running local simulator with 1024 virtual nodes..."
	@cd sdk/python && python examples/flower_integrated/local_simulator.py --virtual-nodes 1024 --rounds 3 --ci

benchmarks-reproducibility:
	@echo "Generating reproducibility benchmark artifacts..."
	@bash scripts/benchmark_fedavg_compare.sh
	@python3 scripts/publish_swarm_runtime_benchmarks.py
	@python3 scripts/validate_fedavg_scale_gates.py || true
	@echo "✓ Reproducibility artifacts available under results/metrics and test-results/swarm-runtime"

deploy-to-kind:
	@bash scripts/deploy_to_kind.sh

run-kind-scale-test:
	@bash scripts/check_test_host_prereqs.sh
	@bash scripts/run_kind_scale_test.sh

run-kind-scale-matrix:
	@bash scripts/check_test_host_prereqs.sh
	@bash scripts/run_kind_scale_matrix.sh

collect-kind-scale-latency:
	@bash scripts/check_test_host_prereqs.sh
	@bash scripts/collect_kind_scale_latency.sh

run-kind-scale-evidence:
	@bash scripts/check_test_host_prereqs.sh
	@bash scripts/run_kind_scale_evidence.sh

check-test-host-prereqs:
	@bash scripts/check_test_host_prereqs.sh

install-kind-prereqs-ubuntu:
	@bash scripts/install_kind_prereqs_ubuntu.sh

cloud-template-scaffold:
	@echo "Cloud template scaffolds:"
	@echo "  - deploy/cloud-templates/README.md"
	@echo "  - deploy/cloud-templates/aws-userdata.sh"
	@echo "  - deploy/cloud-templates/gcp-startup.sh"

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

# Referenced by docs/SUPPLY_CHAIN_SECURITY.md, docs/AUDITOR_QUICK_REFERENCE.md, and
# README.md as an existing gate; added here because it didn't actually exist -- see
# proofs/FORMAL_TRACEABILITY_MATRIX.md's Theorem 3 row for how this lint script caught
# a real class of bug (vacuous `True`-concluding theorems) that a plain `lake build`
# does not.
verify-formal-proofs:
	@cd proofs && lake build LeanFormalization Specification Refinement
	@python3 scripts/ci/lint_formal_proof_claims.py --repo-root .

refresh-formal-validation:
	@python3 scripts/ci/generate_formal_validation_report.py --repo-root .

validate-formal:
	@python3 scripts/ci/generate_formal_validation_report.py --repo-root . --check

validate-formal-container:
	@bash scripts/ci/run_formal_validation_in_container.sh

package-formal-verification-artifacts:
	@bash scripts/ci/generate_formal_proof_artifacts.sh

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
