# External Audit Scope — Sovereign-Mohawk-Proto

**Status**: Seeking independent review (zero-budget, open-source).
**Last updated**: 2026-11-21
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

1. `proofs/FORMAL_TRACEABILITY_MATRIX.md` — per-claim status of all 43 rows. <!-- matrix-rows: 43 -->
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
     - The **quantitative** version now exists too (matrix row 31,
       `SchnorrUF_CMA.lean`, 2026-11-20). Row 25 gave an exact cardinality
       threshold; row 31 proves the second-moment amplification the literature
       states. In the two-stage RO model the tape fixes the commitment, so
       acceptance for a fixed tape is a predicate on the challenge alone;
       writing `ε` for the success probability and `φ` for the fork probability,
       Cauchy–Schwarz (`Finset.sum_mul_sq_le_sq_mul_sq`) yields
       `φ ≥ ε² - ε/N`, and `fork_extraction` turns every fork into `Extracts`,
       so under `SchnorrDLHard`, `ε ≤ 1/N`. `successProbability_eq_one_div_card`
       shows the `1/N` bound is tight.
     - Not proved, stated openly: the game is **identification /
       impersonation**, not full signature UF-CMA (no signing oracle, no
       oracle-query bookkeeping); the random oracle is abstracted to a uniform
       challenge rather than a function-space measure; no efficiency requirement
       on the constructed solver; and the group is still the abstract `ZMod q`.
     - The game was then lifted from identification to **signature UF-CMA**
       (matrix row 32, `SchnorrUF_CMAWithOracle.lean`, 2026-11-20): a signing
       oracle (`honestResponse`, with `honestResponse_accepts`) and a
       not-queried freshness condition (`ufcmaForges`) are added, the prefix is
       `(tape, sigs)` with a fixed number of queries, and the same
       second-moment argument gives `φ ≥ ε² - ε/N` and `ε ≤ 1/N` under
       `SchnorrDLHard`. The classical forking loss `ε² − ε/N` (`N` the
       challenge-space size) is **not** recovered: the abstraction is a uniform
       challenge, and adaptive query histories (row 41) are modelled without
       changing that.

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
     `AffinePoint`, packages the four group laws the transfer needs in
     `Ed25519GroupLaws`, and proves `verificationEquation_iff_ModEq`: under those
     laws the curve equation is **equivalent** to the Schnorr exponent equation
     `s ≡ r + h·a (mod L)`. `ed25519_two_equations_recover` then transfers two
     Ed25519 equations that share the nonce point `R` to the hypotheses of
     `recovery_yields_secret`, so the key is recovered.
     - **The group laws are ASSUMED, not proved** — `affineScalarMulImpl` and
       `affineAdd` are unaudited. They are an explicit structure supplied at each
       use site, never a global `axiom`; `nonAdditiveSmul_violates_addMul`,
       `paritySmul_violates_mulMul`, `paritySmul_violates_congMul` and
       `constantMul_not_injective` are negative controls showing the
       hypotheses are load-bearing. A first increment is now **proved** about the
       real `affineAdd` (matrix row 40): commutativity on reduced representatives,
       the two-sided identity for points with an honest `inf` flag, and
       canonicity preservation. **Associativity is not proved**, and it is the
       law these four consumed hypotheses need, so the bundle above is unchanged.
     - **This is not a UF-CMA proof.** The extractor needs the two equations to
       share `R` (nonce reuse); an honest signer never reuses a nonce, so
       `Ed25519_uf_cma` still requires its caller-supplied `h_secure`. Closing
       that gap needs the random-oracle forking argument. That argument is now
       formalized for the identification game (matrix row 31); the residual is
       the signing-oracle bookkeeping for full signature UF-CMA.
   - **`Refinement/DLP.lean` rebuilt from a vacuous stub (matrix row 28,
     2026-11-20).** It previously defined `dlpHard := True`, a spec and an impl
     that were the *same* guard (`pk ≠ 0 ∧ sig ≠ []`), and a toy `dlpImplSign`.
     The spec is now `Ed25519VerificationEquation`, the impl is
     `ed25519VerifyCore`'s coordinate comparison, and
     `dlp_nonce_reuse_recovers` connects two accepting witnesses to
     `ed25519_two_equations_recover`. The byte-level decode is still not
     refined (stated in the module docstring).

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

