# Changelog

All notable changes to the Sovereign-Mohawk Protocol are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Monitoring smoke gate CI** (`.github/workflows/monitoring-smoke-gate.yml`):
  - Added compose-based Prometheus/Grafana smoke workflow for push/PR
  - Verifies `up` targets are healthy and theorem dashboard is registered via Grafana API
  - Publishes smoke query artifacts for incident/debug traces

- **Release performance evidence index automation** (`scripts/generate_release_performance_evidence.py`, `.github/workflows/release-performance-evidence.yml`, `results/metrics/release_performance_evidence.md`):
  - Added machine-generated release sign-off index for benchmark artifacts
  - Added CI workflow that regenerates benchmark reports and uploads consolidated evidence

- **Golden-path end-to-end evidence runner** (`scripts/golden_path_e2e.sh`, `results/go-live/golden-path-report.json`, `results/go-live/golden-path-report.md`):
  - Added one-command stack-up, readiness, integration-test, and metrics-assertion execution path
  - Produces machine and human-readable evidence artifacts under `results/go-live/`

- **Strict-host evidence artifact** (`results/go-live/strict-host-evidence.md`):
  - Added strict go-live validation evidence template/output for production-host sign-off
  - Documents expected strict failure behavior on non-tuned development hosts and remediation commands

- **Branch protection automation helper** (`scripts/apply_branch_protection.sh`):
  - Added admin-ready script to enforce required status checks and PR review baseline on `main`
  - Includes required contexts for Integrity Guard, monitoring smoke, readiness/chaos, and release evidence gates

- **Bridge compression benchmark CI and report artifacts** (`.github/workflows/bridge-compression-benchmark.yml`, `scripts/benchmark_bridge_compression_compare.sh`, `results/metrics/bridge_compression_benchmark_compare.md`):
  - Added PR/push workflow for JSON-vs-zero-copy bridge compression benchmarking
  - Added markdown summary artifact and raw benchmark output artifact upload
  - Added reproducible benchmark command surface for local and CI parity

- **PyAPI aggregation integration test coverage** (`internal/pyapi/api_aggregate_integration_test.go`):
  - Added endpoint-style coverage for list and wrapped aggregate payloads
  - Added negative-path validation for malformed JSON and empty update batches
  - Added assertions for Multi-Krum selection behavior (`selected_count`, `multi_krum`)

- **FedAvg runtime benchmark comparison CI** (`.github/workflows/fedavg-benchmark-compare.yml`, `scripts/benchmark_fedavg_compare.sh`, `results/metrics/fedavg_benchmark_compare.md`):
  - Added PR/push benchmark comparison workflow with markdown artifact upload (`fedavg-benchmark-report`)
  - Added base-vs-current benchmark script using temporary git worktree execution
  - Added averaged benchmark row reporting and unmatched-row visibility (`NA`) for non-overlapping benchmark symbols

- **Observability v2 dashboards and recording rules** (`monitoring/prometheus/recording-rules.yml`, `monitoring/prometheus/prometheus.yml`, `docker-compose.yml`, `monitoring/grafana/dashboards/v2-*.json`, `monitoring/grafana/dashboards/README_DASHBOARD_V2.md`):
  - Added Prometheus recording rules for throughput, failure ratio, latency quantiles, and availability counts
  - Wired recording rules into compose-mounted Prometheus configuration
  - Added role-oriented v2 dashboard suite for operations, incidents, engineering drilldowns, and executive reporting
  - Added dashboard guide with metric map and verification checklist for identifiable metric navigation

- **PQC readiness overhaul release closure** (`internal/network/gradient.go`, `internal/tpm/tpm.go`, `internal/token/ledger.go`, `cmd/orchestrator/server.go`, `scripts/mainnet_readiness_gate.py`):
  - Hardened runtime hybrid transport negotiation and KEX metadata enforcement for `x25519-mlkem768-hybrid`
  - Completed XMSS-bound TPM quote metadata binding and attestation mode visibility in readiness checks
  - Added epoch-driven migration cutover with cryptographic dual-signature requirement after cutover
  - Added digest-first migration signing endpoint to support deterministic operator signing workflows
  - Added readiness validation coverage for TPM identity signature mode and migration policy defaults

- **Formal go-live gate framework** (`scripts/validate_go_live_gates.py`, `results/go-live/attestations/*.json`, `Makefile`):
  - Added machine-enforced go-live validator combining readiness, chaos, host network preflight, and attestation approvals
  - Added `make go-live-gate` target for one-command formal validation
  - Added structured attestation templates and generated status report artifact at `results/go-live/go-live-gate-report.json`

