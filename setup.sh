#!/bin/bash
set -e

echo "🚀 Starting Sovereign-Mohawk-Proto Setup..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_CMD="$ROOT_DIR/scripts/docker-compose-wrapper.sh"

# 1. Build the Rust Wasm Module
echo "📦 Building Wasm modules..."
cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
cd ../..

# 2. Ensure Go dependencies are current
echo "🐹 Tidying Go modules..."
"$ROOT_DIR/scripts/go_with_toolchain.sh" go mod tidy

# 3. Launch Docker Compose
echo "🐳 Launching containers..."
"$COMPOSE_CMD" up --build -d

echo "✅ All services are starting!"
echo "Orchestrator: http://localhost:8080"
echo "Aggregator:   http://localhost:8090"
echo "Dashboard:    http://localhost:8081"
echo "Grafana:      http://localhost:3000"
