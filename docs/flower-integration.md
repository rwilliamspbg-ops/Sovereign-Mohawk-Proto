# Flower-Compatible Client Integration

## Goal

Add Flower-compatible client-side training workflows to the Python SDK without moving orchestration authority away from the Go runtime.

The intended architecture is:

- Flower provides the familiar client-side `fit()` / `evaluate()` lifecycle and example training loops.
- The Mohawk Python SDK owns local model handling, gradient compression, proof-envelope generation, and aggregation submission.
- The Go node agent remains the authoritative layer for aggregation, hierarchy, and verification.

This implementation is intentionally scoped: one adapter, one runnable smoke example, and tests that prove the integration remains usable without requiring Flower at import time.

## Implemented Pieces

The repository now includes:

- `sdk/python/mohawk/flower_client.py` with `MohawkFlowerClient`
- `sdk/python/examples/flower_mohawk_demo.py` as a smoke-testable end-to-end example
- `sdk/python/tests/test_flower_client.py` covering fallback behavior, Flower-style inheritance, and round submission
- `sdk/python/pyproject.toml` optional `flower` extra
- `.github/workflows/flower-integration.yml` for CI smoke coverage

`wasm-modules/flower_task` remains available as a future execution target, but the client-side integration no longer depends on it.

## Runtime Shape

1. The Flower adapter accepts local training and evaluation callables.
2. The adapter flattens updated model parameters for Mohawk compression and aggregation.
3. The adapter emits a deterministic proof manifest that can be extended to a real ZK proof hook later.
4. The adapter keeps the base SDK usable when Flower is not installed.

## Packaging

Suggested install extras:

- `flower`
- `torch` or framework-specific extras as needed for examples

Use the optional Flower extra when you want to plug the adapter into Flower simulators or examples:

```bash
cd sdk/python
pip install -e .[flower]
```

## Adapter

Add a small adapter layer in the Python SDK that bridges Flower client callbacks to Mohawk operations.

Recommended shape:

- `MohawkFlowerClient` accepts a `MohawkNode` plus `train_fn` and `evaluate_fn` callables.
- The wrapper keeps the local model logic outside the SDK so Flower examples can reuse their own training loops.
- The wrapper compresses updated parameters through Mohawk, emits a proof manifest, and submits the gradient update to the Go-backed aggregator.
- The wrapper works even when Flower is absent by using a local fallback base class with the same method shape.

Important design rule:

- Flower should not become the source of truth for verification or aggregation policy.
- The wrapper should call Mohawk hooks after local training and before remote submission.

## Example

`sdk/python/examples/flower_mohawk_demo.py` is the first runnable demo.

It demonstrates:

- local training callback execution
- Mohawk compression and aggregation submission
- proof-manifest generation
- evaluation callback execution

Run it with:

```bash
python sdk/python/examples/flower_mohawk_demo.py --ci
```

## CI And Tests

Current validation includes:

- `pytest sdk/python/tests/test_flower_client.py`
- `pytest sdk/python/tests/test_client.py tests/test_flower_client.py`
- the smoke example in CI mode
- the new Flower integration workflow on `push` and `pull_request`

## Optional Strategy Bridge

Keep Flower server strategies optional and non-blocking.

Recommended approach:

- Default path: keep aggregation in Go and only adapt the client side.
- Optional path: add a small Python bridge that forwards aggregates to the Go orchestrator over the existing SDK boundary.
- Only port a Flower strategy to Go if a real usage case requires it.

This keeps the architecture aligned with the repository's current strength: Go-owned verification and aggregation.

## Out Of Scope

- claiming zero-code-change integration for all Flower examples
- moving aggregation authority out of the Go runtime
- adding every Flower framework at once
- asserting WASM attestation is automatically available for all client code paths
- replacing the Go verifier with a Python proof generator

## Next Increment

If this integration is expanded further, the next sensible step is a typed NumPy round-trip helper plus one real Flower example port, such as a quickstart PyTorch client.