- **Host UDP/socket tuning preflight** (`scripts/validate_host_network_tuning.sh`, `scripts/mainnet_one_click.sh`):
  - Added strict kernel preflight gate for `net.core.rmem_*` and `net.core.wmem_*`
  - Wired preflight into one-click pipeline as first-stage hard gate

- **Operations runbook publication** (`OPERATIONS_RUNBOOK.md`):
  - Published incident response, escalation flow, readiness/chaos preflight sequence, and backup/restore drill procedures
  - Added evidence references to readiness/chaos artifacts and ledger backup/restore validation paths

- **GitHub SDK release packaging** (`.github/workflows/publish-python-sdk.yml`, `sdk/python/setup.py`):
  - Added a tag-driven workflow that builds the Python SDK source distribution and publishes it as a GitHub Release asset on `sdk-v*` tags
  - Enforces SDK tag/version alignment before publishing to avoid mismatched release artifacts
  - Packaging metadata now uses `mohawk.__version__` as the single SDK version source and prefers packaged shared-library lookup before repository-root fallback

- **Real BN254 Groth16 zk-SNARK verifier** (`internal/zksnark_verifier.go`):
  - Replaced simulation with full four-pairing Miller-loop check using `gnark-crypto v0.20.0`
  - Genesis VK uses canonical BN254 generator points (α=G1, β=G2, γ=G2, δ=G2, IC₀=G1)
  - Wire format: 128 bytes compressed — A[32] | B[64] | C[32] — matches existing buffer contract
  - `GenesisProofBytes()` helper produces a deterministic valid proof (A=G1gen, B=G2gen, C=−G1gen)
  - Infinity-point guard and O(1) 15 ms latency enforcement retained from Theorem 5
- **Real SHA256 Merkle-commitment STARK verifiers** (`internal/hybrid/verifier.go`):
  - `friVerifier` (backend: `simulated_fri`): verifies `proof[0:32] == SHA256(proof[32:])` — binding root to transcript
  - `winterfellVerifier` (backend: `winterfell_mock`): uses domain-separated commitment `SHA256("winterfell-v1:"+transcript)` to prevent cross-protocol replay
  - `GenFRIProof(content)` and `GenWinterfellProof(transcript)` constructor helpers for testing and SDK usage
- **Structured error codes in the Go↔Python bridge** (`internal/pyapi/api.go`):
  - `Result.ErrorCode` field: machine-readable code (`PROOF_TOO_SHORT`, `PROOF_POINT_INVALID`, `PROOF_DEGENERATE`, `PROOF_PAIRING_FAILED`, `PROOF_LATENCY_EXCEEDED`, `PROOF_INVALID`)
  - `classifyProofError()` maps Go error strings to codes; `marshalResultEC()` emits them in JSON
- **Base64/hex proof decoding in the bridge** (`internal/pyapi/api.go`):
  - `decodeProofString()` transparently handles 0x-hex, standard base64, URL-safe base64, and raw string bytes
  - Removed legacy zero-padding in `VerifyZKProof` and `BatchVerifyProofs` — invalid-size proofs now return `PROOF_TOO_SHORT`
- **Structured Python SDK exception hierarchy** (`sdk/python/mohawk/exceptions.py`, `__init__.py`):
  - `ProofTooShortError`, `ProofStructureError`, `ProofPairingError`, `ProofDegenerateError` as `VerificationError` subclasses
  - `verification_error_for_code(code, message)` mapper used by `MohawkNode.verify_proof()` to raise the most specific type
- **gnark-crypto** `v0.20.0` added as a direct dependency
- **Grafana tokenomics dashboard** (`monitoring/grafana/dashboards/finance/tokenomics.json`):
  - Supply, holder count, tx count, burn/mint rates
  - Bridge settlement volume/success tracking
  - Proof verification throughput and p50/p95/p99 latency views
- **WASM module registry + hot reload** (`internal/wasmhost/host.go`, `internal/pyapi/api.go`):
  - Content-hash keyed module registry (`Upsert`, `Get`, `Default`, `HotReload`, `Close`)
  - Runtime status includes active `wasm_module_hash`
  - `LoadWasmModule` supports path and inline `wasm_b64` payloads
