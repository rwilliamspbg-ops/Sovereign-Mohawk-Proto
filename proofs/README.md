# Lean Formalization

Machine-checked formal theorem modules for the Sovereign Mohawk proof claims.

## Build

```bash
cd proofs
export PATH="$HOME/.elan/bin:$PATH"
df -h .

# Optional cleanup if workspace is tight on disk
rm -rf .lake/build .lake/packages/mathlib/.lake/build

lake update
lake build LeanFormalization Specification Mathlib
```

## Modules

- `LeanFormalization/Theorem1BFT.lean`
- `LeanFormalization/Theorem2RDP.lean`
- `LeanFormalization/Theorem3Communication.lean`
- `LeanFormalization/Theorem4Liveness.lean`
- `LeanFormalization/Theorem5Cryptography.lean`
- `LeanFormalization/Theorem6Convergence.lean`

## Specification Modules

- `Specification/System.lean`
- `Specification/Byzantine.lean`
- `Specification/Communication.lean`
- `Specification/Liveness.lean`
- `Specification/Cryptography.lean`
- `Specification/Convergence.lean`

The Specification package currently uses explicit `sorry` placeholders for
proof obligations that are not yet discharged. These are tracked as in-progress
work and are intentionally visible.

## Traceability

See `FORMAL_TRACEABILITY_MATRIX.md` for theorem-to-file mapping and Phase 2 coverage notes.
