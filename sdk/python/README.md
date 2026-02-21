- [![Python SDK](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/main/sdk/python)
+ [![Python SDK](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/feature/python-sdk/sdk/python)

🐍 A Python interface to the high-performance MOHAWK federated learning runtime.

## Overview

The Sovereign-Mohawk Python SDK provides a Pythonic wrapper around the Go-based MOHAWK runtime, enabling Python developers to leverage:

- **10M+ node federated learning** with O(d log n) communication complexity
- **zk-SNARK verification** with 10ms proof verification
- **55.5% Byzantine fault tolerance** for adversarial resilience
- **TPM attestation** for secure node identity
- **WebAssembly module loading** for flexible computation

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
pip install -e .
```

### Verifying Installation

```python
import mohawk
print(mohawk.__version__)  # Should print: 0.1.0
```

## Quick Start

### Initialize a Node

```python
from mohawk import MohawkNode

# Create a node instance
node = MohawkNode()

# Start the node with configuration
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
# {'success': True, 'message': 'Proof verified in 10ms'}
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

### Load WebAssembly Modules

```python
# Load a WASM module for custom computation
result = node.load_wasm("wasm-modules/fl_task/target/wasm32-wasi/release/fl_task.wasm")
print(result)
# {'success': True, 'message': 'WASM module loaded'}
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
- **`aggregate(updates)`**: Aggregate federated learning updates
- **`status(node_id)`**: Get node status
- **`load_wasm(module_path)`**: Load a WebAssembly module
- **`attest(node_id)`**: Perform TPM attestation

### Exceptions

- **`MohawkError`**: Base exception for all SDK errors
- **`InitializationError`**: Node initialization failures
- **`VerificationError`**: Proof verification failures
- **`AggregationError`**: Aggregation failures
- **`AttestationError`**: Attestation failures

## Architecture

The Python SDK uses a C-shared library bridge:

```
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

- **Node initialization**: ~50ms
- **zk-SNARK verification**: 10ms (per proof)
- **Aggregation**: O(d log n) complexity
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