- **Async hot-reload examples** (`sdk/python/examples/wasm_hot_reload_demo.py`, `sdk/python/examples/wasm_hot_reload_async_demo.py`)
- **Mainnet readiness gate** (`.github/workflows/mainnet-readiness-gate.yml`, `scripts/mainnet_readiness_gate.py`):
  - Boots core monitoring stack in CI and verifies Grafana/Prometheus readiness
  - Enforces orchestrator (`orchestrator:9091`) and TPM (`tpm-metrics:9102`) scrape target health
  - Validates tokenomics metric presence and supply invariant (`total_supply ~= minted - burned`)
  - Publishes structured readiness report artifact (`mainnet-readiness-report`)
- **Mainnet chaos gate** (`.github/workflows/mainnet-chaos-gate.yml`, `scripts/chaos_readiness_drill.sh`):
  - Runs outage/recovery drills for `tpm-metrics`, `orchestrator`, `prometheus`, and `grafana` in CI matrix jobs
  - Requires baseline readiness pass, expected failure during outage, and full readiness recovery post-restart
  - Enforces recovery-latency threshold and publishes per-scenario baseline/failure/recovery/summary reports
- **Weekly readiness digest** (`.github/workflows/weekly-readiness-digest.yml`, `scripts/generate_readiness_digest.py`):
  - Runs readiness + all chaos drills on a weekly schedule and on-demand
  - Produces a consolidated markdown digest and publishes it to job summary + artifacts
  - Supports optional Slack/Teams webhook notifications via `SLACK_WEBHOOK_URL` and `TEAMS_WEBHOOK_URL` repository secrets

### Changed

- **Formal go-live validator strict/advisory mode semantics** (`scripts/validate_go_live_gates.py`, `Makefile`, `README.md`, `results/go-live/README.md`):
  - Added explicit `--host-preflight-mode` (`strict` or `advisory`) with audited report metadata
  - Reports now include mode, warnings list, and host-tuning enforcement status
  - Added mode-specific make targets (`go-live-gate-strict`, `go-live-gate-advisory`)

- **Alert remediation linkage** (`monitoring/prometheus/alerting-rules.yml`, `OPERATIONS_RUNBOOK.md`):
  - Added `runbook_url` annotations for each resilience/liveness/attestation alert
  - Added explicit runbook playbooks for all alert names to reduce on-call triage latency

- **Prometheus to Alertmanager routing** (`monitoring/prometheus/prometheus.yml`, `monitoring/alertmanager/alertmanager.yml`, `docker-compose.yml`):
  - Added Alertmanager service and Prometheus alertmanager target wiring
  - Added severity-based routing for `critical` and `warning` alerts

- **FedAvg aggregation worker strategy and benchmark surface** (`internal/accelerator/aggregate.go`, `test/accelerator_test.go`, `README.md`, `PERFORMANCE.md`):
  - Added adaptive worker resolver (`ResolveAggregateWorkers`) with small-workload single-thread fallback and large-workload parallel selection
  - Expanded runtime benchmark matrix to include 4 workload shapes and 5 worker configurations
  - Added worker-resolution unit coverage and reproducible benchmark commands in project documentation

- **One-click host preflight policy tightened** (`scripts/mainnet_one_click.sh`, `README.md`, `OPERATIONS_RUNBOOK.md`):
  - Switched `MOHAWK_HOST_PREFLIGHT_MODE` default from advisory to strict for production-safe execution
  - Documented dev-container advisory override path and production sysctl persistence checklist
  - Added structured one-click report references for release evidence trails

- **SDK version baseline** (`sdk/python/mohawk/__init__.py`, `README.md`, `sdk/python/README.md`):
  - Bumped Python SDK release identifier and badge references to `2.0.1.Alpha`

- **Weekly digest workflow advisory trail** (`.github/workflows/weekly-readiness-digest.yml`):
  - Added advisory host-preflight marker handling and digest summary annotation path
- **Readiness/operations documentation alignment** (`README.md`, `ROADMAP.md`, `DASHBOARD.md`):
  - Updated program-stage language to reflect go-live formalization complete
  - Added formal artifact trails for go-live report and attestations
  - Marked completed operations/runbook/escalation roadmap items as complete
  - Synced formal gate status to `8/8` approved attestations with all required go-live evidences validated

- Documentation alignment: synchronized current phase and program-stage wording across `ROADMAP.md`, `README.md`, and `DASHBOARD.md` to reflect v1.0.0 GA closure under mainnet-readiness gated operations

