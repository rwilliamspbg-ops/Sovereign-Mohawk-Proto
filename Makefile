# Sovereign Mohawk Protocol - Verification & Build System

.PHONY: all build test audit lint verify clean

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
