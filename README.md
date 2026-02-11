# 🛡️ Sovereign Mohawk Proto

[![Lint Code Base](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml)
![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)
![Rust Wasm](https://img.shields.io/badge/Wasm-Rust-black?style=flat&logo=webassembly)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)
![Last Commit](https://img.shields.io/github/last-commit/rwilliamspbg-ops/Sovereign-Mohawk-Proto)

**MOHAWK Runtime & Reference Node Agent**
A tiny Federated Learning (FL) pipeline built to prove the security model for decentralized spatial intelligence. This repo serves as the secure execution skeleton (Go + Wasmtime + TPM) for the broader Sovereign Map ecosystem.

## 🧩 Ecosystem Integration
This prototype is designed to be integrated with:
* **Sovereign Map Federated Learning**: Real FL logic, models, and optimizers.
* **Sovereign-Map-V2**: Orchestration and business logic.
* **Autonomous-Mapping**: Mapping agents and task management.

---

## ⚡ Quick Start

### Prerequisites
* **Go**: 1.22+
* **Rust**: Stable + `wasm32-unknown-unknown` target
* **Docker**: Desktop or Engine with Compose

### 1. Build the Wasm Task
```bash
cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
cd ../../

### 2. Launch the Stack

'''bash
go mod tidy
docker compose up --build

## 🏗️ System Architecture

Internal Components

| Component | Function |
| :--- | :--- |
| cmd/node-agent | The Go runtime utilizing Wasmtime for sandboxed execution. |

## 📊 Observability

Once the stack is running, you can monitor the network via:

Dashboard UI: http://localhost:8081
Prometheus: http://localhost:9090
Grafana: http://localhost:3000 (Credentials: admin / admin)

Capability‑scoped host interface.

A clear place to plug TPM attestation and DP controls.
Note: This environment utilizes a capability-scoped host interface as defined in capabilities.json. This provides a secure integration point for TPM attestation and Differential Privacy (DP) controls.


Would you like me to help you set up a **GitHub Action** to automatically validate that your `capabilities.json` stays in sync with the host functions defined in your Go code?
