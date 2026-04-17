# Sovereign Mohawk Protocol - Verification & Build System

.PHONY: all build test audit lint refresh-proof-artifacts verify clean go-env build-python-lib install-python-sdk test-python-sdk demo-train-synthesize-dataset demo-synthesizebio-docker metrics regional-shard full-stack-3-nodes full-stack-3-nodes-down sandbox-up sandbox-down forensics-drill forensics-drill-down forensics-rehearsal strict-auth-smoke-host strict-auth-smoke-container production-readiness mainnet-one-click go-live-gate go-live-gate-advisory go-live-gate-strict golden-path-e2e failure-injection-latency-check fedavg-scale-gate tpm-attestation-closure-check tpm-closure-summary ga-tag-ready-check release-performance-evidence openapi-spec capability-dashboard-matrix benchmark-gpu full-validation-fast full-validation-deep validation-trends validation-diff-summary workflow-pin-check fips-runtime-check fips-regression pqc-health tamper-evident-export tamper-evident-e2e-test artifact-retention-dryrun artifact-retention-apply artifact-summary testnet-gui-windows

all: build verify

build:
	@echo "🏗️  Building Sovereign Mohawk binaries..."
	bash -c 'source scripts/ensure_go_toolchain.sh && go build ./...'

test:
	@echo "🧪 Running Proof-Driven Design tests..."
	@if [ -f test_all.sh ]; then \
		chmod +x test_all.sh; \
		./test_all.sh; \
	else \
		bash -c 'source scripts/ensure_go_toolchain.sh && go test -count=1 ./...'; \
	fi

refresh-proof-artifacts:
	@echo "🧾 Refreshing proof freshness artifacts..."
	python3 scripts/refresh_proof_artifacts.py

audit:
	@echo "🔍 Running Security Audit..."
	chmod +x scripts/audit_proofs.sh
	./scripts/audit_proofs.sh

lint:
	@echo "🧹 Running local linting checks..."
	bash -c 'source scripts/ensure_go_toolchain.sh && go fmt ./...'
	bash -c 'source scripts/ensure_go_toolchain.sh && go vet ./...'

verify: lint test refresh-proof-artifacts audit
	@echo "✅ All Formal Proofs and Lints PASSED."

clean:
	@echo "🧹 Cleaning build artifacts..."
	bash -c 'source scripts/ensure_go_toolchain.sh && go clean'
	rm -f proofs/VERIFICATION_LOG.md
	rm -f libmohawk.so libmohawk.dylib libmohawk.dll libmohawk.h
	@echo "🐍 Cleaning Python artifacts..."
	cd sdk/python && rm -rf build/ dist/ *.egg-info/ __pycache__/ .pytest_cache/

go-env:
	@echo "🔧 Active Go toolchain context..."
	bash scripts/go_with_toolchain.sh

# Python SDK Targets

build-python-lib:
	@echo "🐍 Building MOHAWK Go C-shared library for Python SDK..."
	@if [ "$(shell uname)" = "Darwin" ]; then \
		bash -c 'source scripts/ensure_go_toolchain.sh && go build -o libmohawk.dylib -buildmode=c-shared internal/pyapi/api.go'; \
		echo "✅ Built libmohawk.dylib"; \
	elif [ "$(shell uname)" = "Linux" ]; then \
		bash -c 'source scripts/ensure_go_toolchain.sh && go build -o libmohawk.so -buildmode=c-shared internal/pyapi/api.go'; \
		echo "✅ Built libmohawk.so"; \
	else \
		bash -c 'source scripts/ensure_go_toolchain.sh && go build -o libmohawk.dll -buildmode=c-shared internal/pyapi/api.go'; \
		echo "✅ Built libmohawk.dll"; \
	fi

install-python-sdk: build-python-lib
	@echo "📦 Installing Python SDK..."
	cd sdk/python && pip install -e .
	@echo "✅ Python SDK installed successfully"

test-python-sdk: build-python-lib
	@echo "🧪 Running Python SDK tests..."
	cd sdk/python && python -m pytest tests/ -v

