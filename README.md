# Sovereign-Mohawk-Proto
The reference node agent + MOHAWK runtime (Go + Wasmtime + manifests + TPM stub).  A tiny FL pipeline to prove the security model.  A dashboard + monitoring shell you can later point at Sovereign_Map/Federated_Learning data.

Sovereign_Map_Federated_Learning: real FL logic, models, optimizers.

Sovereign-Map / Sovereign-Map-V2: orchestration + business logic.

Autonomous-Mapping: mapping agents and tasks.

# Sovereign Mohawk Proto

Small-scale prototype of the MOHAWK execution model:

- Go + Wasmtime node agent with capability-based host funcs
- Signed zero-trust manifests from an orchestrator
- FL aggregator with gradient clipping (DP-ready)
- Wasm-based FL client module
- Basic user dashboard and operator observability stack

## Layout

- cmd/orchestrator: issues jobs + signed manifests
- cmd/fl-aggregator: receives gradients, clips norms
- cmd/node-agent: node runtime (Go + Wasmtime)
- cmd/api-dashboard: simple web UI for overview
- internal/manifest: manifest types + Ed25519 verify
- internal/wasmhost: Wasmtime host & capabilities
- internal/tpm: TPM/TEE verification stub
- wasm-modules/fl_task: Rust Wasm client
- monitoring: Prometheus + Grafana

## Prereqs

- Go 1.22+
- Rust + cargo
- Docker + docker compose

## Build Wasm

```bash
cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
cd ../../

Run locally (Docker)

go mod tidy
docker compose up --build


Services:

Orchestrator: http://localhost:8080

FL Aggregator: http://localhost:8090

Dashboard API/UI: http://localhost:8081

Prometheus: http://localhost:9090

Grafana: http://localhost:3000 (admin / admin)

What happens
Node agents ask /jobs/next on the orchestrator.

Orchestrator returns a Wasm module + signed manifest.

Node agent verifies TPM (stub), manifest signature, and wasm hash.

Node agent runs the Wasm task with Wasmtime, using only allowed capabilities.

Wasm task logs and submits dummy gradients to the FL aggregator.

Aggregator receives gradients and clips them.

This repo is a minimal skeleton to be integrated with:

Sovereign_Map_Federated_Learning (real FL)

Sovereign-Map / V2 (real orchestration)

Autonomous-Mapping (real mapping tasks)


## 3. Concrete move into existing projects

Once `Sovereign-Mohawk-Proto` is up and running:

1. **Node agent into Sovereign_Map_Federated_Learning**

   - Copy `internal/manifest`, `internal/wasmhost`, `internal/tpm`, and `cmd/node-agent` into that repo under a new module, e.g. `/mohawk/node-agent`.  
   - Replace the dummy `FLSend` with calls to your real FL client code (model updates, secure upload, DP).  
   - Keep the Wasm contract stable: `run_task`, `env.log`, `env.submit_gradients`.

2. **Orchestrator into Sovereign-Map / Sovereign-Map-V2**

   - Move the orchestrator logic into that repo’s main API service:  
     - Add manifest construction and signing to your existing job model.  
     - Replace `loadWasm()` with real model‑specific Wasm bundles for FL or mapping jobs.  
   - Add your existing auth, tokenomics, and job scheduling around `/jobs/next`.

3. **Autonomous-Mapping integration**

   - For each mapping tool you want sandboxed, wrap it as a Wasm module that implements `run_task` and uses only host functions you allow (e.g. `GET_LIDAR_FRAME`, `GET_CAMERA_FRAME`, `SUBMIT_MAP_TILE`).  
   - Plug those modules into the same orchestrator path, with manifests that expose only the correct capabilities and data scopes.

4. **Dashboard + metrics**

   - Point the `api-dashboard` service at your real DB or metrics store from Sovereign-Map instead of static values.  
   - Export `/metrics` from the orchestrator, FL aggregator, and node agent using Prometheus client libraries and extend the Grafana dashboard panels.

## 4. GitHub initial commit flow

In a fresh folder:

```bash
git init
git remote add origin git@github.com:rwilliamspbg-ops/Sovereign-Mohawk-Proto.git

# create all files as specified (structure + contents)
go mod tidy
cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
cd ../..

git add .
git commit -m "Initial MOHAWK prototype: orchestrator, node agent, FL aggregator, dashboard, monitoring"
git push -u origin main

