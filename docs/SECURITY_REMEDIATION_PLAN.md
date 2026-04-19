# Security Remediation Plan

## Purpose

This plan turns the current review notes into a concrete remediation set. The goal is to remove Ethereum code, make safety checks fail closed, and eliminate privacy-accounting drift while keeping the Sovereign Mohawk utility coin intact.

## Scope

The work is split into four deliverables:

1. Remove Ethereum bridge code while preserving the Sovereign Mohawk utility coin.
2. Make formal checks fail closed.
3. Cap gradient dimensions before native entrypoints.
4. Make privacy accounting exact and workload-agnostic.

## 1. Decommission the Ethereum bridge surface

This is a removal effort, not a feature flag. The final state should not rely on Ethereum bridge code or `bridge_transfer()` being present but disabled. The Sovereign Mohawk utility coin remains in scope and must continue to work.

Planned changes:

- Inventory every current consumer of Ethereum bridge code and `bridge_transfer()`.
- Keep utility-coin code separate from Ethereum-specific code, then remove only the Ethereum-specific bridge components.
- Remove the `bridge_transfer` export from `internal/pyapi/api.go`.
- Remove the Python SDK bridge methods from `sdk/python/mohawk/client.py` and `sdk/python/mohawk/async_client.py`.
- Remove bridge examples and docs from `README.md`, `sdk/python/README.md`, and any operational scripts that still call the bridge flow.
- Delete or rewrite tests that only exercise the removed Ethereum bridge path so the test suite no longer depends on the deprecated API.

Suggested file targets:

- `internal/bridge/bridge.go`
- `internal/pyapi/api.go`
- `sdk/python/mohawk/client.py`
- `sdk/python/mohawk/async_client.py`
- `sdk/python/tests/test_client.py`
- `README.md`
- `sdk/python/README.md`
- `scripts/pyapi_metrics_exporter.py`
- `scripts/strict_auth_smoke.py`

Acceptance criteria:

- No code imports Ethereum bridge-only packages or symbols.
- No public SDK method or exported runtime entrypoint exposes `bridge_transfer()`.
- No docs or example scripts instruct users to rely on Ethereum bridge flows.
- The build fails if any stale reference remains.

## 2. Make formal checks fail closed

The formal-check path must never report success when the check fails. A failure needs to return a non-success HTTP status and a failure payload, with no fallback success envelope.

Planned changes:

- Audit both aggregator handlers that perform the formal Byzantine check.
- Ensure the failure branch returns immediately with a non-200 status and `formal_check_pass: false`.
- Ensure the success branch is only reachable after the check passes.
- Keep logging, but do not allow logging to mask a failed control decision.
- Add a regression test that asserts failure cannot return `status: "success"`.

Suggested file targets:

- `cmd/aggregator/main.go`
- `cmd/fl-aggregator/main.go`
- `cmd/aggregator/main_test.go`
- `cmd/fl-aggregator/main_test.go`

Acceptance criteria:

- A failed formal check always returns a failing HTTP response.
- No handler returns a success status when `formal_check_pass` is false.
- Tests cover both the failure and success paths.

## 3. Cap gradient dimensions before native entrypoints

The gradient-compression path needs a hard dimension cap before any CGO/native call or unsafe slice creation.

Planned changes:

- Set a single documented cap of `MAX_DIM = 10_000_000` in the Python SDK.
- Reject oversized gradient vectors before they reach the native SDK entrypoint.
- Mirror the same guard in the native `CompressGradients` and `CompressGradientsZeroCopy` entrypoints so a direct caller cannot bypass Python-side validation.
- Reject zero-length and negative/invalid lengths explicitly.
- Update the tests for both standard and zero-copy compression to exercise oversized input rejection.

Suggested file targets:

- `sdk/python/mohawk/client.py`
- `sdk/python/tests/test_client.py`
- `internal/pyapi/api.go`
- `internal/pyapi/compress_benchmark_test.go`

Acceptance criteria:

- Oversized vectors fail before any CGO/native buffer access.
- The limit is enforced consistently across standard and zero-copy paths.
- Regression tests fail if the cap is removed or bypassed.

## 4. Make privacy accounting exact and workload-agnostic

Privacy accounting should use exact rational values for bookkeeping and should not vary with runtime workload profile.

Planned changes:

- Keep epsilon bookkeeping in rational form end-to-end where feasible.
- Replace float-derived epsilon composition with rational numerator/denominator inputs where the source is known exactly.
- Remove any `workloadProfile` contribution from privacy-budget calculation.
- Standardize the privacy-budget source of truth so different execution modes do not produce materially different epsilon values.
- Preserve human-readable output through canonical rational formatting, not binary-float artifacts.
- Add regression tests that prove the same budget is reported across modes and that the known float artifact does not reappear.

Suggested file targets:

- `internal/rdp_accountant.go`
- `internal/dp_config.go`
- `test/rdp_accountant_test.go`
- any caller that computes privacy budgets from workload metadata

Acceptance criteria:

- Privacy budget values are stable across modes.
- No budget path depends on `workloadProfile`.
- Output does not expose IEEE-754 rounding noise for known exact values.
- Tests cover exact accumulation and cross-mode equivalence.

## Execution order

1. Remove Ethereum bridge code while keeping utility coin code intact.
2. Fix the formal-check fail-closed behavior.
3. Add the gradient-size cap at both SDK and native boundaries.
4. Normalize privacy accounting to rational arithmetic and remove workload-dependent variance.
5. Run the targeted test suites, then the full repository validation.

## Done means

The remediation is complete when the repository no longer exposes the deprecated bridge surface, formal failures cannot return success, oversized gradient inputs are rejected before native access, and privacy accounting is reproducible with rational values only.
