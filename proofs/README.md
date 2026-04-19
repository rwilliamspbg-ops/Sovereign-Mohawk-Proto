# Lean Formalization

Machine-checked formal theorem modules for the Sovereign Mohawk proof claims.

## Build

```bash
cd proofs
export PATH="$HOME/.elan/bin:$PATH"
lake update
lake build LeanFormalization Mathlib
```

## Modules

- `LeanFormalization/Theorem1BFT.lean`
- `LeanFormalization/Theorem2RDP.lean`
- `LeanFormalization/Theorem3Communication.lean`
- `LeanFormalization/Theorem4Liveness.lean`
- `LeanFormalization/Theorem5Cryptography.lean`
- `LeanFormalization/Theorem6Convergence.lean`

## Traceability

See `FORMAL_TRACEABILITY_MATRIX.md` for theorem-to-file mapping and Phase 2 coverage notes.
