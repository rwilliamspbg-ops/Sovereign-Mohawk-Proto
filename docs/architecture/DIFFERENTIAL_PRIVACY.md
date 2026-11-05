# Differential Privacy — RDP Accounting

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Rényi Differential Privacy (RDP) accountant tracking the privacy budget across
federated rounds.

- Implementation: `internal/rdp_accountant.go`.
- Budget: epsilon = 2.0 (enforced by the privacy guard).
- Formalization: `proofs/LeanFormalization/` RDP composition (Theorem 2 region).

## 2. How it works

- Each round's mechanism (gradient clipping + Gaussian noise) has an RDP cost.
- The accountant composes costs across rounds (RDP composition).
- Before a round, check that cumulative cost stays within budget epsilon = 2.0.
- If exceeded, the round is blocked.

## 3. What is formalized vs. surrogate

- Formalized: RDP composition and budget enforcement (Lean).
- Surrogate: the accountant is an accounting model; it does not prove the
  underlying mechanism is DP in the full sense. See docs/EXTERNAL_AUDIT_SCOPE.md.

## 4. Configuration

- Budget set in `internal/rdp_accountant.go` (epsilon = 2.0).
- Tests: `test/rdp_accountant_test.go`.

## 5. Cross-references

- Formal: `proofs/LeanFormalization/` (Theorem 2 region)
- Privacy guard: root `SECURITY.md`
- Threat model: `docs/security/THREAT_MODEL.md`
