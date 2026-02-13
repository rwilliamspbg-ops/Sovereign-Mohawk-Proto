# 🛡️ Sovereign Mohawk Proto

[![Lint Code Base](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml)[![Sync Check](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/sync-check.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/sync-check.yml)
![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)
![Rust Wasm](https://img.shields.io/badge/Wasm-Rust-black?style=flat&logo=webassembly)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)
[![Security Audit](https://img.shields.io/badge/Security-Zero%20Trust%20Audit-blueviolet?logo=dependabot)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/security)
![Last Commit](https://img.shields.io/github/last-commit/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![BFT Resilience](https://img.shields.io/badge/BFT_Safety-55.5%25-green)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/WHITE_PAPER.md)
[![Scale](https://img.shields.io/badge/Scale-10M_Nodes-orange)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/pulls)

## 🛡️ Formally Verified Guarantees
The Sovereign-Mohawk protocol is provably optimal and secure at a 10M node scale:
- **Resilience:** 55.5% Byzantine Fault Tolerance (Theorem 1).
- **Privacy:** (ε=2.0, δ=1e-5)-DP composition (Theorem 2).
- **Optimality:** O(d log n) communication complexity (Theorem 3).
- **Verification:** 200-byte zk-SNARK proofs with 10ms O(1) verify (Theorem 5).

- 
## ⚡ Quick Start

### Prerequisites
* **Go**: 1.22+
* **Rust**: Stable + `wasm32-unknown-unknown` target
* **Docker**: Desktop or Engine with Compose

### 1. Build the Wasm Task
```bash
cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
```

### 2. Launch the Stack
```bash
go mod tidy
docker compose up --build
```

## 🏗️ System Architecture

 Internal Components
| Component | Function |
| :--- | :--- |
| `cmd/node-agent` | The Go runtime utilizing Wasmtime for sandboxed execution. |
| `cmd/orchestrator` | Issues jobs and signs zero-trust manifests (Ed25519). |
| `cmd/fl-aggregator` | Receives gradients with DP-ready clipping. |
| `internal/wasmhost` | Manages [capability-based](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/capabilities.json) host functions. |
| `internal/tpm` | TPM/TEE verification stub for hardware attestation. |

---

## 📊 Observability
Once the stack is running, you can monitor the network via:
* **Dashboard UI**: [http://localhost:8081](http://localhost:8081)
* **Prometheus**: [http://localhost:9090](http://localhost:9090)
* **Grafana**: [http://localhost:3000](http://localhost:3000) (Credentials: `admin` / `admin`)

> **Note**: This environment utilizes a capability-scoped host interface as defined in [capabilities.json](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/capabilities.json). This provides a secure integration point for TPM attestation and Differential Privacy (DP) controls.