4. **Convergence / straggler refinement bridges** — answered 2026-11-20 (matrix row 27)
   - `proofs/Refinement/Convergence.lean`, `proofs/Refinement/Straggler.lean`
   - Question: do the refinement predicates genuinely imply the spec
     properties, or are the bounds vacuous?
   - **Answer: three of them WERE vacuous, and are removed.** A previous
     `convergence_impl_floor_ge_spec` stated `heterogeneity ≥ 0` from the
     hypothesis `0 ≤ heterogeneity` and proved it by `exact hh`;
     `straggler_adversarial_refines` proved `(if d < r then 0 else 1) =
     stragglerAdversarialSpec r d` by `rfl` with the spec *defined* as the Go
     expression; `stragglerChernoffEnvelope_nonneg` was `0 ≤ exp _`, true of
     every exponential. All three are gone (module docstrings record why).
   - **Replacements that carry content:**
     `effectiveThreshold_eq_envelope` (the runtime guard `Threshold +
     Heterogeneity` *is* the envelope when `Threshold = 1/(2KT)`),
     `convergence_impl_floor_ge_spec` (a real branch inequality using both
     `K ≤ 0 ∨ T ≤ 0` and `0 ≤ heterogeneity`), `straggler_impl_le_spec` (the Go
     clamp never exceeds the uncapped Lean spec — the runtime is never more
     optimistic than the theorem), `straggler_independent_refines_spec`, and
     `stragglerChernoffEnvelope_le_one`.
   - **Negative controls:** `convergence_refines_spec_hhet_needed`,
     `convergence_floor_npos_needed`, `straggler_impl_le_spec_out_of_range`.
   - **Still open, and stated:** the envelopes agree only under the bridge
     hypothesis `heterogeneity = zeta^2`, which is a *configuration* fact about
     how the monitor is wired, not a theorem; and the Go floor is more
     permissive than the spec's degenerate case.
   - **Q3 (measure-theoretic convergence) answered 2026-11-20 (matrix row
     30).** It was **not** an envelope restatement, but it did over-claim: the
     docstring said the model was "built on Mathlib's PMF" when there is no
     PMF, measure or `expectation` in the file (`noiseVariance` was the
     identity), and `convergence_rate_from_descent` proved only a
     nonnegativity bound while its docstring claimed the `O(1/√T)` rate. Both
     fixed: `noiseVariance` removed, docstring honest, and the rate now really
     proved — `convergence_rate_uniform` gives
     `g² ≤ D/(T·η) + η·L·σ²/2`, and `convergence_rate_sqrt_T` optimizes it to
     `g² ≤ sqrt(2·L·σ²·D/T)`. The descent lemma remains an explicit hypothesis
     (smoothness/convexity are not modelled).

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

Two further **explicit hypotheses** (not axioms) were added in #361 and are
disclosed at each use site:

- `SchnorrDLHard` (`SchnorrForking.lean`) — the discrete-logarithm hardness
  assumption the forking security reduction consumes.
