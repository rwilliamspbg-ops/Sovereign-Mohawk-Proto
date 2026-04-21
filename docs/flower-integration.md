# Flower-Compatible Client Integration Plan

## Goal

Add Flower-compatible client-side training workflows to the Python SDK without moving orchestration authority away from the Go runtime.

The intended architecture is:

- Flower provides the familiar client-side `fit()` / `evaluate()` lifecycle and example training loops.
- The Mohawk Python SDK owns local model handling, gradient compression, privacy accounting, and proof submission.
- The Go node agent remains the authoritative layer for aggregation, hierarchy, and verification.

This is a compatibility plan, not a promise that Flower examples run unchanged in production.

## Scope Corrections

The original draft assumed a few things that are not present in the repo yet:

- There is no existing Flower dependency in `sdk/python`.
- There is no `MohawkFlowerClient` wrapper today.
- `wasm-modules/flower_task` is a useful runtime integration point, but it is not a drop-in executor for every Flower example.

The first implementation should therefore focus on a thin adapter and a small number of example ports, then expand after the interface is stable.

## Phase 1: Environment And Packaging

1. Add Flower as an optional Python dependency in `sdk/python/pyproject.toml`.
2. Keep the base install light; make Flower and ML frameworks opt-in extras.
3. Document the expected dev setup in `sdk/python/README.md`.
4. Verify the Python SDK can still be installed with `pip install -e .[dev]` without Flower.

Suggested extras:

- `flower`
- `torch` or framework-specific extras as needed for examples

## Phase 2: Client Adapter

Add a small adapter layer in the Python SDK that bridges Flower client callbacks to Mohawk operations.

Recommended shape:

- Create a new `MohawkFlowerClient` wrapper in `sdk/python/mohawk/`.
- Have it accept a `MohawkNode` or similar SDK client object.
- Keep model training logic outside the wrapper so example code can supply PyTorch, TensorFlow, JAX, or sklearn loops.
- Convert Flower parameters to the SDK's gradient/update format, then hand the result to the Go runtime for aggregation and proof workflows.

Important design rule:

- Flower should not become the source of truth for verification or aggregation policy.
- The wrapper should call Mohawk hooks after local training and before remote submission.

## Phase 3: Example Ports

Create a small example folder under `sdk/python/examples/` for Flower-compatible demos.

Start with one minimal training example and one larger framework example.

Good first candidates:

- PyTorch quickstart-style client
- A lightweight evaluation-only client
- A demo that exercises compression and proof submission

Each example should show:

- local training loop
- parameter round-trip through Flower callbacks
- Mohawk compression and update submission
- a simple simulator entry point

## Phase 4: Optional Strategy Bridge

Keep Flower server strategies optional and non-blocking.

Recommended approach:

- Default path: keep aggregation in Go and only adapt the client side.
- Optional path: add a small Python bridge that forwards aggregates to the Go orchestrator over the existing SDK boundary.
- Only port a Flower strategy to Go if a real usage case requires it.

This keeps the architecture aligned with the repository's current strength: Go-owned verification and aggregation.

## Phase 5: Tests And CI

Add tests that prove the compatibility layer behaves correctly before expanding the example set.

Minimum test coverage:

- adapter smoke test with mocked Flower parameters
- serialization round-trip test for model updates
- update submission test against a mocked Mohawk runtime
- one end-to-end example test in `sdk/python/tests/`

Suggested CI additions:

- a lightweight workflow that installs the optional Flower extras
- a smoke run for the example client
- existing proof-verification checks reused where applicable

## Out Of Scope For The First PR

- claiming zero-code-change integration for all Flower examples
- moving aggregation authority out of the Go runtime
- adding every Flower framework at once
- asserting WASM attestation is automatically available for all client code paths

## Proposed First Delivery

1. Add the documentation and roadmap pointer.
2. Add the Python package extras needed for a Flower-compatible path.
3. Add the adapter skeleton and one example.
4. Add tests and a minimal CI smoke check.

That sequence keeps the branch reviewable and gives a clear path from prototype to working integration.