# External Audit Scope — Sovereign-Mohawk-Proto

**Status**: Seeking independent review (zero-budget, open-source).
**Last updated**: 2026-11-04
**Audit-ready commit**: see `git rev-parse HEAD` on `main` after the latest merge.

This document defines what we ask external reviewers to look at, in priority order,
what is already machine-checked, and what the known limitations are. It is the
single entry point for anyone considering a review.

## 1. How to rebuild and check everything (one command)

```bash
make audit-ready-check
```

which runs `lake build`, `check_refinement.py`, and the theorem/runtime
consistency check. Equivalent manual commands:

```bash
cd proofs && lake build
python3 scripts/check_refinement.py --lean proofs/Specification/System.lean --go internal/
python3 scripts/ci/check_theorem_runtime_consistency.py
```

CI reproduces the same checks on every PR (`verify-lean-formalization`,
`verify-lean-formalizations`, `proof-traceability`, `proof-quality-checks`).

## 2. Trusted base vs. proofs (read this first)

- **Trusted base**: Lean 4 core, Mathlib v4.30.0-rc2, gnark-crypto, the Go
  standard library, and the Go compiler. We do not re-prove these.
- **Proofs**: everything under `proofs/` — `LeanFormalization/`, `Refinement/`,
  `Specification/`. These are the claims under review.
- **Runtime**: `internal/` Go code. Refinement bridges (under `proofs/Refinement/`)
  connect Lean specs to Go predicates.

A theorem is *not* vacuous if its hypotheses are satisfiable and its conclusion
is not trivially `True`. Reviewers are encouraged to check for (a) theorems
whose conclusion holds by `rfl`/`trivial` with no real content, (b) axioms
standing in for unproven lemmas, and (c) `sorry` placeholders.

## 3. Highest priority — please review these

1. **Discrete-log reduction + Forking Lemma core**
   - `proofs/LeanFormalization/DiscreteLogReduction.lean`
   - Axioms in play: none. `dlL_prime` was demoted from a global `axiom` to the
     explicit `Fact (Nat.Prime dlL)` hypothesis on the four declarations that
     need it (#318); `ForkingLemma` and `ed25519_uf_cma_from_dlp` were deleted
     as dead (#313).
   - Question: is the reduction algebraically sound? Are the assumptions
     discharged by a real forking-lemma argument, or are they load-bearing?

2. **Ed25519 UF-CMA model soundness**
   - `proofs/LeanFormalization/TheoremUF_CMA_Ed25519.lean`
   - Question: does the model capture the real Ed25519 verification equation,
     or does it abstract away the curve/field details that carry the security?

3. **MiMC circuit ↔ Go verifier refinement**
   - `proofs/Refinement/ZKCircuit.lean`, `proofs/LeanFormalization/Theorem5MiMCFormalization.lean`
   - `internal/zksnark_circuit_verifier.go` (circuit + MPC setup)
   - Question: does the Lean circuit model match the gnark circuit actually
     compiled? Is the multi-party setup (MPC, N=3, beacon-sealed) correctly
     threaded into the verifier key used at runtime?

4. **Convergence / straggler refinement bridges**
   - `proofs/Refinement/Convergence.lean`, `proofs/Refinement/Straggler.lean`
   - `proofs/LeanFormalization/Theorem6MeasureTheoreticConvergence.lean`
   - Question: do the refinement predicates (`convergence_impl_refines_spec`,
     `straggler_impl_refines_spec`) genuinely imply the spec properties, or
     are the bounds vacuous?

## 4. Medium priority

- **Claim accuracy**: compare `README.md`, `ROADMAP*`, and `docs/NEXT_ACTIONS_PLAN.md`
  against the actual theorem statements. Flag any over-claim.
- **Remaining axioms / sorry**: full list in section 6.
- **BFT / topology safety bridge**: `proofs/Refinement/BFT.lean` vs.
  `internal/hbft/` (Go's `n > 2*f+2` check vs. Lean's `2*f < n`).

## 5. Lower priority (security surface)

- Aggregation path: `internal/batch/aggregator.go` (gradient commitment routing).
- PQC hybrid KEX: `internal/crypto/` (x25519-mlkem768).
- TPM attestation stubs: `internal/tpm/`.
- Concurrency / race: `go test -race ./...` (CI runs this).

## 6. Known limitations and remaining axioms (be honest)

Axioms present in the proof tree: **0**. The Lean development is axiom-free;
`#print axioms` over all 272 theorems and lemmas reports only Mathlib's
foundation (`propext`, `Classical.choice`, `Quot.sound`).

Previously-listed axioms that have since been **removed**:

| File | Axiom | How it was removed |
|---|---|---|
| `DiscreteLogReduction.lean` | `ForkingLemma` | deleted — dead, zero dependents (#313) |
| `DiscreteLogReduction.lean` | `ed25519_uf_cma_from_dlp` | deleted — dead, zero dependents (#313) |
| `Theorem5Cryptography.lean` | MiMC collision resistance | deleted — dead, zero dependents (#313) |
| `Refinement/MultiKrum.lean` | 8 `Float.*` ordering axioms | packaged as the `FloatOrderLaws` structure, passed explicitly to each theorem that needs it — no longer global axioms (#316) |
| `DiscreteLogReduction.lean` | `dlL_prime` | demoted from a global `axiom` to the explicit `Fact (Nat.Prime dlL)` hypothesis on the four declarations that need it (#318) |

`sorry` placeholders: 0. The last one (`supermartingale_convergence_ae` in
`SupermartingaleConvergence.lean`, the almost-sure strengthening) was closed in
#315 via the supermartingale transform `M_t = V_t + S_t - C_t` and
`Submartingale.exists_ae_tendsto_of_bdd`. CI enforces no *new*
`sorry`/`admit`/`axiom` beyond the documented set.

Other honest limitations:
- The MPC trusted setup is simulated in-process (N=3 contributors chained in
  one goroutine), not a distributed ceremony over independent machines.
- The Lean model for Theorem 5 is an abstract constant-operation cost model;
  it does not formalize Groth16 succinctness/soundness or q-SDH (Mathlib
  lacks pairing machinery).
- Per-round gradient/model commitments are not yet populated by any production
  caller; `Aggregator.GradientCommitment` must be supplied by the caller.
- `genesisVK` (in `internal/zksnark_verifier.go`) is still a fixed identity
  with no circuit behind it; only the additive `dataCommitmentVK` path is
  circuit-derived.

## 7. What we are NOT asking reviewers to do

- Do not audit Mathlib, gnark, or Go stdlib.
- Do not audit the build/CI infrastructure beyond confirming reproducibility.
- Do not treat the in-process MPC as a production ceremony.

## 8. How to contribute a review

- Open a GitHub issue labeled `audit-help-wanted` + component label
  (e.g., `formal-review`, `security-review`, `crypto-review`).
- Or comment directly on the relevant source file via a PR.
- Credit: every reviewer is listed in `AUDITS.md` with scope + date, plus
  co-authorship on any resulting technical note.

## 9. Contact

- Maintainer: @rwilliamspbg-ops
- Security disclosures: see `SECURITY.md` (private vulnerability reporting enabled).
- Lean community: we are posting to leanprover.zulipchat.com.
