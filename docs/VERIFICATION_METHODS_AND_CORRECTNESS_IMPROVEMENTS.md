# Verification Methods And Correctness Improvements

This note records the next verification upgrades that would give the largest increase in confidence per unit of effort.

## Completed In This Pass

- Aligned the runtime convergence envelope and Phase 3b theorem tests to the current Lean `1 / (2KT) + ζ²` model.
- Removed a runtime correctness bug where `ζ²` was being treated as `sqrt(ζ²)` in the convergence threshold.
- Strengthened the specification/refinement privacy layer from vacuous `True`-style definitions to exact rational composition lemmas.
- Replaced the vacuous cryptography specification with a small but meaningful statement/proof model supporting completeness, soundness, and constant-size/cost invariants.

## Highest-Leverage Next Steps

### 1. Turn claim-level docs into generated artifacts

Generate the public theorem matrix from the Lean sources plus a checked metadata file instead of editing the claims by hand.

Why this helps:
- Prevents docs from drifting ahead of the formalization.
- Makes `surrogate verified` vs `fully verified` status machine-enforced.
- Gives reviewers one canonical source of truth.

Suggested implementation:
- Add a checked metadata file such as `proofs/theorem_claims.json`.
- Include fields for `claim_text`, `formal_scope`, `status`, `lean_modules`, `runtime_tests`.
- Generate `FORMAL_TRACEABILITY_MATRIX.md` from that file in CI.

### 2. Add theorem-to-runtime consistency checks

The runtime formulas for liveness, privacy accounting, and convergence should be compared directly against the formulas documented in Lean-facing proof metadata.

Why this helps:
- Catches drift like the old `1/(2√KT)` vs `1/(2KT)` mismatch.
- Makes theorem-backed runtime guards auditable.

Suggested implementation:
- Export a small JSON artifact from the proof package with formula IDs and constants.
- Add a CI script that checks runtime code references those same constants or formulas.

### 3. Separate `surrogate verified` from `mathematically formalized`

Keep both, but label them differently in CI, docs, and reports.

Why this helps:
- Surrogate proofs are still useful engineering evidence.
- Auditors care deeply about the difference between exact formalization and model-level validation.

Suggested status labels:
- `fully_formalized`
- `model_verified`
- `surrogate_verified`
- `runtime_validated_only`

### 4. Add property-based tests for theorem-shaped invariants

Current tests are mostly point checks. Add randomized invariant checks for monotonicity, append-composition, and threshold preservation.

Good candidates:
- RDP composition is additive and monotone for nonnegative steps.
- Chernoff-style redundancy bound decreases as redundancy increases.
- Convergence envelope decreases as rounds or clients increase.
- Runtime guards stay conservative relative to the documented envelope.

### 5. Promote the specification/refinement layer to a release gate

Right now the spec/refinement files exist, but they should become required evidence rather than optional structure.

Suggested gate:
- No public theorem claim can be marked `fully_formalized` without:
  - a spec theorem,
  - a refinement theorem,
  - and a runtime test mapping.

### 6. Add local proof execution to the developer container

This environment did not have `lean` or `go`, which makes it harder to finish verification work safely.

Suggested improvement:
- Add a devcontainer or reproducible local tool bootstrap that includes:
  - Lean/Elan
  - Go
  - Python
  - Mathlib cache bootstrap

### 7. Use proof-review lint rules, not just placeholder scans

Placeholder scans are necessary but too weak on their own.

Add advisory checks for:
- theorems proved by `rfl` where the statement mentions the same expression on both sides,
- theorems whose conclusion is `True`,
- specs that reduce to `True`,
- report text that uses `production ready` or `verified` without a matching status label.

## Recommended Phase Labels

- Phase 3b:
  Complete abstract-model and rational-envelope formalization, plus runtime alignment.
- Phase 3c:
  Add claim-generation, theorem/runtime consistency CI, and proof-review linting.
- Phase 4:
  Pursue measure-theoretic RDP and stochastic convergence formalization with Mathlib probability.
