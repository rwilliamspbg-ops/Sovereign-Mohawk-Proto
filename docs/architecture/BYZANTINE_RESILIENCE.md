# Byzantine Resilience Architecture

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Single-tier Multi-Krum filtering is fully implemented and formalized.

- Implementation: `internal/multikrum.go` (`MultiKrumSelect`).
- Guard: `n > 2f+2` (enforced in code; `internal/hbft/simulator.go` rejects
  configurations violating it).
- Formalization: `proofs/Refinement/MultiKrum.lean`, `proofs/LeanFormalization/`
  (Multi-Krum selection properties).

## 2. How it works

Given `n` gradient updates with at most `f` Byzantine (malicious) ones:
1. Compute pairwise squared L2 distances.
2. For each update, sum the `n - f - 2` smallest distances (Krum score).
3. Select the `m` updates with the lowest scores (default `m = n - f - 2`).
4. Aggregate (mean) the selected updates.

Requires `n > 2f+2` so that `n - f - 2 > 0`.

## 3. What is formalized vs. surrogate

- **Formalized**: single-tier Multi-Krum selection properties (Lean).
- **Surrogate (not formalized)**: hierarchical composition across L1-L4 tiers.
  The Lean artifacts model a single aggregation step; the tiered composition is
  claimed but not proven. See `docs/EXTERNAL_AUDIT_SCOPE.md`.

## 4. Configuration

- `f` (Byzantine bound) is derived per tier from committee size.
- `internal/hbft/simulator.go` panics/fails if `NodesPerCommittee <= 2*f+2`.
- Tests: `internal/multikrum_test.go`, `multikrum_property_test.go`,
  `aggregator_multikrum_test.go`, `multikrum_lean_correspondence_test.go`.

## 5. Cross-references

- Formal: `proofs/Refinement/MultiKrum.lean`
- BFT bridge: `proofs/Refinement/BFT.lean` (Lean `2*f < n` vs Go `n > 2*f+2`)
- Architecture overview: `docs/ARCHITECTURE.md`
