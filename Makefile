# Sovereign Mohawk Protocol - Verification & Build System

.PHONY: all build test audit lint verify clean build-python-lib install-python-sdk test-python-sdk metrics regional-shard strict-auth-smoke-host strict-auth-smoke-container production-readiness mainnet-one-click go-live-gate

all: build verify

build:
	@echo "🏗️  Building Sovereign Mohawk binaries..."
	go build ./...

test:
	@echo "🧪 Running Proof-Driven Design tests..."
	@if [ -f test_all.sh ]; then \
		chmod +x test_all.sh; \
		./test_all.sh; \
	else \
		go test ./...; \
	fi

audit:
	@echo "🔍 Running Security Audit..."
	chmod +x scripts/audit_proofs.sh
	./scripts/audit_proofs.sh

lint:
	@echo "🧹 Running local linting checks..."
	go fmt ./...
	go vet ./...

verify: lint test audit
	@echo "✅ All Formal Proofs and Lints PASSED."

clean:
	@echo "🧹 Cleaning build artifacts..."
	go clean
	rm -f proofs/VERIFICATION_LOG.md
	rm -f libmohawk.so libmohawk.dylib libmohawk.dll libmohawk.h
	@echo "🐍 Cleaning Python artifacts..."
	cd sdk/python && rm -rf build/ dist/ *.egg-info/ __pycache__/ .pytest_cache/

# Python SDK Targets

build-python-lib:
	@echo "🐍 Building MOHAWK Go C-shared library for Python SDK..."
	@if [ "$(shell uname)" = "Darwin" ]; then \
		go build -o libmohawk.dylib -buildmode=c-shared internal/pyapi/api.go; \
		echo "✅ Built libmohawk.dylib"; \
	elif [ "$(shell uname)" = "Linux" ]; then \
		go build -o libmohawk.so -buildmode=c-shared internal/pyapi/api.go; \
		echo "✅ Built libmohawk.so"; \
	else \
		go build -o libmohawk.dll -buildmode=c-shared internal/pyapi/api.go; \
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

python-all: build-python-lib install-python-sdk test-python-sdk
	@echo "🐍 Python SDK fully built, installed, and tested!"

metrics:
	@echo "📈 Starting TPM metrics exporter..."
	go run ./cmd/tpm-metrics

regional-shard:
	@echo "🌐 Launching regional shard profile..."
	./genesis-launch.sh --regional-shard local-us-east

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
