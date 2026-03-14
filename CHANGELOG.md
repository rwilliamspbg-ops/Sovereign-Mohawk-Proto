# Changelog

All notable changes to the Sovereign-Mohawk Protocol are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

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
