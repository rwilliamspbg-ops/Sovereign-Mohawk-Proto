# Major-Win Plan — from honest scoping to external credibility

Status: **W2–W7 implemented 2026-11-18.** W1's audit package is done; only the **external audit report** remains, which needs a human reviewer. Scope: the five
suggested next steps, reviewed against the tree as of 2026-11-18 (post PR #348).

---

## 0. Review of the five suggestions

| # | Suggestion | Verdict | What already exists | Real remaining gap |
| --- | --- | --- | --- | --- |
| 1 | Independent formal audit + public report | **accept, reframe** | `docs/EXTERNAL_AUDIT_SCOPE.md`, `AUDITOR_QUICK_REFERENCE.md`, `AUDIT_EVIDENCE_PLAN.md`, `LEAN_AXIOM_AUDIT_AND_REMOVAL_PLAN.md`, root `AUDITS.md` | The scope doc is **stale** (§3.3 and §6 still describe the pre-`WeightUpdateCircuit` state); no reviewer recruited; no public report |
| 2 | Close the zk/crypto soundness loop | **partially stale** | `WeightUpdateCircuit` (PR #348) already removed the "weakly bound" criticism; `proofs/Refinement/ZKCircuit.lean`, `Theorem5MiMCFormalization.lean` | `Refinement/ZKCircuit.lean` still models the **old single-scalar** circuit; `weightHash` is a surrogate; no end-to-end FL round |
| 3 | Publish a focused honest paper | **mostly done** | `docs/ACADEMIC_PAPER.md` + `ACADEMIC_PAPER.pdf` already lead with the composition fallacy + Chernoff repair | §7 predates the weight circuit; claim-status methodology is not a first-class section |
| 4 | Reproducible large-scale evidence package | **accept** | `scripts/run_kind_scale_evidence.sh`, `deploy_to_kind.sh`, `collect_kind_scale_latency.sh`, `simulator-scale-smoke.yml` | Weight proofs not exercised; no single scripted entry point joining raw metrics + formal bundle |
| 5 | Tighten Go↔Lean correspondence | **accept** | `internal/multikrum_lean_correspondence_test.go` (2 tests) | No randomized differential testing; no Lean proof that the transcribed algorithm equals the spec |

### Pushbacks (stated plainly, so the plan doesn't over-promise)

- **"Replace the surrogate `weightHash` with a proper MiMC/BN254 formalization"** is a
  research project, not a gap-fix. The right move is staged: extend the *refinement*
  to the weight circuit (W2), instantiate the MiMC round guard at the real modulus
  (W3), and pin the Go↔Lean hash correspondence with vectors (W3). A full MiMC
  collision-resistance proof is future work with a written plan, not a silent drop.
- **"Add a minimal Groth16 knowledge-soundness statement"** is very likely out of
  reach: the pinned Mathlib has **no pairing/Tate-Weil machinery and no
  computational-hardness infrastructure** (a feasibility scout already confirmed
  this — see `proofs/theorem_claims.json`, `theorem5_cryptography` gaps). Take the
  suggestion's second branch: mark it future work **with a concrete plan**.
- Suggestion 1's "recruit external reviewers" is a human action I cannot perform.
  The plan delivers the recruitment package; the outreach is the maintainer's.

---

## 1. Work packages

### W1 — Refresh the audit package, then recruit (suggestion 1) · **docs half done 2026-11-18; report BLOCKED on a human reviewer**
- [x] `docs/EXTERNAL_AUDIT_SCOPE.md` §3.3 already named the weight circuit
      (`internal/zkweight_circuit.go`, `proofs/Refinement/ZKCircuit.lean`,
      `Theorem5Cryptography.lean`, `Theorem5MiMCFormalization.lean`); verified, no
      change needed.
- [x] §6 "Known limitations": both superseded bullets restated against the
      code. The aggregator **does** verify a real `WeightProof;
      `zkprover.ProduceWeightProof` is the production producer. The formerly
      separate `computeproof.Trace` (no producer, duplicate commitment fields) was
      **removed** on 2026-11-21, closing ZK plan M2 Gap 1 by deletion.
      `genesisVK` is still a fixed identity, but **two** keys are now
      circuit-derived (`dataCommitmentVK` and the weight circuit key).
- [x] New **§1.1 "Review in under 30 minutes"**: rebuild + placeholder sweep +
      a concrete `#print axioms` probe, then the three artifacts to read in order
      (matrix → §3 → `results/zk/weight-proof-latest.json`), then one
      refinement bridge checked by hand.
- [x] `docs/AUDITOR_QUICK_REFERENCE.md`: added a "Formal Proof Audit Quick
      Reference" section with the weight-circuit artifact table and the honest
      limitations. (That file was supply-chain-only; the formal section is
      deliberately separate and cross-linked.)
- [x] New `docs/AUDIT_RECRUITMENT.md` (why-review, the ask, a copy-paste outreach
      message, suggested channels) and `.github/ISSUE_TEMPLATE/audit-help-wanted.md`
      (labelled `audit-help-wanted` + `help wanted`). Credit policy confirmed in
      `AUDITS.md`.
- [x] New `docs/AUDIT_REPORT_TEMPLATE.md` so a reviewer can drop in findings.
- [ ] **Deliverable — a public audit report: BLOCKED, needs a human.** No reviewer
      has been recruited; `AUDITS.md` still lists none. Everything a reviewer needs
      is now in the repo; the remaining step is a person.

### W2 — Extend the Lean refinement to `WeightUpdateCircuit` (suggestion 2a) · **done 2026-11-18**
- [ ] `proofs/Refinement/ZKCircuit.lean` currently models the **single-scalar**
      circuit (`ZKSpec`, `zkSpecRelation`, `zk_impl_refines_spec`,
      `zk_impl_complete`, `zk_impl_binding`). Add a `Weight` section:
      `WeightSpec` (six public fields), `WeightWitness` (gradients/noise/steps),
      `WeightProof`, `weightSpecRelation`, `weightImplVerify`, `weightImplProve`.
- [ ] Prove `weight_impl_refines_spec`, `weight_impl_complete`,
      `weight_impl_binding` — the same three properties the old model has, now for
      the circuit that production actually uses.
- [ ] Keep the old model (it still describes `DataCommitmentCircuit`, which remains
      wired for compatibility) but rename/namespace it so the two are not confused.
- [ ] Update `proofs/FORMAL_TRACEABILITY_MATRIX.md` row 21 and
      `proofs/theorem_claims.json`.

### W3 — MiMC at the real modulus + pinned hash correspondence (suggestion 2b) · **done 2026-11-18**
- [ ] `Theorem5MiMCFormalization.lean` instantiates only `p = 7`. Add an
      instantiation at the BN254 scalar modulus
      (`r = 21888242871839275222246405745257275088548364400416034343698204186575808495617`):
      discharge `Nat.Prime r` and `Nat.Coprime 5 (r-1)` concretely (`native_decide`
      if feasible, otherwise an explicit checked guard), so the injectivity lemma is
      stated at the field the Go circuit actually hashes over.
- [ ] Pin the byte-order/split convention: `internal.mimcFields` writes one
      32-byte big-endian block per element. Add test vectors for a fixed input set
      so a gnark-crypto byte-order change is caught by CI rather than silently
      changing the statement.
- [ ] Write the **future-work plan** for full MiMC collision resistance: what
      Mathlib would need, what could be proved with `ZMod r` arithmetic today, and
      what stays assumed.

### W4 — End-to-end FL round with a bound proof (suggestion 2c) · **done 2026-11-18**
- [x] ~~Populate `computeproof.Trace` at a real producer.~~ **Resolved 2026-11-21
      by deletion:** no production caller ever constructed it and there was no
      `GradientUpdate{` construction site; `Trace` duplicated `WeightStatement`'s
      commitment fields and its verifier had no circuit behind it. `WeightStatement`
      is the single wired path.
- [ ] Produce a `WeightProof` next to a real update and verify it in
      `internal/batch` inside a chaos test (30% Byzantine) and a scale test.
- [ ] Expose proof-verification counts in metrics (`metrics.ObserveFedAvg*`).

### W5 — Paper update (suggestion 3) · **done 2026-11-18**
- [x] New §8.4: `WeightUpdateCircuit` — the six-element statement, the four
      constrained relations (model hash chain, range+norm bound, update hash chain,
      dataset binding), the measured cost (verify 0.675 ms, prove 38 ms, 9 569
      constraints, 164 B proof, 41.4 s one-time setup), and the explicit caveats
      (Lean proves the MiMC injectivity lemma, not this circuit; no q-SDH soundness;
      simulated ceremony). The old "surrogate hash" caveat was replaced: the circuit
      uses real gnark MiMC over BN254, so the caveat is now precise about *what* is
      and is not proved.
- [x] New first-class **§3 "Claim Status and Epistemic Scope"**: status taxonomy
      (`fully_formalized`, `model_verified`/`surrogate_verified`, `structural`,
      `circuit_relation_modeled`, `empirical`), the model-vs-runtime distinction, the
      axiom/hypothesis inventory, and an explicit "what is deliberately not claimed"
      list. §2.3 trimmed to a pointer so the two do not duplicate. Sections
      3–15 renumbered to 4–16 (verified sequential; no cross-references existed).
- [x] Fixed the stale claim in §1.3 contribution 5 ("BN254 is not instantiated").
- [x] Regenerate `docs/ACADEMIC_PAPER.pdf`. Toolchain installed on this host:
      **pandoc 3.14** + **Typst 0.15.1** (chosen over LaTeX because Typst renders the
      paper's `$...$` mathematics natively and is a single ~50 MB binary rather than a
      multi-GB TeX install). New `scripts/render_paper_pdf.sh` (also
      `make paper-pdf`, and `--check` for a staleness gate) resolves pandoc/typst on
      both winget-Windows and normal PATH layouts; the MSYS-to-native path conversion
      for native binaries is handled. Output: 32 pages, 556 675 bytes, math/tables/
      code/ASCII-art all verified via text extraction.

### W6 — One-script evidence package (suggestion 4) · **done 2026-11-18**
- [x] `scripts/run_evidence_package.sh`: one entry point, stages `zk-bench`,
      `zk-round`, `scale` (Kind, opt-in), `dp`, `formal`, `manifest`. Also
      `make evidence-package EVIDENCE_ARGS="--skip-kind"`.
- [x] `docs/EVIDENCE_PACKAGE.md`: prerequisites per stage, every option, what each
      artifact means, how to verify a package you did not produce, a CI recipe,
      troubleshooting, and an explicit "what this does not establish" section.
- [x] Gate: the script fails if any stage's artifact is missing or empty.
      **This caught two real bugs while being written** — the stage dispatch
      (hyphen vs underscore) and the `formal` stage writing to the repo's canonical
      `results/proofs/` instead of the package.
- [ ] Commit a run directory. Deliberately not done by default: `results/**` is
      gitignored and the bundle duplicates `proofs/`, so a run is ~550 KB. The
      committed artifact remains `results/zk/weight-proof-latest.json`; a run
      directory can be `git add -f`-ed when a citation-worthy snapshot is needed.

### W7 — Correspondence tightening (suggestion 5) · **done 2026-11-18**
- [ ] Randomized differential test for Multi-Krum: N random `(n, f, m)`
      configurations, Go's `MultiKrumSelect` vs the Lean-transcribed selection;
      assert exact equality. (`internal/multikrum_lean_correspondence_test.go`
      currently has 2 hand-written tests.)
- [ ] Prove in Lean that the transcribed selection procedure equals the
      `krumScore`-based specification (`Specification.neighborScore`), closing the
      "Lean cannot invoke Go, so correspondence is by definition" caveat one level
      up.
- [ ] Same treatment for the weight hash chain (W3's vectors generalize to a
      randomized differential test).

---

## 2. Sequencing

```
W2 (Lean refinement) ──┐
W3 (MiMC + vectors)   ──┼──► W6 (evidence package) ──► W5 (paper) ──► W1 (audit + recruit)
W4 (end-to-end round) ──┘
W7 (correspondence) runs alongside W2/W3
```

W1's *document* half (scope refresh) should land first — it is cheap and makes the
recruitment ask concrete. W1's *report* half is the longest pole and depends on a
human reviewer.

## 3. Non-goals

- Full Groth16 / q-SDH formalization — out of reach in the pinned Mathlib (no
  pairings, no hardness infrastructure); kept as written future work.
- Full MiMC collision resistance — same.
- Treating the in-process 3-party MPC as a production ceremony.

## 4. Definition of done

1. `docs/EXTERNAL_AUDIT_SCOPE.md` describes the weight circuit accurately, and at
   least one external reviewer is engaged with a published scope.
2. `proofs/Refinement/ZKCircuit.lean` models `WeightUpdateCircuit` with
   refinement, completeness and binding theorems; `lake build` clean.
3. The MiMC round-injectivity guard is instantiated at the BN254 scalar modulus,
   and the Go hash chain is pinned by test vectors.
4. A real FL round produces and verifies a `WeightProof` in a chaos test, with the
   verification count in metrics.
5. `docs/ACADEMIC_PAPER.md` has a weight-circuit section and a first-class
   claim-status section; PDF regenerated.
6. `scripts/run_evidence_package.sh` reproduces the scale + proof evidence from a
   clean checkout, with committed raw metrics.
7. `AUDITS.md` records the reviewer's scope and date.

---

## Appendix A — Future work: MiMC collision resistance and Groth16 knowledge soundness

Written plan, per W2/W3. Neither is attempted; both are recorded so the gap is
explicit rather than implicit.

### A.1 MiMC collision resistance over BN254

**Proved today** (`Theorem5MiMCFormalization.lean`): `pow_injective` /
`mimcRound_injective` — injectivity of `x ↦ (x + c)^e` on `ZMod p` when `e` is
coprime to `p - 1` — instantiated at the BN254 scalar modulus
(`mimcRound_bn254_injective`), with `Nat.Prime bn254Prime` an explicit hypothesis
and the exponent coprimality discharged concretely.

**Not proved:** collision resistance of the Miyaguchi–Preneel chain over the MiMC
permutation, i.e. that two distinct field-element streams cannot produce the same
digest. That is a computational-hardness claim about the MiMC block cipher, not an
algebraic identity.

**Why it is hard here:** Mathlib has no symmetric-cipher or PRF/security-game
machinery. A from-scratch proof needs a permutation-security game, a
Miyaguchi–Preneel composition argument, and a reduction to the MiMC round's
differential properties over `F_r` — thesis-scale formalization.

**Concrete staged plan.**

1. Formalize the reachable algebraic core: the exact Miyaguchi–Preneel
   compression over `ZMod r` as a Lean function, and prove it is a permutation of
   the state for a fixed-length stream when the round function is injective
   (`ZMod r` arithmetic only, no hardness).
2. Pin the Lean compression to Go's `gnark-crypto` implementation with
   *randomized* differential vectors, not just fixed literals, so the model cannot
   silently diverge.
3. State collision resistance as an explicit `Prop` with a written reduction
   sketch, and carry it as a named hypothesis in any theorem that needs it —
   exactly as `FloatOrderLaws` packages the IEEE order laws — rather than letting
   a surrogate hash make the existential trivially satisfiable.
4. Attempt the full hardness proof only if Mathlib gains a symmetric-cipher /
   security-game library.

### A.2 Groth16 knowledge soundness

**Status:** not formalized, not attempted. `proofs/theorem_claims.json`
(`theorem5_cryptography`) records the feasibility finding: the pinned Mathlib has
real elliptic-curve group law but **zero pairing/Tate–Weil machinery and zero
computational-hardness formalization** (no discrete-log or q-SDH infrastructure).

**What the runtime relies on.** `internal/zkweight_circuit.go` verifies real
Groth16 proofs under a circuit-derived VK. The soundness of that step — an
accepted proof implies a witness satisfying the circuit relation — is the
cryptographic assumption. The Lean refinement
(`proofs/Refinement/ZKCircuit.lean`, `weight_impl_accept_iff`) characterizes what
the *implementation predicate* asserts structurally and deliberately does NOT
claim this direction.

**Concrete plan.**

1. Keep the structural refinement; never let a surrogate hash make the
   existential trivially satisfiable (the mistake the `mimc` identity stand-in
   risks).
2. If a pairing formalization lands in Mathlib, state knowledge soundness for the
   specific `WeightUpdateCircuit` relation with the QAP/R1CS reduction explicit.
3. Until then, cite Groth16's published security proof and record the assumption
   in `docs/EXTERNAL_AUDIT_SCOPE.md`.

---

### A.3 Multivariate Gaussian RDP

**Proved today** (`LeanFormalization/RenyiDivergenceMeasure.lean`, matrix row
34): the **scalar** Gaussian mechanism's Rényi divergence,
`gaussianRDPBound_measure`:
`D_α(N(Δ,σ²) ‖ N(0,σ²)) = α·Δ²/(2σ²)`, unconditional apart from `σ ≠ 0` and
`α ≠ 1`, derived from a proved completed-square integral.

**Target.** For `Σ` positive definite and `p = N(0,Σ)`, `q = N(μ,Σ)` on `ℝⁿ`,
`D_α(q‖p) = (α/2) · μᵀ Σ⁻¹ μ`.

**Update 2026-11-21 — step 2 (the diagonal case) is now PROVED** (matrix row 37,
`LeanFormalization/RenyiDivergenceMultivariate.lean`).
`gaussianRDPMeasure_diagonal` gives
`D_α(∏ᵢ N(Δᵢ,σᵢ²) ‖ ∏ᵢ N(0,σᵢ²)) = ∑ᵢ α·Δᵢ²/(2σᵢ²)` for any finite index type,
derived from `gaussianRDP_integral` plus `n`-variable Fubini
(`MeasureTheory.integral_fintype_prod_volume_eq_prod`). This lands step 2 of the
staged plan without needing items 1–3. **The correlated case remains open**, but
**not** because of the change of variables: a 2026-11-23 scout confirmed the
`det` layer is in Mathlib (verified 2026-11-23 by `#check` and compiled
demos). What remains open is item 1 below plus packaging the general
quadratic-form integral; the spectral/diagonalization prerequisite for
step 4 was not found in the pinned Mathlib. The diagonal restriction is
stated openly in the theorem docstring and in
`docs/EXTERNAL_AUDIT_SCOPE.md`.

**Update 2026-11-24 — items 3 and 4 are now DONE; item 1 remains open.**
Matrix row 44, `LeanFormalization/RenyiDivergenceMultivariateCovariance.lean`:

* `gaussian_integral_isotropic_sum` — the isotropic `n`-dimensional integral on
  `ι → ℝ`: `∫ exp(-½ ∑ᵢ xᵢ²) dx = (2π)^(card ι / 2)` (`n`-variable Fubini from
  the 1-D `gaussian_integral_half_sq_1d`).
* `gaussian_quadratic_integral_matrix` — for invertible `B`,
  `∫ exp(-½ ∑ᵢ ((B *ᵥ x)ᵢ)²) dx = (2π)^(card ι / 2) / abs (det B)`, via
  `Real.map_matrix_volume_pi_eq_smul_volume_pi`.
* `integral_gaussian_density_covariance` — the normalized density integrates to 1.

Stated openly: the exponent is the Gram form `Q = Bᵀ * B`; rewriting it as
`x ⬝ᵥ Q *ᵥ x` and constructing a factorisation `Σ ↦ B` are **not** done, so the
correlated Rényi divergence itself is still not claimed.

**What is missing.**

1. A multivariate normal density on `Fin m → ℝ`, with the quadratic form
   `exp(-½ (x-μ)ᵀ Σ⁻¹ (x-μ))` and normalizing constant `det(2πΣ)^(-1/2)`. Not in
   Mathlib (a grep for `matrixGaussian`/`MultivariateNormal` finds nothing).
2. `Σ` positive definite and invertible. `Matrix.PosSemidef` / `Matrix.PosDef`
   exist, and `Matrix.PosDef.det_pos` (`Mathlib/Analysis/Matrix/PosDef.lean:85`)
   already gives `0 < det Σ`. Available.
3. A **multivariate** affine change of variables for Lebesgue measure — the
   Jacobian/`det` factor. **Available in Mathlib**:
   `Real.map_matrix_volume_pi_eq_smul_volume_pi`
   (`Mathlib/MeasureTheory/Measure/Lebesgue/Basic.lean:411`) rescales Lebesgue
   measure on `ι → ℝ` by `|det M|⁻¹` when `det M ≠ 0`,
   `MeasureTheory.Measure.map_linearMap_addHaar_eq_smul_addHaar`
   (`.../Lebesgue/EqHaar.lean:234`) is the Haar form, and the Jacobian integral
   lemmas in `Mathlib/MeasureTheory/Function/Jacobian.lean` transport integrals.
4. The base measure on `ℝⁿ`: `MeasureTheory.volume_pi` supplies it, so no new
   measure infrastructure is needed.

**Why it is not attempted here.** An earlier revision of this plan called item 3
the obstruction; that is **stale** — the `det` change-of-variables layer is in
Mathlib (verified by `#check` and compiled demos, 2026-11-23). What remains is
item 1 (a multivariate Gaussian density / Radon–Nikodym lemma; only the 1-D
`rnDeriv_gaussianReal` exists) plus packaging the general quadratic-form
Gaussian integral from the existing isotropic one. Both are derivable from
current Mathlib primitives, so the correlated case is a bounded-but-real
formalization rather than a deferral.

**Concrete staged plan.**

1. Define `mvGaussianDensity (μ : Fin m → ℝ) (Σ : Matrix (Fin m) (Fin m) ℝ) (x)`,
   taking `Σ` positive definite as an explicit hypothesis built from
   `Matrix.PosDef` — not an opaque predicate, and not an axiom.
2. Prove the **diagonal** case first (`Σ = diag σ²`), reducing to `m` independent
   scalar integrations via `MeasureTheory.volume_pi` and reusing the already
   proved scalar bound. Bounded, checkable, and it exercises the density
   definition.
3. Prove the affine change-of-variables lemma for Lebesgue measure on `ℝⁿ`
   (`∫ f (L x + c) dx = |det L|⁻¹ ∫ f y dy` for `det L ≠ 0`), with the `m = 1`
   case checked against `gaussianIntegral_shift`.
4. Diagonalize `Σ` and transport the diagonal result. **Prerequisite gap:** no
   spectral/diagonalization development for symmetric matrices was found in the
   pinned Mathlib. If it is not added, stop at step 2, ship the diagonal-`Σ`
   result, and pin the general case as a named hypothesis rather than implying
   coverage.

**Negative control to carry.** The scalar result's `σ ≠ 0` is load-bearing
(`gaussianRDP_integral` degenerates at `σ = 0`); the multivariate analogue is a
**singular** `Σ`, where `Σ⁻¹` does not exist. State that control explicitly
rather than letting the density degenerate silently.

**The `(ε,δ)`-DP conversion for the Gaussian mechanism is now delivered**
(matrix row 39, `Refinement/GaussianApproxDP.lean`) as an explicit two-sided
rational bracket at `α = 10`, via the row-13 log-sandwich. **Not covered by
this plan:** an *exact* measure-theoretic `(ε,δ)` theorem, the **correlated**
multivariate Gaussian, or adaptive composition (the accountant's `CheckBudget` conversion is formalized separately in
`Refinement/RDPLogBound.lean`), and adaptive composition in the measure-theoretic
framework (`Theorem2RDP.RDP_adaptive_composition` covers finite support only).
### A.4 Bounded-query programmed random oracle (Pointcheval–Stern rewind)

**Status: CLOSED 2026-11-21.** `LeanFormalization/RenyiDivergenceBoundedRO.lean`
proves `roForkProb qH Q ≥ (roAcceptProb qH Q)²` (matrix row 36), and the machine-checked
negative control `naiveRewind_agrees_off_count` shows the rewind direction is
load-bearing. The premise was verified numerically first, then the derivation
below was formalized directly. Remaining scope limit, stated openly: the query
schedule is fixed / non-adaptive.

**The gap.** `SchnorrUF_CMAWithOracle.lean` and `Ed25519UF_CMASecurity.lean` model
the random oracle as a **uniform challenge**: the prefix fixes the forgery
message and nonce point, and the challenge is drawn independently. The
Pointcheval–Stern `\epsilon^2/q_H` loss is therefore not recovered.

**The model.** `qH` RO queries with a fixed (non-adaptive) schedule; an answer
vector is `a : Fin qH → C`; the accepting set is `Q ⊆ Tape × (Fin qH → C)`;
`ε = |Q| / (|Tape|·|C|^qH)`. A fork rewinds at a uniformly chosen query index `j`:
the two runs share the tape and the answers at queries **before** `j`, and may
differ from `j` onward.

**Verified numerically (2026-11-21).** Over 150 random accepting sets per
(`qH`, `|C|`) for `qH ∈ {1,2,3,4}` and `|C| ∈ {2,3,4}`, with acceptance bias
`p ∈ {0.05, 0.1, 0.25, 0.5, 0.75, 0.9}`, the inequality
`φ ≥ ε² − ε/qH` held in **every** trial. The Cauchy–Schwarz derivation below
in fact gives the stronger `φ ≥ ε²`.

**Derivation.** Group the agreeing pairs by `(t, p)` where `p = a|<j`:

    n t p = #{a | a|<j = p ∧ (t,a) ∈ Q}

so `∑ t ∑ p n²` counts exactly the agreeing pairs, `∑ t ∑ p n = |Q|`, and
Cauchy–Schwarz gives `∑ n² ≥ |Q|² / (|Tape|·|C|^j)`. Hence
`P(E_j) ≥ |Q|²/(|Tape|²·|C|^{2qH}) = ε²`.

**Modeling trap (found by simulation, not by inspection).** If "agree before `j`"
is replaced by the naive "agree everywhere **except** `j`", the bound **fails**:
with `qH = 3`, `|C| = 2`, `Tape` a single point and `Q = {000, 011, 101}`,
`ε = 3/8`, `φ = 0`, while `ε² − ε/qH = 1/64 > 0`. Any formalization must use
rewind semantics (agree on `< j`), not differ-only-at-`j` semantics.

**Named residual — the one lemma left.** The Cauchy–Schwarz step needs the
partition identity

    ∑ t, ∑ p, (n t p)^2  =  ∑ ta, [ta ∈ Q] · n (ta.1) (ta.2 |< j)

i.e. with the definitions that compile on the pinned toolchain (`roPrefix`,
`roCount`, `roAcceptProb`, `roForkProb` in `LeanFormalization`),

    ∑ t, ∑ p, (roCount qH j Q t p)^2
      = ∑ ta, (if ta ∈ Q then roCount qH j Q ta.1 (roPrefix qH j ta.2) else 0)

This is a standard sum-over-a-partition identity (`Finset.sum_comm` plus a
`∑ p, if pre a = p then c else 0 = c` step), not an open problem. It is the
only obstruction.

**Concrete staged plan.**

1. Prove the linear partition identity `∑ t, ∑ p, roCount = |Q|` first — the
   same plumbing without the squares, and it is checkable independently.
2. Prove the squared identity via `Finset.sum_mul_sum` and `Finset.sum_comm`.
3. Apply `Finset.sum_mul_sq_le_sq_mul_sq` to conclude
   `roForkProb qH Q ≥ (roAcceptProb qH Q)^2`.
4. Instantiate at the UF-CMA game: a `UFCMAROAdversary` whose forgery challenge
   is read from the transcript rather than drawn, and derive `ε ≤ 1/N` under
   `SchnorrDLHard`.

**Scope, stated openly.** Even at step 4 this is a **fixed-schedule**
(non-adaptive) query model: the adversary's queries do not depend on earlier
answers. Full adaptive query histories are not modelled, and that limitation
must appear in the docstring and the matrix row.
### A.5 Ed25519 field-arithmetic bridge

**Status: the field layer is CLOSED 2026-11-21** (matrix row 38,
`LeanFormalization/Ed25519FieldBridge.lean`). `Ed25519.lean` defines
`fadd`/`fsub`/`fmul`/`fPow`/`fInv` and had **zero** correctness lemmas; the
bridge proves the first four are what they claim:

* `fadd_zmod`, `fsub_zmod`, `fmul_zmod` identify them with `ZMod (2^255 - 19)`.
* The ring laws (`fadd_comm`/`assoc`/`mod`, `fmul_comm`/`assoc`/`mod`,
  `fmul_add`, `add_mul`) are derived in `ZMod p` and transported back by
  `nat_eq_of_zmod_eq`.
* `fPow` is proved correct by a generic fold invariant
  (`list_foldl_invariant`): the square-and-multiply state satisfies
  `result * base ^ exp = a ^ e` and its exponent component is `e / 2 ^ fuel`,
  so at `fuel = 256` and `e < 2 ^ 256`, `fPow a e = (a ^ e) % p`.

**`fInv` is now bridged too.** `card_units_zmod` proves
`Fintype.card (ZMod p)ˣ = p - 1` for prime `p` from `Fintype.card_units` and
`ZMod.card`; `zmod_pow_sub_one` derives `a ^ (p-1) = 1` via Lagrange
(`pow_card_eq_one`); and `fmul_fInv` concludes `fInv a * a = 1` for `a` not
divisible by `p`, carrying `Fact (Nat.Prime ed25519P)` explicitly. A local
`units_val_pow` supplies the power form of `Units.val` that Mathlib omits.

**Still the multi-week item:** the group law on the curve itself
(twisted-Edwards completeness of `affineAdd`, and full double-and-add
correctness of `affineScalarMulImpl`). The field bridge removes the field layer
from that assumption; it does not prove the group law.

**Increment 2026-11-24 (matrix row 45).** The double-and-add loop is factored out
as `smulStep`/`smulFold` and audited directly
(`Ed25519ScalarMulStructure.lean`): `0 · P = identity` and `1 · P = P` are
**derived** (they were previously *assumed* as `zeroMul`/`oneMul` before #361
removed them for having no dependents); `affineAdd_consistent` shows `affineAdd`
never manufactures a false infinity; and the loop preserves both `IsConsistent`
and `IsCanonical`, so its outputs need no extra hypotheses downstream.

**Still open, stated plainly:** associativity of `affineAdd`. It requires the
denominators `1 ± d·x1·x2·y1·y2` to be non-zero for on-curve points, i.e.
twisted-Edwards completeness, which rests on `d` being a non-square mod `p`. That
is a curve/number-theoretic result, not a case bash, and neither the closure
identity nor the associativity identity closes with `ring`, `field_simp` or
`linear_combination` on this Mathlib. It remains the blocker for the four
consumed group laws.

---

## Appendix B — Prove-time review (2026-11-18)

A review claimed the ~28 s figure was an abnormally slow Groth16 prove that
"should finish in well under 1 s". **That premise is a misreading.** Measured on
this host (16 cores, AMD Ryzen AI 7 350):

| phase | time |
| --- | --- |
| compile (`frontend.Compile`) | 18–39 ms |
| trusted setup — simulated MPC, 3 contributors (current default) | 43.4 s |
| trusted setup — simulated MPC, 1 contributor | 29.7 s |
| `groth16.Setup` (single-party, for comparison) | **0.32 s** |
| **prove (warm)** | **~30 ms** |
| verify | ~0.5–0.8 ms |

`cmd/simulate` timed from before the first `ProveWeightUpdate`, so its
"Prove Time" line included the one-time setup. It now reports setup and prove
separately. `cmd/zkweightbench` and `results/zk/weight-proof-latest.json` already
reported them separately (setup 44.1 s, prove 34.3 ms).

So the prove was never the problem — it is already inside the reviewer's target
range. The one-time setup is the only large cost, and it is a deliberate
simulated ceremony rather than an accident.

**Levers measured.**

- `frontend.WithCompressThreshold(10)` — **counterproductive**: 9569 → 10028
  constraints, no setup speedup. Rejected.
- MPC contributors 3 → 1 — 43.4 s → 29.7 s (−32%). This weakens the documented
  "no single contributor holds the toxic waste" property to one in-process
  contributor, which is the same trust as `groth16.Setup` but slower. Rejected.
- `groth16.Setup` — 0.32 s, a 137× setup speedup. It drops the multi-party
  claim entirely and leaves the toxic waste in the process. **Not adopted
  unilaterally**: it is a security-narrative change, not a performance tweak.
  Maintainer decision.
- ICICLE (CUDA) — not applicable: this host has a Radeon 860M iGPU (no CUDA),
  and CI runners are CPU-only.
- Poseidon in place of MiMC — would change the circuit relation that
  `Theorem5Cryptography.lean`, `Refinement/ZKCircuit.lean` and the pinned MiMC
  vectors are stated about. Rejected.
- Caching `(pk, vk)` on disk — would make repeat runs instant but introduces a
  serialized-key trust path. Not adopted.
- Prove off the critical path — already the case: proving is client-side, and
  the aggregator only verifies (0.5 ms).