demo-python-sdk: build-python-lib
	@echo "🎬 Running Python SDK demo..."
	cd sdk/python && python examples/basic_usage.py

demo-train-synthesize-dataset:
	@echo "🧬 Training synthesize.bio dataset export..."
	@if [ -z "$(DATASET)" ] && [ -z "$(INPUT_CSV)" ]; then \
		echo "usage: make demo-train-synthesize-dataset DATASET=<dataset-url-or-uuid> [LABEL_COLUMN=target] [OUTPUT=results/demo/synthesize_bio/training_report.json]"; \
		echo "   or: make demo-train-synthesize-dataset INPUT_CSV=<path-to-export.csv> [LABEL_COLUMN=target] [OUTPUT=results/demo/synthesize_bio/training_report.json]"; \
		exit 1; \
	fi
	@if [ -n "$(INPUT_CSV)" ]; then \
		INPUT_CSV="$(INPUT_CSV)" LABEL_COLUMN="$(LABEL_COLUMN)" OUTPUT="$(OUTPUT)" ./scripts/run_synthesizebio_demo.sh; \
	else \
		DATASET="$(DATASET)" LABEL_COLUMN="$(LABEL_COLUMN)" OUTPUT="$(OUTPUT)" ./scripts/run_synthesizebio_demo.sh; \
	fi

demo-synthesizebio-docker:
	@echo "🐳 Running synthesize.bio demo, validation, and artifact capture in Docker..."
	@if [ -z "$(DATASET)" ] && [ -z "$(INPUT_CSV)" ]; then \
		echo "usage: make demo-synthesizebio-docker DATASET=<dataset-url-or-uuid> [LABEL_COLUMN=target] [VALIDATION_PROFILE=fast]"; \
		echo "   or: make demo-synthesizebio-docker INPUT_CSV=<path-to-export.csv> [LABEL_COLUMN=target] [VALIDATION_PROFILE=fast]"; \
		exit 1; \
	fi
	@if [ -n "$(INPUT_CSV)" ]; then \
		INPUT_CSV="$(INPUT_CSV)" LABEL_COLUMN="$(LABEL_COLUMN)" VALIDATION_PROFILE="$(VALIDATION_PROFILE)" OUTPUT="$(OUTPUT)" ARTIFACT_DIR="$(ARTIFACT_DIR)" ./scripts/run_synthesizebio_demo_in_docker.sh; \
	else \
		DATASET="$(DATASET)" LABEL_COLUMN="$(LABEL_COLUMN)" VALIDATION_PROFILE="$(VALIDATION_PROFILE)" OUTPUT="$(OUTPUT)" ARTIFACT_DIR="$(ARTIFACT_DIR)" ./scripts/run_synthesizebio_demo_in_docker.sh; \
	fi

python-all: build-python-lib install-python-sdk test-python-sdk
	@echo "🐍 Python SDK fully built, installed, and tested!"

metrics:
	@echo "📈 Starting TPM metrics exporter..."
	bash -c 'source scripts/ensure_go_toolchain.sh && go run ./cmd/tpm-metrics'

regional-shard:
	@echo "🌐 Launching regional shard profile..."
	./genesis-launch.sh --regional-shard local-us-east

full-stack-3-nodes:
	@echo "🌐 Launching full local stack (orchestrator + 3 node agents)..."
	./scripts/launch_full_stack_3_nodes.sh --no-build

full-stack-3-nodes-down:
	@echo "🛑 Stopping full local stack..."
	./scripts/launch_full_stack_3_nodes.sh --down

testnet-gui-windows:
	@echo "🪟 Building the Windows testnet GUI executable..."
	mkdir -p dist/windows
	bash -c 'source scripts/ensure_go_toolchain.sh && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o dist/windows/testnet-gui.exe ./cmd/testnet-gui'
	@echo "✅ Built dist/windows/testnet-gui.exe"

sandbox-up:
	@echo "🧪 Launching Mini-Mohawk sandbox..."
	./scripts/launch_sandbox.sh --no-build

