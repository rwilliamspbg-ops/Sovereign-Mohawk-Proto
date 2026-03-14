# Changelog

All notable changes to the Sovereign-Mohawk Protocol are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
- **Grafana tokenomics dashboard** (`monitoring/grafana/dashboards/tokenomics.json`):
  - Supply, holder count, tx count, burn/mint rates
  - Bridge settlement volume/success tracking
  - Proof verification throughput and p50/p95/p99 latency views
- **WASM module registry + hot reload** (`internal/wasmhost/host.go`, `internal/pyapi/api.go`):
  - Content-hash keyed module registry (`Upsert`, `Get`, `Default`, `HotReload`, `Close`)
  - Runtime status includes active `wasm_module_hash`
  - `LoadWasmModule` supports path and inline `wasm_b64` payloads
- **Async hot-reload examples** (`sdk/python/examples/wasm_hot_reload_demo.py`, `sdk/python/examples/wasm_hot_reload_async_demo.py`)

### Changed

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