- `Ed25519GroupLaws affineBase` (`Ed25519VerificationEquation.lean`) — **four**
  group laws for the unaudited `affineScalarMulImpl`/`affineAdd`, reduced from
  six on 2026-11-21: `zeroMul` and `oneMul` had zero dependents and were removed,
  so the security theorems now assume strictly less. Each surviving law has a
  concrete violator (see the module docstring's consumer table).

So the full set of standing assumptions is `FloatOrderLaws`,
`Fact (Nat.Prime dlL)`, `SchnorrDLHard` and `Ed25519GroupLaws`. None is an
`axiom`; the first two are number/IEEE facts, the latter two are cryptographic
and algebraic assumptions of the security statements. <!-- standing-assumptions: 4 -->

Other honest limitations:
- The MPC trusted setup is simulated in-process (N=3 contributors chained in
  one goroutine), not a distributed ceremony over independent machines.
- The Lean model for Theorem 5 is an abstract constant-operation cost model;
  it does not formalize Groth16 succinctness/soundness or q-SDH (Mathlib
  lacks pairing machinery).
- **The Gaussian RDP bound is structurally out of reach of the current
  framework, not merely unfinished** (made precise 2026-11-20; **SUPERSEDED
  2026-11-21 — the gap is CLOSED, see the update below; retained as the
  historical record of the pre-#371 framework**). Row 2's
  `gaussianRDPBound` is an *existence witness*: it exhibits a nonnegative
  `eps = α/(2σ²)` and derives nothing. The reason it cannot be strengthened
  in place is that `RenyiDivergence` is declared
  `{α : Type*} [Fintype α] (p q : α → ℝ)` -- **finite support only** -- while
  the Gaussian mechanism's output distribution is continuous, so its
  divergence cannot even be *stated*. A real derivation needs (i) a
  measure-theoretic Rényi divergence
  `D_α(p‖q) = (1/(α-1))·log ∫ p^α q^{1-α} dμ`, and (ii) the completed-square
  Gaussian integral with a shift/change of variables. Mathlib ships
  `integral_gaussian` (`∫ exp(-b·x²) dx = √(π/b)`); the framework, the shift
  lemma, and the integral itself are all now present (see the 2026-11-21 update
  below).
* **Update (2026-11-21, matrix row 34): BOTH prerequisites are now MET, and the
   gap is CLOSED for the scalar fixed-variance case.**
   `LeanFormalization/RenyiDivergenceMeasure.lean` defines the measure-theoretic
   divergence and proves the existing finite-support `RenyiDivergence` is exactly
   its counting-measure special case, so the old development is subsumed.
   `gaussianIntegral_shift` derives `∫ exp(-b·(x−c)²) dx = √(π/b)` from Mathlib's
   `integral_gaussian` via translation invariance of Lebesgue measure
   (`measurePreserving_add_right` + `MeasureTheory.integral_map`).
   `gaussianRDP_integrand` and `gaussianRDP_integral` then **prove** the
   completed-square identity `∫ q^α / p^(α-1) = exp(α(α−1)Δ²/(2σ²))` for
   `p = N(0,σ²)`, `q = N(Δ,σ²)`, and `gaussianRDPBound_measure` **derives**
   `D_α = α·Δ²/(2σ²)` unconditionally (only `σ ≠ 0`, `α ≠ 1`).
   The hypothesis bundle `GaussianRDPHypotheses` is removed — nothing is assumed —
   and the existence witness `Theorem2RDP.gaussianRDPBound` is superseded.

   **The `(ε, δ)`-DP conversion is now closed too** — see matrix row 39 and
   `Refinement/GaussianApproxDP.lean`: `gaussianRDPValue_eq_divergence`
   identifies the conversion's input with the proved divergence
   (`gaussianRDPBound_measure`), and `gaussian_approxDP_bound` brackets the
   converted `ε(δ) = ε_RDP + log(1/δ)/9` by an explicit two-sided rational
   interval at the production order `α = 10` (via `Refinement.rdpToApproxDP_bound`).
   **Not closed by any of this:** the general **correlated** multivariate
   mechanism, **adaptive** composition, and an *exact* measure-theoretic
   `(ε, δ)` theorem (Hölder + change of measure on an infinite base measure) —
   the row-39 bracket is a rational sandwich around a noncomputable logarithm,
   not an equality. *Independent* (product-measure) composition is closed
   separately — see matrix row 35 and
   `LeanFormalization/RenyiDivergenceCompose.lean`, which tensorizes
   `RenyiDivergenceMeasure` over a product measure and composes the Gaussian
   bound across two rounds. Row 2's own status is unaffected.
- `Aggregator.ProcessRound` **does** verify a real `WeightProof` against the
  caller's `WeightStatement` when one is supplied (`internal/batch/aggregator.go`,
  `internal/zkweight_circuit.go`), and falls back to the single-scalar
  `DataCommitmentCircuit` path. **Update (2026-11-20, #370):**
  `zkprover.ProduceWeightProof` is now the production producer — it runs any
  `Prover`, returns the `(encoded proof, WeightStatement)` pair the aggregator
  consumes, and self-verifies before returning. `cmd/simulate` uses it.
  **Update (2026-11-21):** `internal/computeproof.Trace` — whose commitment fields
  duplicated `WeightStatement`, which had no production caller, and whose verifier
  was a SHA-256 challenge-response with no circuit behind it — was **removed**.
  `docs/ZK_FINALIZATION_PLAN.md` M2 Gap 1 is closed by deletion, not by an
  invented caller. `WeightStatement` is the single wired path.
- **The Ed25519 field arithmetic is now bridged to `ZMod p`**
  (`LeanFormalization/Ed25519FieldBridge.lean`, matrix row 38). `fadd`, `fsub`,
  `fmul` — the `Nat`-valued operations the curve arithmetic uses — are proved
  to be the operations of `ZMod (2^255 - 19)`, with the ring laws
  (`fadd_comm`/`assoc`, `fmul_comm`/`assoc`, `fmul_add`, `add_mul`, `*_mod`)
  derived in `ZMod p` and transported back. `fPow` is proved correct by a
  generic fold invariant: `fPow a e = (a ^ e) % p` for `e < 2 ^ 256`. **This is
  the field layer of the group-law work**: after it, the assumption is that the
  *group law on the curve* holds, not the field arithmetic beneath it.
  **All five field operations are bridged**, including `fInv`:
  `card_units_zmod` proves `Fintype.card (ZMod p)ˣ = p - 1` for prime `p`
  (from `Fintype.card_units` + `ZMod.card`), `zmod_pow_sub_one` derives
  `a ^ (p-1) = 1` via Lagrange, and `fmul_fInv` gives `fInv a * a = 1` for
  `a` not divisible by `p`. Negative controls `fPowState_exp_ge` (the
  `e < 2 ^ 256` bound) and `fmul_fInv_zero` (`a = 0` gives `0`, not `1`).
  What remains open is the **curve group law**, not the field layer.
- **The Gaussian RDP bound is now extended to a diagonal multivariate
  covariance** (`LeanFormalization/RenyiDivergenceMultivariate.lean`, matrix row
  37): `gaussianRDPMeasure_diagonal` proves
  `D_α(∏ᵢ N(Δᵢ,σᵢ²) ‖ ∏ᵢ N(0,σᵢ²)) = ∑ᵢ α·Δᵢ²/(2σᵢ²)` for any finite index
  type, by `n`-variable Fubini (`integral_fintype_prod_volume_eq_prod`) plus the
  already-proved scalar integral. **The covariance is diagonal** — independent
  coordinates. A general positive-definite `Σ` still needs a multivariate
  density. The affine change-of-variables layer (the `det` factor) **is** in
  Mathlib — `Real.map_matrix_volume_pi_eq_smul_volume_pi`
  (`Mathlib/MeasureTheory/Measure/Lebesgue/Basic.lean:411`) and
  `MeasureTheory.Measure.map_linearMap_addHaar_eq_smul_addHaar`
  (`.../Lebesgue/EqHaar.lean:234`), verified 2026-11-23; an earlier revision of
  this bullet called it the obstruction, which was stale. The correlated case is not
  implied. The negative control `gaussianDensity_zero_sigma` shows `σ ≠ 0` is
  load-bearing (at `σ = 0` the density integrates to `0`, not `1`).
- **The bounded-query programmed random oracle is now formalized**
  (`LeanFormalization/RenyiDivergenceBoundedRO.lean`, matrix row 36):
  `roForkProb_ge` proves `roForkProb qH Q ≥ (roAcceptProb qH Q)²`, which is
  **stronger** than the classical forking loss `ε² − ε/N` (`N` the
  challenge-space size, as in rows 31-32), because in this abstraction each
  agreeing-pair count is at least `ε²·|Tape|`. The model is a
  **fixed-schedule (non-adaptive)** query schedule. A machine-checked negative
  control shows the rewind direction is load-bearing: with `qH = 3`, `|C| = 2`
  and `Q = {000, 011, 101}` the naive “agree everywhere except `j`” model gives
  `φ = 0 < ε² = 9/64`. Adaptive query histories are modelled in row 41
  (`RenyiDivergenceAdaptiveRO.lean`), where the bound is shown to be unchanged;
  the classical loss itself is still not recovered.
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
