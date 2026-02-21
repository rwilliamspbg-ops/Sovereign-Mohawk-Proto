# Sovereign Mohawk Protocol - Verification & Build System

.PHONY: all build test audit lint verify clean build-python-lib install-python-sdk test-python-sdk

all: build verify

build:
	@echo "🏗️  Building Sovereign Mohawk binaries..."
	go build ./...

test:
	@echo "🧪 Running Proof-Driven Design tests..."
	chmod +x test_all.sh
	./test_all.sh

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
