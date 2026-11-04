# Python SDK Guide — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.
**Canonical reference**: `sdk/python/README.md` (installation, full API).

## 1. Overview

The Python SDK wraps the Go runtime via a C-shared library (CGo). It exposes
federated learning, ZK verification, Byzantine safety checks, TPM attestation,
and the utility coin ledger to Python callers.

- Python 3.8+.
- Requires a built Go shared library (`make build-python-lib`).
- Async support via `AsyncMohawkNode`.

## 2. Install

```bash
git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
cd Sovereign-Mohawk-Proto
make build-python-lib
cd sdk/python
pip install -e .[dev]
```

## 3. Quick examples

### 3.1 Context-managed node

```python
from mohawk import MohawkNode

with MohawkNode(config_path="node.json") as node:
    status = node.status()
    print(status)
```

### 3.2 Async lifecycle

```python
import asyncio
from mohawk import AsyncMohawkNode

async def main():
    async with AsyncMohawkNode(config_path="node.json") as node:
        await node.start_round()

asyncio.run(main())
```

### 3.3 Hybrid proof check

```python
from mohawk import HybridProofCheck

result = HybridProofCheck.verify(proof_bytes, commitment_hex)
print(result.accepted, result.backend)
```

## 4. Where to find more

- Full API surface and options: `sdk/python/README.md`.
- Go package details: `docs/api/API_REFERENCE.md`.
- gRPC federation service: `docs/api/GRPC_FEDERATION.md`.
- Getting started (Docker/K8s): `docs/guides/GETTING_STARTED.md`.

## 5. Open items

- `make docs-api` target to regenerate the gRPC reference from the proto
  (currently hand-maintained).