sandbox-down:
	@echo "🛑 Stopping Mini-Mohawk sandbox..."
	./scripts/launch_sandbox.sh --down

forensics-drill:
	@echo "🔎 Running local Byzantine forensics drill..."
	./scripts/launch_sandbox.sh --no-build || ./scripts/launch_sandbox.sh
	bash scripts/extract_byzantine_forensics.sh --since 15m --output results/forensics/byzantine_rejections_local.md --metrics-json results/forensics/byzantine_forensics_metrics_local.json
	@echo "✅ Forensics artifacts:"
	@echo "   - results/forensics/byzantine_rejections_local.md"
	@echo "   - results/forensics/byzantine_forensics_metrics_local.json"

forensics-drill-down:
	@echo "🛑 Stopping sandbox after forensics drill..."
	./scripts/launch_sandbox.sh --down

forensics-rehearsal:
	@echo "🧪 Running compact forensics rehearsal (drill + cleanup)..."
	@set -e; \
	cleanup() { ./scripts/launch_sandbox.sh --down >/dev/null 2>&1 || true; }; \
	trap cleanup EXIT; \
	$(MAKE) forensics-drill
	@echo "✅ Forensics rehearsal complete (sandbox cleaned up)."

strict-auth-smoke-host: build-python-lib
	@echo "🔐 Running strict auth/role smoke checks on host..."
	MOHAWK_API_AUTH_MODE=file-only \
	MOHAWK_API_TOKEN_FILE=$$PWD/runtime-secrets/mohawk_api_token \
	MOHAWK_API_ENFORCE_ROLES=true \
	MOHAWK_API_BRIDGE_ALLOWED_ROLES=bridge,admin \
	MOHAWK_API_HYBRID_ALLOWED_ROLES=verifier,admin \
	PYTHONPATH=sdk/python python scripts/strict_auth_smoke.py --lib-path ./libmohawk.so --token-file ./runtime-secrets/mohawk_api_token

strict-auth-smoke-container: build-python-lib
	@echo "🐳 Running strict auth/role smoke checks in container (glibc path)..."
	docker compose run --rm -v "$$PWD":/workspace -w /workspace tpm-metrics \
		env MOHAWK_API_AUTH_MODE=file-only MOHAWK_API_TOKEN_FILE=/workspace/runtime-secrets/mohawk_api_token MOHAWK_API_ENFORCE_ROLES=true MOHAWK_API_BRIDGE_ALLOWED_ROLES=bridge,admin MOHAWK_API_HYBRID_ALLOWED_ROLES=verifier,admin \
		python3 /workspace/scripts/strict_auth_smoke.py --lib-path /workspace/libmohawk.so --token-file /workspace/runtime-secrets/mohawk_api_token

production-readiness: verify strict-auth-smoke-host strict-auth-smoke-container
	@echo "✅ Production readiness checks passed (verify + strict auth smoke host/container)."

mainnet-one-click:
	@echo "🚀 Running one-click Mainnet + PQC contract readiness pipeline..."
	chmod +x scripts/mainnet_one_click.sh
	./scripts/mainnet_one_click.sh

go-live-gate:
	@echo "📋 Validating formal go-live production gates..."
	python3 scripts/validate_go_live_gates.py

go-live-gate-strict:
	@echo "📋 Validating formal go-live production gates (strict host preflight)..."
	python3 scripts/validate_go_live_gates.py --host-preflight-mode strict

go-live-gate-advisory:
	@echo "📋 Validating formal go-live production gates (advisory host preflight)..."
	python3 scripts/validate_go_live_gates.py --host-preflight-mode advisory

golden-path-e2e:
	@echo "🧪 Running end-to-end golden path evidence scenario..."
	bash scripts/golden_path_e2e.sh

failure-injection-latency-check:
	@echo "⏱️ Validating failure-injection latency evidence against SLO baseline..."
	python3 scripts/validate_failure_injection_latency.py

fedavg-scale-gate:
	@echo "📈 Validating FedAvg scale gate metrics and throughput floors..."
	python3 scripts/validate_fedavg_scale_gates.py

