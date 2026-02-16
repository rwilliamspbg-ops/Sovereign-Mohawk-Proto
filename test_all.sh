#!/bin/bash
set -e
echo "🧪 Running Sovereign-Mohawk-Proto Validation..."

# Run Go Tests
go test ./internal/... -v

# Run Simulation
go run cmd/simulate/main.go --nodes 5

echo "✅ Build and Logic verified against Professional Evaluation Specs."
