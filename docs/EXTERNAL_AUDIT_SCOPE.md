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

### 1.1 Review in under 30 minutes

If you only have half an hour, these three steps cover the highest-risk surface.

**Step 1 — rebuild and audit the axioms (~10 min)**

```bash
cd proofs && lake build

# no placeholders, no global axioms
# scope to the project's own modules, not proofs/.lake/ (Mathlib and its
# dependencies produce thousands of hits)
grep -rn "sorry\|admit" --include=*.lean proofs/LeanFormalization proofs/Refinement proofs/Specification
grep -rn "^axiom " --include=*.lean proofs/LeanFormalization proofs/Refinement proofs/Specification

# spot-check that no declaration carries a non-kernel trust
cat > _axprobe.lean <<'EOF'
import LeanFormalization.Theorem1BFT
#print axioms LeanFormalization.chernoffBoundZ_deployment_scale_tiny
#print axioms LeanFormalization.chernoff_hierarchical_bound_deployment_scale
EOF
lake env lean _axprobe.lean; rm -f _axprobe.lean
```

Expect: **zero** hits from both greps (the only `admit` in the project modules
is the word in a comment in `Refinement/MultiKrum.lean`), and `#print axioms`
reporting only `propext`, `Classical.choice`, `Quot.sound` — no
`._native.native_decide.ax_1_1`, no `sorryAx` (see §6). Full history:
`docs/LEAN_AXIOM_AUDIT_AND_REMOVAL_PLAN.md`.

**Step 2 — read the three artifacts in this order (~10 min)**

1. `proofs/FORMAL_TRACEABILITY_MATRIX.md` — per-claim status of all 23 rows.
   Start with every row *not* marked `fully_formalized`.
2. §3 of this document — the four highest-priority review targets.
3. `results/zk/weight-proof-latest.json` — measured cost of the real circuit
   (verify 0.675 ms, prove 38.0 ms, setup 41.3 s, 9 569 constraints, 164-byte
   proof). Every zk latency claim in the repo should resolve to this file.

**Step 3 — confirm one refinement bridge by hand (~10 min)**

Pick a row from the traceability matrix, open the Lean spec and the Go predicate
it maps to, and check the transcription against the pinned vectors. Report any
row where the two disagree — that is the finding we most want.

Report format: `docs/AUDIT_REPORT_TEMPLATE.md`. Credit policy: `AUDITS.md`.

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
   - **Load-bearingness, now machine-checked (matrix row 23):**
     `proofs/LeanFormalization/HypothesisNecessity.lean` exhibits, for each
     transcript hypothesis of `recovery_yields_secret` and
     `schnorr_special_soundness`, a concrete instance where that hypothesis
     fails and the conclusion fails with it. The `Fact (Nat.Prime …)` instance
     is deliberately not refuted: it is a number-theoretic assumption, not a
     condition on transcripts (dropping it makes `ZMod n` a ring in which
     inverses need not exist).
   - **The forking core is now PROVED, not assumed (matrix row 25, 2026-11-20).**
     `proofs/LeanFormalization/SchnorrForking.lean` replaces the deleted
     `ForkingLemma`/`ForkingStep` material with a concrete, checkable argument:
     * `SchnorrAdversary` is **two-stage** — `commit pk r` takes no challenge —
       so "both transcripts share a commitment" is a property of the model, not
       an assumption. This is the part of rewinding that is pure algebra.
     * `exists_fork_of_card` proves the remaining content as a **pigeonhole
       principle** over a finite set: if the adversary succeeds on more than `q`
       of the `q²` (randomness, challenge) pairs — success probability `> 1/q`
       — some randomness supports two distinct challenges, and
       `forking_extractor` recovers the key. No probability library is used.
     * `success_card_le_of_dl_hard` is the contrapositive security statement:
       under the hardness assumption `SchnorrDLHard` (an explicit `def`, never
       an axiom) every two-stage adversary succeeds on at most `q` pairs. The
       only hypotheses are `Fact (Nat.Prime q)` and hardness.
     * `exists_forger_card_eq_q` + `tightness_witness_not_forked` show the
       threshold `q` is **tight** — it cannot be lowered.
     - Not proved, stated openly: no probabilistic amplification (cardinality,
       not probability), no efficiency requirement on the constructed solver,
       and the group is still the abstract `ZMod q`.

2. **Ed25519 UF-CMA model soundness**
   - `proofs/LeanFormalization/TheoremUF_CMA_Ed25519.lean`
   - Question: does the model capture the real Ed25519 verification equation,
     or does it abstract away the curve/field details that carry the security?
   - Note: `Ed25519_uf_cma`'s `h_secure` is a hardness assumption, not a
     refutable condition, so it has no negative control; the module's own
     docstring says a full proof needs a genuine Ed25519 verifier plus a
     discrete-log reduction. The refutable algebraic core is
     `schnorr_special_soundness`, covered by row 23.
   - **The verification equation is now modelled and bridged (matrix row 26,
     2026-11-20).** `proofs/LeanFormalization/Ed25519VerificationEquation.lean`
     states the equation `S·B = R + h·A` as a structural proposition about
     `AffinePoint`, packages the six group laws the transfer needs in
     `Ed25519GroupLaws`, and proves `verificationEquation_iff_ModEq`: under those
     laws the curve equation is **equivalent** to the Schnorr exponent equation
     `s ≡ r + h·a (mod L)`. `ed25519_two_equations_recover` then transfers two
     Ed25519 equations that share the nonce point `R` to the hypotheses of
     `recovery_yields_secret`, so the key is recovered.
     - **The group laws are ASSUMED, not proved** — `affineScalarMulImpl` and
       `affineAdd` are unaudited. They are an explicit structure supplied at each
       use site, never a global `axiom`; `constantMul_violates_oneMul` and
       `constantMul_not_injective` are negative controls showing the hypotheses
       are load-bearing.
     - **This is not a UF-CMA proof.** The extractor needs the two equations to
       share `R` (nonce reuse); an honest signer never reuses a nonce, so
       `Ed25519_uf_cma` still requires its caller-supplied `h_secure`. Closing
       that gap needs the random-oracle forking argument, which is not
       formalized here.