tpm-attestation-closure-check:
	@echo "🔐 Validating TPM attestation production-closure evidence matrix..."
	python3 scripts/validate_tpm_attestation_closure.py

tpm-closure-summary:
	@echo "📊 Generating TPM closure dashboard summary artifacts..."
	python3 scripts/generate_tpm_closure_summary.py

ga-tag-ready-check:
	@echo "🛡️ Enforcing GA tag safety policy..."
	python3 scripts/enforce_ga_tag_safety.py --tag v1.0.0

release-performance-evidence:
	@echo "📈 Building release performance evidence index..."
	python3 scripts/generate_release_performance_evidence.py

openapi-spec:
	@echo "📘 Generating OpenAPI spec artifact..."
	python3 scripts/generate_openapi_spec.py --output results/api/openapi.json --server-url https://localhost:8080

capability-dashboard-matrix:
	@echo "🧭 Generating capability-to-dashboard verification matrix..."
	python3 scripts/generate_capability_dashboard_matrix.py --output results/go-live/capability_dashboard_matrix.md

benchmark-gpu:
	@echo "⚡ Running CPU vs GPU vs NPU benchmark matrix..."
	python3 scripts/benchmark_accelerator_backends.py --output-md results/metrics/accelerator_backend_compare.md --output-json results/metrics/accelerator_backend_compare.json

full-validation-fast:
	@echo "🧪 Running full validation suite (fast profile)..."
	python3 tests/scripts/python/run_full_validation_suite.py --profile fast

full-validation-deep:
	@echo "🧪 Running full validation suite (deep profile)..."
	python3 tests/scripts/python/run_full_validation_suite.py --profile deep

validation-trends:
	@echo "📉 Checking validation trend thresholds..."
	python3 tests/scripts/ci/check_validation_trends.py

validation-diff-summary:
	@echo "📝 Writing validation diff summary..."
	python3 tests/scripts/ci/write_validation_diff_summary.py

workflow-pin-check:
	@echo "📌 Validating workflow action pin policy..."
	python3 scripts/ci/check_workflow_action_pins.py

fips-runtime-check:
	@echo "🛡️ Verifying Go runtime is in FIPS mode..."
	bash -c 'source scripts/ensure_go_toolchain.sh && GODEBUG=fips140=on go run ./scripts/fips_runtime_check'

fips-regression:
	@echo "🧪 Running FIPS regression tests (TLS/keygen/signing)..."
	bash -c 'source scripts/ensure_go_toolchain.sh && GODEBUG=fips140=on MOHAWK_REQUIRE_FIPS_MODE_FOR_TESTS=true go test ./test -run "^TestFIPSRegression$$"'

pqc-health:
	@echo "🧪 Running PQC posture self-audit..."
	@MOHAWK_TRANSPORT_KEX_MODE=$${MOHAWK_TRANSPORT_KEX_MODE:-x25519-mlkem768-hybrid}; \
		export MOHAWK_TRANSPORT_KEX_MODE; \
		echo "KEX: $$MOHAWK_TRANSPORT_KEX_MODE"; \
		python3 scripts/validate_transport_kex_mode.py --repo-root . --check-runtime-env; \
		python3 scripts/validate_pqc_contract_ready.py

tamper-evident-export:
	@echo "🧾 Exporting tamper-evident audit event bundle..."
	python3 scripts/export_tamper_evident_events.py --output-dir results/forensics/tamper-evident-events

tamper-evident-e2e-test:
	@echo "🧪 Running tamper-evident export e2e test..."
	python3 tests/scripts/ci/test_tamper_evident_bundle_e2e.py

artifact-retention-dryrun:
	@echo "🧾 Previewing validation artifact retention plan (dry-run)..."
	bash scripts/manage_artifacts.sh --keep 3 --archive

artifact-retention-apply:
	@echo "🧾 Applying validation artifact retention policy..."
	bash scripts/manage_artifacts.sh --keep 3 --archive --apply

artifact-summary:
	@echo "🧾 Generating canonical artifact summary and manifest..."
	bash scripts/manage_artifacts.sh --keep 3 --summary --apply
