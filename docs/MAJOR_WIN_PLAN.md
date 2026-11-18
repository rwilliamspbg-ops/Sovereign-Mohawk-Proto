# Major-Win Plan — from honest scoping to external credibility

Status: **W2 + W3 + W4 implemented 2026-11-18** (W1, W5–W7 open). Scope: the five
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

### W1 — Refresh the audit package, then recruit (suggestion 1) · ~1 week
- [ ] Update `docs/EXTERNAL_AUDIT_SCOPE.md` §3.3: replace the
      `DataCommitmentCircuit`-centric item with the weight circuit —
      `internal/zkweight_circuit.go`, `proofs/Refinement/ZKCircuit.lean`,
      `Theorem5Cryptography.lean` (`WeightUpdateCircuit` section).
- [ ] Update §6 "Known limitations": the two bullets claiming per-round
      commitments are unpopulated and that only `dataCommitmentVK` is
      circuit-derived are now superseded; restate them accurately (the
      aggregator verifies `WeightProof`, but `computeproof.Trace` still has no
      production producer).
- [ ] Add a **"review in under 30 minutes"** subsection: the one-command rebuild
      (`cd proofs && lake build`), the `#print axioms` audit, and the three
      artifacts a reviewer should read first.
- [ ] Add the weight circuit to `AUDITOR_QUICK_REFERENCE.md`.
- [ ] Recruitment: an `audit-help-wanted` issue template and a short outreach
      message; credit policy already documented (`AUDITS.md`).
- [ ] Deliverable: a public audit report (or arXiv note) that either confirms the
      claims under the stated scopes or enumerates the remaining gaps.

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
- [ ] Populate `computeproof.Trace` at a real producer. **Blocker found earlier:**
      no production caller constructs `computeproof.Trace` at all, and there is no
      `GradientUpdate{` construction site — so this needs a design decision
      (populate `Trace`, or delete it and wire `WeightStatement` directly).
- [ ] Produce a `WeightProof` next to a real update and verify it in
      `internal/batch` inside a chaos test (30% Byzantine) and a scale test.
- [ ] Expose proof-verification counts in metrics (`metrics.ObserveFedAvg*`).

### W5 — Paper update (suggestion 3) · ~1 week
- [ ] New §7.x: `WeightUpdateCircuit` — statement, what is bound, measured cost
      (verify 0.67 ms, prove 34 ms, 9569 constraints, 164 B proof,
      `results/zk/weight-proof-latest.json`), and the explicit surrogate-hash
      caveat.
- [ ] Promote the claim-status / model-vs-runtime methodology to a first-class
      section (it is currently scattered across the traceability matrix and
      `EXTERNAL_AUDIT_SCOPE.md` §2/§6).
- [ ] Regenerate `docs/ACADEMIC_PAPER.pdf`.

### W6 — One-script evidence package (suggestion 4) · ~1 week
- [ ] `scripts/run_evidence_package.sh`: Kind deploy → scale matrix → a round that
      produces and verifies a `WeightProof` → RDP accounting → formal bundle.
- [ ] Commit the raw metrics + `results/zk/*.json` + the formal validation bundle
      together, with exact commands and configs in the repo.
- [ ] Gate: the script fails if any stage's artifact is missing.

### W7 — Correspondence tightening (suggestion 5) · ~1 week
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