3. **ZK circuit ↔ Go verifier refinement** (updated 2026-11-18)
   - `proofs/Refinement/ZKCircuit.lean`, `proofs/LeanFormalization/Theorem5Cryptography.lean`
     (`WeightUpdateCircuit` section), `proofs/LeanFormalization/Theorem5MiMCFormalization.lean`
   - `internal/zkweight_circuit.go` (the circuit production verifies),
     `internal/zksnark_circuit_verifier.go` (the older single-scalar path)
   - Question: does the Lean circuit model match the gnark circuit actually
     compiled? `weight_impl_accept_iff` (row 22) is the exact acceptance
     condition; the soundness direction is Groth16 knowledge soundness and is
     deliberately not claimed.
   - **Constraint correspondence (2026-11-20):** `WeightRelation` now transcribes
     `WeightUpdateCircuit.Define` constraint-by-constraint, including the 64-bit
     per-component and 63-bit norm-bound range checks, with
     `weight_relation_range_checks` projecting them and a negative control per
     range conjunct (row 21).
   - **MiMC/VK surrogates replaced (2026-11-20):** the commitment is a
     `ZMod bn254Prime` element and the hash is the real MiMC construction
     (row 24): a 110-round keyed block cipher, Miyaguchi–Preneel compressor,
     Merkle–Damgård chain. The block cipher is proved a permutation
     (`mimcEncrypt_bijective`) with a unique preimage per digest
     (`mimcEncrypt_preimage_unique`); `zk_impl_accept_iff` characterizes the
     acceptance predicate exactly. The identity stand-in and the
     `zkSpecVerify stmt ↔ stmt.commitment ≠ 0` triviality are **gone**;
     `zk_spec_verify_iff` is now the honest image characterization and
     `zk_impl_refines_spec` states its image hypothesis explicitly.
   - **Verification keys are structural now:** `circuitVK`/`weightCircuitVK`
     are `deriveVK` of a `CircuitDescription` (public-input count, witness
     arity, and the **measured** constraint count — 331 for
     `DataCommitmentCircuit`, 9,569 for `WeightUpdateCircuit`), and
     `deriveVK_injective` proves distinct circuits have distinct keys. The
     previous magic constants are gone.
   - The MiMC round injectivity is now stated at the BN254 scalar modulus
     (`mimcRound_bn254_injective`); `Nat.Prime r` is an explicit hypothesis
     (trial-division decidability), the exponent coprimality is discharged.
   - Is the multi-party setup (MPC, N=3, beacon-sealed) correctly threaded into
     the verification key used at runtime? Note it is an in-process simulation,
     not a distributed ceremony. **Go-side inspection (2026-11-20):**
     `mpcSetupBN254` runs gnark's Phase1 + Phase2 `mpcsetup` flow with N=3
     chained contributions and a beacon, and `verifyWeightProofBytes` verifies
     against the resulting `weightVK`. The Lean `weightCircuitVK` is now a
     structural derivation (`deriveVK`) of the measured `WeightUpdateCircuit`
     description rather than a magic constant; the honest derivation would hash
     the compiled constraint system, which needs curve machinery this Mathlib
     lacks, and that residual gap is stated rather than hidden.

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

**Declared axioms: 0.** No `axiom` declaration is used anywhere in `proofs/`.

**No toolchain trust remains either.** The last `native_decide` —
`LeanFormalization.chernoffBoundZ_deployment_scale_tiny` (`Theorem1BFT.lean`),
which had asserted `Lean.ofReduceBool` on a ~5000-digit rational inequality —
is gone. The goal `(11/10)^50000 / 2^25000 ≤ 1/10^1000` is an inequality
between two `1000`th powers, so `pow_le_pow_iff_left₀` reduces it to
`11^50 ≤ 2^74 * 5^49`, a 53- versus 57-digit integer comparison that `norm_num`
decides directly; the exponent reduction is the whole proof.

`#print axioms` over the whole development now reports only Mathlib's
foundation (`propext`, `Classical.choice`, `Quot.sound`): no `sorryAx`, no
`._native.native_decide.ax_1_1`, and no `axiom` declaration.

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
- `Aggregator.ProcessRound` **does** verify a real `WeightProof` against the
  caller's `WeightStatement` when one is supplied (`internal/batch/aggregator.go`,
  `internal/zkweight_circuit.go`), and falls back to the single-scalar
  `DataCommitmentCircuit` path. What is still missing is a **production producer**:
  the only constructors of a `WeightProof` are `cmd/simulate`, `cmd/zkweightbench`
  and tests, and `internal/computeproof.Trace` has no production caller at all
  (`docs/ZK_FINALIZATION_PLAN.md` M2, Gap 1). Read "wired" as *wired into the
  round path, not yet produced by service code*.
- `genesisVK` (in `internal/zksnark_verifier.go`) is still a fixed identity with
  no circuit behind it. Two keys *are* circuit-derived: `dataCommitmentVK` (the
  single-scalar `DataCommitmentCircuit`) and the key behind
  `VerifyWeightProof` / `VerifyWeightProofAgainst` (the `WeightUpdateCircuit`).
  Both come from the simulated in-process setup described above.

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
