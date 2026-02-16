# 🧪 Testing & Evaluation Procedures: Sovereign Mohawk Protocol

This document outlines the professional testing suite and monitoring specifications for the Sovereign Mohawk Proto (SMP) reference node and MOHAWK runtime.

## 1. Testing Procedures

### A. Unit & Logic Verification
Validate the Go-based aggregator and Rust-based attestation logic.
* **Command:** `go test ./test/... -v`
* **Objective:** Ensure `aggregator.go` correctly implements Multi-Krum Byzantine filtering and 55.5% resilience thresholds.
* **Rust Validation:** Run `cargo test` within `/host` and `/node` to verify Wasm module loading and TPM signature stubs.

### B. Simulation Scaling (Stress Test)
Simulate the O(d log n) communication complexity across virtual shards.
* **Procedure:** 1. Spin up the simulation environment: `docker-compose up --build`.
    2. Execute the simulation entry point: `go run cmd/simulate/main.go`.
* **Evaluation:** Monitor memory consumption (target: <95% footprint vs. standard FL) and metadata overhead.

### C. Security & Formal Proof Verification
Verify that the implementation adheres to the formal theorems (Theorems 1, 4, and 5).
* **Proof Check:** `python3 scripts/verifier.py --proofs ./proofs/`
* **Expectation:** Validates 10ms zk-SNARK verification times and Byzantine Fault Tolerance (BFT) safety limits.

---

## 2. Evaluation Specifications

### Performance Benchmarks
| Metric | Professional Standard | SMP Target |
| :--- | :--- | :--- |
| **Verification Speed** | < 50ms | **10ms (zk-SNARK)** |
| **Byzantine Resilience** | 33.3% (Standard BFT) | **55.5% (Theorem 1)** |
| **Comm. Complexity** | O(d * n) | **O(d log n)** |
| **Straggler Tolerance** | 90% | **99.99% (Theorem 4)** |

### Monitoring & Observability
* **Dashboard:** Access the monitoring shell via the Grafana datasource configured in `/monitoring`.
* **Key Logs:** Filter for `[LIVENESS]` and `[ATTESTATION_SUCCESS]` tags to track real-time node health.
* **Audit Trail:** Verify `capabilities.json` against runtime manifests to ensure zero-trust compliance.

## 3. Professional Certification
To certify a node for the Sovereign Map ecosystem, it must pass the `200_Node_TEST.md` suite without a single attestation failure.
