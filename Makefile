# Sovereign-Mohawk-Proto Build System
# Reference: /WHITE_PAPER.md

.PHONY: all tidy verify build clean docker-test

# Default target: prepares and builds the entire stack
all: tidy verify build

# 1. Dependency Management
# Ensures Go 1.24+ compatibility for wazero requirements
tidy:
	@echo "Tidying Go modules..."
	go mod tidy

# 2. Formal Proof Verification
# Executes the integration tests for BFT (Theorem 1) and Convergence (Theorem 6)
verify:
	@echo "Verifying Formal Proofs (Theorems 1-6)..."
	go test -v ./internal/...
	go test -v ./test/integration_test.go

# 3. Binary Compilation
# Builds the Global Aggregator and Edge Node Agent
build:
	@echo "Building Sovereign-Mohawk Binaries..."
	go build -o bin/aggregator ./cmd/aggregator/main.go
	go build -o bin/node-agent ./cmd/node-agent/main.go

# 4. Simulation Environment
# Launches the local 10-node cluster via Docker Compose
deploy:
	@echo "Deploying local 10-node cluster..."
	docker-compose up --build -d

# 5. Cleanup
clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	docker-compose down --rmi local
