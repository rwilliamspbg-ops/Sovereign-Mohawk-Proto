# MOHAWK Python SDK

[![Python SDK](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/main/sdk/python)

🐍 A Python interface to the high-performance MOHAWK federated learning runtime.

[![Build Status](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/build-test.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/build-test.yml)
[![Integrity Guard - Linter](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml)
[![Performance Gate](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml)

![SDK Version](https://img.shields.io/badge/SDK-2.0.1.Alpha-blue?logo=python)
![Python Support](https://img.shields.io/badge/Python-3.8%2B-blue?logo=python)
![Proof Verify Mean](https://img.shields.io/badge/Proof%20Verify-10.55ms-success)
![Compression Mean](https://img.shields.io/badge/Compression-0.996ms-informational)
![Async Client](https://img.shields.io/badge/SDK-Async%20Supported-6f42c1)
![WASM Hot Reload](https://img.shields.io/badge/WASM-Hot%20Reload-blueviolet)

## Overview

The Sovereign-Mohawk Python SDK provides a Pythonic wrapper around the Go-based MOHAWK runtime, enabling Python developers to leverage:

- **10M+ node federated learning** with O(d log n) communication complexity
- **zk-SNARK verification** with 10ms proof verification
- **hybrid SNARK/STARK policy checks** with backend selection
- **55.5% Byzantine fault tolerance** for adversarial resilience
- **TPM attestation** for secure node identity
- **utility coin ledger controls** with backup/restore, nonce replay protection, and auth hooks
- **bridge route policy verification** with typed EVM/Cosmos proof helpers
- **hardware-aware gradient compression** and streaming aggregation
- **WebAssembly module loading** for flexible computation

The SDK now includes:

- automatic Go string deallocation via exported `FreeString` (prevents bridge-response leaks)
- context-managed lifecycle (`with MohawkNode(...) as node:`)
- async context-managed lifecycle (`async with AsyncMohawkNode(...) as node:`)
- high-level wrapper models for bridge and hybrid proof flows (`BridgeTransferIntent`, `HybridProofCheck`)

## Installation

### Prerequisites

- Python 3.8+
- Go 1.24+ (for building the C-shared library)
- GCC or compatible C compiler

### From Source

```bash
# Clone the repository
git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
cd Sovereign-Mohawk-Proto

# Build the Go shared library
make build-python-lib

# Install the Python package
cd sdk/python
pip install -e .[dev]

# Optional extras
pip install -e .[accelerator]
```

### Verifying Installation

```python
import mohawk
print(mohawk.__version__)  # Should print: 2.0.1.Alpha
```

## GitHub Release Publishing

GitHub does not provide a native Python package registry for this SDK, so the GitHub-native publish path is a tagged GitHub Release carrying the source distribution artifact.

To publish a new SDK package on GitHub:

```bash
cd sdk/python
python -m pip install --upgrade build twine
python -m build --sdist
python -m twine check dist/*

git tag sdk-v2.0.1.Alpha
git push origin sdk-v2.0.1.Alpha
```

Pushing an `sdk-v*` tag triggers `.github/workflows/publish-python-sdk.yml`, which validates that the tag matches `mohawk.__version__`, builds the source package, and uploads it to a GitHub Release.

## Quick Start

### Initialize a Node

```python
from mohawk import MohawkNode

with MohawkNode() as node:
    result = node.start(
        config_path="capabilities.json",
        node_id="node-001"
    )
    print(result)
    # {'success': True, 'message': 'Node started successfully'}
```

### Verify zk-SNARK Proofs

```python
# Verify a zero-knowledge proof
proof_data = {
    "proof": "0x1234...",
    "public_inputs": ["input1", "input2"]
}

verification = node.verify_proof(proof_data)
print(verification)
# {'success': True, 'message': 'Proof verified'}
```

### Aggregate Federated Learning Updates

```python
# Aggregate model updates from multiple nodes
updates = [
    {"node_id": "node-001", "gradient": [0.1, 0.2, 0.3]},
    {"node_id": "node-002", "gradient": [0.15, 0.25, 0.35]},
]

result = node.aggregate(updates)
print(result)
# {'success': True, 'message': 'Updates aggregated successfully'}
```

### Gradient Compression and Device Discovery

```python
devices = node.device_info()
print(devices)

compressed = node.compress_gradients([0.1, 0.2, 0.3], format="fp16")
print(compressed)

stream = node.stream_aggregate(
    [[0.1, 0.2, 0.3], [0.11, 0.21, 0.31]],
    format="int8",
    max_norm=1.0,
)
print(stream)
```

### Hybrid Proof Verification

```python
hybrid = node.verify_hybrid_proof(
    snark_proof="s" * 128,
    stark_proof="t" * 64,
    mode="both",
)
print(hybrid)

print(node.hybrid_backends())
```

### Pythonic High-Level Wrappers

```python
from mohawk import MohawkNode, BridgeTransferIntent, HybridProofCheck

with MohawkNode() as node:
    transfer = BridgeTransferIntent(
        source_chain="ethereum",
        target_chain="polygon",
        asset="USDC",
        amount=5.0,
        sender="0xabc",
        receiver="0xdef",
        nonce=10,
        proof={"proof": "typed-proof"},
        finality_depth=12,
    )
    bridge_receipt = node.transfer_asset(transfer)

    hybrid_receipt = node.verify_hybrid(
        HybridProofCheck(
            snark_proof="s" * 128,
            stark_proof="t" * 64,
            mode="both",
        )
    )

print(bridge_receipt.success, hybrid_receipt.success)
```

### Bridge and Utility Coin Operations

```python
receipt = node.bridge_transfer(
    source_chain="ethereum",
    target_chain="polygon",
    asset="USDC",
    amount=12.5,
    sender="0xabc",
    receiver="0xdef",
    nonce=1,
    proof="proof-bytes",
)
print(receipt)

settled = node.bridge_transfer(
    source_chain="ethereum",
    target_chain="polygon",
    asset="MHC",
    amount=2.0,
    sender="0xabc",
    receiver="0xdef",
    nonce=2,
    proof="proof-bytes",
    settle=True,
)
print(settled)

minted = node.mint_utility_coin(
    to="edge-alice",
    amount=100.0,
    actor="protocol",
    idempotency_key="mint-001",
    nonce=1,
)
print(minted)

payment = node.transfer_utility_coin(
    from_account="edge-alice",
    to_account="edge-bob",
    amount=25.0,
    idempotency_key="tx-001",
    nonce=2,
)
print(payment)

print(node.utility_coin_balance("edge-bob"))
print(node.utility_coin_ledger())
```

### Load WebAssembly Modules

```python
# 1) Load by filesystem path
result = node.load_wasm("wasm-modules/fl_task/target/wasm32-wasi/release/fl_task.wasm")
print(result["module_hash"])

# 2) Hot-reload inline bytes
with open("wasm-modules/fl_task/target/wasm32-wasi/release/fl_task.wasm", "rb") as f:
    wasm_bytes = f.read()

# Sign sha256(wasm_bytes) with your approved signing workflow and pass
# module_sha256 + module_signature + module_public_key.
hot = node.load_wasm(
    wasm_bytes=wasm_bytes,
    module_sha256="<sha256-hex>",
    module_signature="<base64-or-hex-signature-over-sha256-bytes>",
    module_public_key="<base64-or-hex-ed25519-public-key>",
)

# 3) Hot-reload pre-encoded base64 payload
import base64
wasm_b64 = base64.b64encode(b"\x00asm\x01\x00\x00\x00").decode("ascii")
hot2 = node.load_wasm(
    wasm_b64=wasm_b64,
    module_sha256="<sha256-hex>",
    module_signature="<base64-or-hex-signature-over-sha256-bytes>",
    module_public_key="<base64-or-hex-ed25519-public-key>",
)

print(hot["module_hash"], hot2["module_hash"])
# {'success': True, 'message': 'WASM module loaded', 'module_hash': '...'}
```

Runnable demo:

```bash
python sdk/python/examples/wasm_hot_reload_demo.py
```

Notebook tutorial (full FL cycle through hybrid verification):

```bash
jupyter notebook sdk/python/examples/federated_learning_hybrid_verification_tutorial.ipynb
```

Async variant:

```bash
python sdk/python/examples/wasm_hot_reload_async_demo.py
```

PQC migration digest-flow demo:

```bash
python sdk/python/examples/pqc_migration_demo.py
```

### TPM Attestation

```python
# Perform hardware-backed attestation
attestation = node.attest("node-001")
print(attestation)
# {'success': True, 'message': 'Attestation successful'}
```

## API Reference

### `MohawkNode`

Main class for interacting with the MOHAWK runtime.

#### Methods

- **`start(config_path, node_id, capabilities=None)`**: Initialize a node
- **`verify_proof(proof)`**: Verify a zk-SNARK proof
- **`batch_verify(proofs)`**: Verify many proofs in parallel
- **`verify_hybrid_proof(...)`**: Evaluate hybrid SNARK/STARK policies
- **`verify_hybrid(check, **overrides)`**: High-level hybrid verification wrapper returning `HybridVerificationReceipt`
- **`hybrid_backends()`**: List available STARK backends
- **`aggregate(updates)`**: Aggregate federated learning updates
- **`aggregate_buffer(gradient_buffer)`**: Inspect zero-copy aggregation buffer path
- **`status(node_id)`**: Get node status
- **`load_wasm(module_path=None, wasm_bytes=None, wasm_b64=None, module_sha256=None, module_signature=None, module_public_key=None)`**: Load or hot-reload a WebAssembly module and return `module_hash` (inline hot-reload requires hash+signature+public key)
- **`attest(node_id)`**: Perform TPM attestation
- **`close()`**: Release SDK bridge references; also available through `with MohawkNode(...) as node:`
- **`device_info()`**: Enumerate available CPU/GPU/NPU backends
- **`compress_gradients(gradients, format='fp16'|'int8')`**: Quantize gradients for transport
- **`stream_aggregate(gradient_stream, format='fp16'|'int8')`**: Buffer + compress gradient stream
- **`bridge_transfer(..., settle=False, settlement_minter=None, auth_token=None, role=None)`**: Cross-chain transfer verification with optional settlement execution
- **`transfer_asset(intent, **overrides)`**: High-level bridge wrapper returning `BridgeTransferReceipt`
- **`mint_utility_coin(to, amount, actor='protocol', auth_token=None, idempotency_key=None, nonce=None, role=None)`**: Mint utility coin balances with optional API auth + replay controls
- **`transfer_utility_coin(from_account, to_account, amount, auth_token=None, idempotency_key=None, nonce=None, role=None)`**: Transfer utility coin with optional API auth + replay controls
- **`burn_utility_coin(from_account, amount, auth_token=None, idempotency_key=None, nonce=None, role=None)`**: Burn utility coin balances with optional API auth + replay controls
- **`utility_coin_balance(account)`**: Retrieve utility coin balance
- **`utility_coin_ledger()`**: Retrieve utility coin ledger snapshot
- **`backup_utility_coin_ledger(path, auth_token=None, role=None)`**: Write current utility coin state snapshot to backup file
- **`restore_utility_coin_ledger(path, auth_token=None, role=None)`**: Restore utility coin state from backup file

Async lifecycle support:

- Use `async with AsyncMohawkNode(...) as node:` for automatic cleanup.

Example:

```python
from mohawk import AsyncMohawkNode

async def run():
    async with AsyncMohawkNode() as node:
        return await node.status("node-001")
```

Bridge policy fallback:

- If no `route_policy`, `policy_manifest`, or `policy_manifest_path` is supplied to `bridge_transfer`, the runtime automatically attempts to load a default manifest from `bridge-policies.json`.
- Override the default path with environment variable `MOHAWK_BRIDGE_POLICY_MANIFEST`.

Bridge settlement runtime controls:

- Set `settle=True` on `bridge_transfer(...)` to execute settlement after receipt verification.
- Set `MOHAWK_BRIDGE_SETTLEMENT_ASSETS` (for example `MHC,USDX`) to enforce a settlement asset registry.
- Use `MOHAWK_LEDGER_STATE_PATH_<SYMBOL>` and `MOHAWK_LEDGER_AUDIT_PATH_<SYMBOL>` for per-asset persistent ledgers.
- Use `MOHAWK_UTILITY_MINTER_<SYMBOL>` for per-asset settlement mint actors.

Utility coin hardening runtime controls:

- Set `MOHAWK_LEDGER_STATE_PATH` and `MOHAWK_LEDGER_AUDIT_PATH` to enable persistent ledger state + append-only audit trail.
- Set `MOHAWK_API_TOKEN` (or `MOHAWK_API_TOKEN_FILE`) to require API token authorization on mint/transfer requests.
- Set `MOHAWK_API_AUTH_MODE` to `optional` (default), `required`, or `file-only` for global API token behavior.
- Set `MOHAWK_UTILITY_RATE_LIMIT_PER_MIN` to cap utility coin endpoint operations per principal per minute.
- Set `MOHAWK_UTILITY_ENFORCE_ROLES=true` to require role authorization for mint/burn/transfer/backup/restore.
- Configure allowed roles with `MOHAWK_UTILITY_MINT_ALLOWED_ROLES`, `MOHAWK_UTILITY_BURN_ALLOWED_ROLES`, `MOHAWK_UTILITY_TRANSFER_ALLOWED_ROLES`, `MOHAWK_UTILITY_BACKUP_ALLOWED_ROLES`, and `MOHAWK_UTILITY_RESTORE_ALLOWED_ROLES`.
- Optionally bind the configured API token to a fixed role with `MOHAWK_API_TOKEN_ROLE`.
- Set `MOHAWK_API_ENFORCE_ROLES=true` and configure `MOHAWK_API_BRIDGE_ALLOWED_ROLES` / `MOHAWK_API_HYBRID_ALLOWED_ROLES` for non-utility endpoint role gates.

### Strict Auth Smoke Validation

Use reproducible smoke targets to validate positive and negative auth/role behavior:

```bash
# Host execution
make strict-auth-smoke-host

# Container execution (recommended for deployment parity)
make strict-auth-smoke-container
```

### Container Troubleshooting (Alpine + ctypes)

If `ctypes.CDLL("libmohawk.so")` fails in an Alpine/musl runtime with a TLS relocation error (for example `initial-exec TLS resolves to dynamic definition`), run strict smoke validation from a glibc-based container path instead (`make strict-auth-smoke-container`).

### Accelerator APIs

```python
from mohawk import MohawkNode, GradientBuffer

node = MohawkNode()
print(node.device_info())

profile = node.auto_tune_profile(vector_length=4096)
print(profile)

compressed = node.compress_gradients([0.1, 0.2, 0.3], format="auto")
print(compressed)

batch = node.batch_verify([
    {"id": "p1", "proof": "abc"},
    {"id": "p2", "proof": "xyz"},
])
print(batch)

stream = node.stream_aggregate(
    [[0.1, 0.2, 0.3], [0.11, 0.21, 0.31]],
    format="int8",
    max_norm=1.0,
)
print(stream)

# Hybrid SNARK/STARK verification
hybrid = node.verify_hybrid_proof(
    snark_proof="s" * 128,
    stark_proof="t" * 64,
    mode="both",  # one of: both | any | prefer_snark
)
print(hybrid)

# Cross-chain transfer verification
bridge = node.bridge_transfer(
    source_chain="ethereum",
    target_chain="polygon",
    asset="USDC",
    amount=12.5,
    sender="0xabc",
    receiver="0xdef",
    nonce=1,
    proof="proof-bytes",
)
print(bridge)

# Utility coin mint/transfer/balance workflow
minted = node.mint_utility_coin(
    to="edge-alice",
    amount=100.0,
    actor="protocol",
    auth_token="my-service-token",
    idempotency_key="mint-001",
    nonce=1,
)
print(minted)

payment = node.transfer_utility_coin(
    from_account="edge-alice",
    to_account="edge-bob",
    amount=25.0,
    auth_token="my-service-token",
    idempotency_key="tx-001",
    nonce=2,
)
print(payment)

print(node.utility_coin_balance("edge-bob"))
print(node.utility_coin_ledger())

# Optional backup/restore operations
node.backup_utility_coin_ledger("/tmp/mohawk_ledger_backup.json")
node.restore_utility_coin_ledger("/tmp/mohawk_ledger_backup.json")
```

Auto-tuner environment controls:

- `MOHAWK_ACCELERATOR_BACKEND=auto|cpu|cuda|metal|npu`
- `MOHAWK_GRADIENT_FORMAT=fp16|int8`
- `MOHAWK_ACCELERATOR_WORKERS=<positive integer>`
- `MOHAWK_NPU_AVAILABLE=true` (force-enable generic NPU detection in containerized environments)

### Exceptions

- **`MohawkError`**: Base exception for all SDK errors
- **`InitializationError`**: Node initialization failures
- **`VerificationError`**: Proof verification failures
- **`AggregationError`**: Aggregation failures
- **`AttestationError`**: Attestation failures

## Architecture

The Python SDK uses a C-shared library bridge:

```text
┌─────────────────┐
│  Python Code    │
│  (mohawk/)      │
└────────┬────────┘
         │ ctypes
         ▼
┌─────────────────┐
│  libmohawk.so   │
│  (C-shared)     │
└────────┬────────┘
         │ cgo
         ▼
┌─────────────────┐
│  Go Runtime     │
│  (internal/)    │
└─────────────────┘
```

This design maintains the high-performance Go runtime while providing a clean Python interface.

## Development

### Running Tests

```bash
pytest tests/
```

### Code Formatting

```bash
black mohawk/
ruff check mohawk/
```

### Type Checking

```bash
mypy mohawk/
```

## Performance

Benchmark snapshot from `python -m pytest tests/test_benchmarks.py --benchmark-only -q` on March 14, 2026:

| Benchmark | Mean | Median | Throughput |
| --- | ---: | ---: | ---: |
| `test_verify_proof_performance` | 10.55 ms | 10.55 ms | 94.77 ops/s |
| `test_aggregate_nodes_performance` | 30.63 us | 25.20 us | 32,648 ops/s |
| `test_gradient_compression_performance` | 995.70 us | 944.57 us | 1,004 ops/s |

- **Node initialization**: ~50ms
- **zk-SNARK verification**: 10.55ms mean in the benchmark suite
- **Aggregation**: O(d log n) complexity with 30.63us mean benchmark latency
- **Gradient compression**: 995.70us mean for FP16 path in the benchmark suite
- **Memory overhead**: 28 MB for 10M nodes

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development guidelines.

## License

Apache License 2.0 - See [LICENSE.md](../../LICENSE.md)

## Links

- [Main Repository](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
- [White Paper](../../WHITE_PAPER.md)
- [Academic Paper](../../ACADEMIC_PAPER.md)
- [API Documentation](https://rwilliamspbg-ops.github.io/Sovereign-Mohawk-Proto/)