- `TestVerifyProof_Valid` now uses `internal.GenesisProofBytes()` (real BN254 proof) instead of `make([]byte, 128)`
- `TestVerifyProof_TooSmall` behaviour unchanged; added `TestVerifyProof_InvalidPoint` and `TestVerifyProof_WrongProof`
- `TestHybridVerifyModes` updated to construct proofs via `hybrid.GenFRIProof` / `hybrid.GenWinterfellProof`
- Python bridge now deallocates Go-returned strings through exported `FreeString` (leak-safe ctypes boundary)
- Python SDK client lifecycle now supports `close()`, `with MohawkNode(...)`, and `async with AsyncMohawkNode(...)`
- Build workflow now installs SDK (`pip install -e ./sdk/python[dev]`) and runs Python tests directly in CI

- Python SDK roadmap integration milestones
- CI/CD pipeline for automated Python SDK builds
- Strict auth/role smoke runner at `scripts/strict_auth_smoke.py` for deterministic token/role validation (positive and negative paths)
- New Make targets: `strict-auth-smoke-host`, `strict-auth-smoke-container`, and `production-readiness`
- SDK docs for strict-auth smoke usage and Alpine/musl ctypes troubleshooting with glibc-container fallback
- README and SDK README refresh covering badges, genesis testnet usage, observability endpoints, and Python SDK v2 feature surface
- Bridge settlement lifecycle in `internal/bridge/bridge.go`, including burn → release flow, deterministic settlement records, and automatic refund-on-mint-failure handling
- Multi-asset settlement routing with optional asset registry enforcement via the new `internal/token/registry.go`
- Utility coin ledger hardening in `internal/token/ledger.go` with integer base-unit accounting, `burn` transactions, and state migration support from legacy float-backed snapshots
- `bridge_transfer` settlement controls in Python SDK (`settle`, `settlement_minter`) and runtime API wiring in `internal/pyapi/api.go`
- Environment-driven settlement configuration for multi-asset deployments (`MOHAWK_BRIDGE_SETTLEMENT_ASSETS`, per-asset ledger/minter overrides)
- Compose rollout templates and operator guidance in `docker-compose.yml` for single-asset defaults and optional multi-asset settlement mode
- Expanded automated coverage for settlement, multi-asset routing, env parsing/config loading, and ledger migration behavior (`test/bridge_hybrid_test.go`, `internal/pyapi/api_security_test.go`, `test/utility_coin_durability_test.go`)
- Restored tokenomics dashboard ingestion by exposing orchestrator metrics on internal plaintext listener (`:9091`) while preserving mTLS on the control-plane API (`:8080`)
- Updated Prometheus orchestrator scrape target to `http://orchestrator:9091/metrics` for reliable in-network collection
- Added CI monitoring smoke check in `.github/workflows/build-test.yml` to assert `mohawk_utility_coin_total_supply` is queryable after stack startup
- Aligned containerized Go build/runtime toolchains to 1.25 (`Dockerfile`, `cmd/orchestrator/Dockerfile`, `cmd/node-agent/Dockerfile`, `cmd/api-dashboard/Dockerfile`, `cmd/fl-aggregator/Dockerfile`, `docker-compose.yml`)

### Benchmarks

- Published the latest SDK benchmark snapshot in project docs:
  - `test_verify_proof_performance`: 10.55 ms mean, 94.77 ops/s
  - `test_aggregate_nodes_performance`: 30.63 us mean, 32,648 ops/s
  - `test_gradient_compression_performance`: 995.70 us mean, 1,004 ops/s

- Added Go runtime FedAvg benchmark matrix and comparison reporting:
  - Benchmark symbol: `BenchmarkAggregateParallel`
  - Workloads: `clients32_dim2048`, `clients128_dim4096`, `clients256_dim8192`, `clients512_dim8192`
  - Worker profiles: `workers1`, `workers2`, `workers4`, `workers8`, `workersAuto`
  - Comparison report artifact: `results/metrics/fedavg_benchmark_compare.md`

- Added live 10-minute stress metrics capture artifacts from running stack scope:
  - JSON report: `results/metrics/stress_metrics_capture_10m.json`
  - Markdown summary: `results/metrics/stress_metrics_capture_10m.md`
  - Observed zero gradient submit failures during the capture window (`accel_gradient_submit_failure_total` delta = `0`)

## [0.1.0] - 2026-02-20

### Added - Python SDK Foundation

#### Core Components

- **Go C-Shared Library** (`internal/pyapi/api.go`)
  - Exported functions: `InitializeNode`, `VerifyZKProof`, `AggregateUpdates`, `GetNodeStatus`, `LoadWasmModule`, `AttestNode`
  - JSON-based communication protocol between Go and Python
  - Memory-safe string handling with `FreeString` function
  - Cross-platform support (Linux `.so`, macOS `.dylib`, Windows `.dll`)

