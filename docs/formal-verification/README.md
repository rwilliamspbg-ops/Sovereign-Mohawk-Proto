# Formal Verification & Proofs

---

## Getting Started with Formal Verification

- **FORMAL_VERIFICATION_GUIDE.md** - Lean setup, verification workflow
- **THEOREM_SPECIFICATIONS.md** - 6 theorem formalization specs

---

## Proof Documentation

- **PROOF_TRACEABILITY_MATRIX.md** - Theorem → Proof → Runtime Evidence
- **PROOF_CHECKLIST.md** - Step-by-step verification checklist
- **EXTENDING_PROOFS.md** - Adding new theorems to the system

---

## Formalization Details

All formal proofs are in `proofs/LeanFormalization/` directory:
- `Theorem1BFT.lean` - Byzantine consensus claims
- `Theorem3Communication.lean` - Communication complexity
- `Theorem4Liveness.lean` - Liveness and safety

---

## Running Verification Locally

```bash
make refresh-formal-validation    # Build and verify all proofs
make validate-formal              # Check cached results
cd proofs && lake build            # Build Lean modules
```

---

See [../INDEX.md](../INDEX.md) for complete documentation navigation.
