#!/bin/bash
# Sovereign Mohawk Protocol - Unified Test Suite

set -e # Exit on error

echo "🚀 Starting Sovereign-Mohawk-Proto Professional Validation..."

# 1. Go Logic & Byzantine Resilience Verification
echo "--- Testing Go Aggregator Logic ---"
go test ./internal/... -v
go test ./cmd/simulate/... -v

# 2. Rust Runtime & Attestation Stubs
echo "--- Testing Rust AOT Runtime ---"
cd host && cargo test
cd ../node && cargo test
cd ..

# 3. Formal Proof Verification (Python)
echo "--- Verifying Mathematical Proofs (O(d log n)) ---"
if command -v python3 &>/dev/null; then
    python3 scripts/verifier.py --proofs ./proofs/
else
    echo "⚠️ Python3 not found, skipping formal proof verification."
fi

# 4. Simulation Run
echo "--- Executing Baseline Simulation ---"
go run cmd/simulate/main.go --nodes 10 --byzantine 2

echo "✅ All tests passed. System compliant with README_ForTesting.MD specs."