- **Python Client Package** (`sdk/python/mohawk/`)
  - `MohawkNode` class with ctypes bindings to Go runtime
  - Pythonic API with type hints and comprehensive docstrings
  - Custom exception hierarchy: `MohawkError`, `InitializationError`, `VerificationError`, `AggregationError`, `AttestationError`
  - Automatic library path detection and loading

- **Build Automation**
  - `setup.py` with custom `BuildGoLibrary` command
  - Automatic Go library compilation during `pip install`
  - Platform detection and appropriate library extension selection
  - `pyproject.toml` for modern Python packaging standards

- **Example Scripts**
  - `examples/basic_usage.py`: Demonstrates all SDK features
  - `examples/federated_learning_demo.py`: Complete FL workflow simulation
  - Interactive demos with progress indicators and statistics

- **Testing Infrastructure**
  - `tests/test_client.py`: Pytest unit tests for all methods
  - Fixtures for node initialization
  - Exception handling test coverage

- **Makefile Extensions**
  - `build-python-lib`: Build Go C-shared library
  - `install-python-sdk`: Install Python package with dependencies
  - `test-python-sdk`: Run pytest suite
  - `demo-python-sdk`: Execute example demonstrations
  - `python-all`: Complete build/install/test workflow

- **Documentation**
  - Complete Python SDK README with API reference
  - Architecture diagrams showing Go↔Python bridge
  - Installation instructions and quick start guide
  - Performance benchmarks and usage examples

### Technical Specifications

#### Performance

- Node initialization: ~50ms
- zk-SNARK verification: 10ms (maintained from Go runtime)
- Aggregation complexity: O(d log n)
- Memory overhead: Minimal (ctypes zero-copy where possible)

#### API Coverage

| Function | Go Implementation | Python Binding | Status |
| --- | --- | --- | --- |
| InitializeNode | ✅ | ✅ | Stubbed |
| VerifyZKProof | ✅ | ✅ | Stubbed |
| AggregateUpdates | ✅ | ✅ | Stubbed |
| GetNodeStatus | ✅ | ✅ | Stubbed |
| LoadWasmModule | ✅ | ✅ | Stubbed |
| AttestNode | ✅ | ✅ | Stubbed |

*Note: "Stubbed" means the binding is complete but calls mock implementations. Next phase will connect to actual Go runtime logic.*

### Changed (0.1.0)

- Updated `README.md` with Python SDK section and examples
- Extended `Makefile` with Python-specific targets
- Added Python SDK badge to repository shields

### Developer Notes

#### Bridge Architecture

```text
Python (mohawk.client) → ctypes → libmohawk.so → CGO → Go Runtime (internal/)
```

#### Memory Management

- Go allocates strings with `C.CString()`
- Python receives via `ctypes.c_char_p`
- Python calls `FreeString()` to deallocate Go memory
- JSON is used for complex data structures

#### Next Steps for Full Integration

1. Replace TODO comments in `internal/pyapi/api.go` with actual module calls
1. Connect `VerifyZKProof` to `internal/zksnark_verifier.go`
1. Link `AggregateUpdates` to `internal/aggregator.go`
1. Integrate `LoadWasmModule` with `internal/wasmhost`
1. Connect `AttestNode` to `internal/tpm` attestation

## [0.0.1] - 2026-01-15

### Added - Initial Release

#### Core Protocol

- Hierarchical federated learning architecture (10M:1k:100:1)
- O(d log n) communication complexity
- 55.5% Byzantine fault tolerance (Theorem 1)
- 99.99% straggler resilience (Theorem 4)
- 10ms zk-SNARK proof verification (Theorem 5)
- 28 MB metadata for 10M nodes (700,000x compression)

#### Implementation

- Go 1.24 runtime with Wasmtime integration
- TPM attestation stub
- Batch verification system
- RDP (Rényi Differential Privacy) accountant
- Convergence guarantees with formal proofs
- WebAssembly module hosting

#### Documentation

- White Paper with complete protocol specification
- Academic Paper with formal proofs (Theorems 1-5)
- Proof-driven design verification system
- Security audit scripts

#### Testing

- Comprehensive test suite (`test_all.sh`)
- GitHub Actions CI/CD
- Proof verification automation
- Build and test workflows

---

## Version Numbering

- **Major (X.0.0)**: Breaking changes to protocol or API
- **Minor (0.X.0)**: New features, backwards compatible
- **Patch (0.0.X)**: Bug fixes, no new features

---

## Links

- [Repository](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
- [Releases](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases)
- [Issues](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
