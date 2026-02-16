# 🧪 Testing & Evaluation: Sovereign Mohawk Protocol

## 1. Automated Test Suite
The following workflows are integrated via GitHub Actions to ensure continuous compliance with the MOHAWK runtime specifications:

* **Logic Verification:** `go test ./internal/...` validates the Byzantine fault tolerance logic.
* **Formal Proofs:** `python3 scripts/verifier.py` checks the mathematical consistency of the O(d log n) complexity.
* **AOT Compilation:** Validates that the Rust-based Wasm modules compile for Ahead-of-Time execution.

## 2. Professional Evaluation Specs
| Category | Requirement | Validation Method |
| :--- | :--- | :--- |
| **Trust Integrity** | Zero-Knowledge Proofs | `scripts/verifier.py` |
| **Throughput** | > 1000 attestations/sec | `cmd/simulate/main.go` |
| **Byzantine Threshold** | 55.5% Resilience | Unit tests in `aggregator_test.go` |

## 3. Monitoring & Observability
For professional deployments, the following metrics must be exported to the monitoring stack defined in `/monitoring`:
* **`mohawk_node_attestation_latency`**: Targeted at **10ms**.
* **`mohawk_aggregator_byzantine_count`**: Real-time tracking of filtered malicious updates.
* **`mohawk_runtime_memory_bytes`**: Ensuring < 5% overhead compared to non-sovereign execution.

## 4. Troubleshooting CI Failures
If the `Proof-Driven Design Verification` or `Build and Test` workflows fail:
1. Ensure the `mock-tpm` dependency is correctly linked in the Rust environment.
2. Verify that the Go version in `.github/workflows` matches the `go.mod` file (v1.21+).
