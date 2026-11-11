# Lean Axiom Audit & Removal Plan

**Date:** 2026-11-11
**Scope:** `proofs/` — `LeanFormalization/`, `Specification/`, `Refinement/`, `TraceValidator/`, `quarantined/`
**Toolchain:** Lean 4.30.0-rc2 + Mathlib v4.30.0-rc2 (the exact pins in `proofs/lean-toolchain` / `proofs/lakefile.lean`)
**Status:** Audit complete and machine-verified. **All phases executed and
merged** (2026-11-11): Phase 0 dead-axiom deletion and Phase 2
`native_decide` replacement (#313), Phase 1 the last `sorry` (#315), Phase 3
`FloatOrderLaws` (#316), Phase 4 `dlL_prime` demotion (#318). The Lean
development is now **axiom-free and sorry-free**, with two explicit hypotheses
(`FloatOrderLaws`, `Fact (Nat.Prime dlL)`) and no `native_decide`.

---

## 0. Method (reproducible)

The audit is not a read-only source scan. It was produced with the real pinned
toolchain on this host:

```bash
# 1. Install the exact toolchain (elan)
elan-init.exe -y --no-modify-path --default-toolchain leanprover/lean4:v4.30.0-rc2

# 2. Build the three declared lean_lib targets
cd proofs && lake build LeanFormalization Specification Refinement
#    -> Build completed successfully (8362 jobs).
#    -> CI's own warning confirms the single sorry:
#       warning: LeanFormalization/SupermartingaleConvergence.lean:69:8:
#         declaration uses `sorry`

# 3. Enumerate every declaration and print its axiom set
#    (script in §5.1) -> 510 declarations, 328 axiom-bearing,
#    19 depending on something beyond Mathlib's foundation.

# 4. Run the repo's own gate
python3 scripts/ci/check_no_unsafe_placeholders.py
#    -> Placeholder scan passed: no `admit`, no un-allowlisted `axiom`
#       (13 allowlisted). sorry placeholders detected: 1 (allowed, tracked only)
```

All numbers below come from that run, not from reading the source.

---

## 1. Executive summary

| Trust item | Count | Removable now? |
|---|---|---|
| `axiom` declarations | **12** | 3 dead (delete), 8 Float (scope decision), 1 hard |
| `sorry` placeholders | **1** | **Yes** — Mathlib has every required lemma |
| `native_decide`-generated axioms | **7** | **6 yes** (trivial), 1 hard |
| **Total** | **20** | **10 removable with modest effort** |

The three headline findings:

1. **Three axioms are dead** — `ForkingLemma`, `ed25519_uf_cma_from_dlp`,
   `mimc_collision_resistant` have **zero dependents** in the entire proof tree.
   They can be deleted outright; nothing is lost.
2. **The one `sorry` is closable.** Mathlib v4.30.0-rc2 already contains the
   a.e. martingale convergence theorem, a one-step supermartingale constructor,
   and the a.e.-finiteness lemma the proof needs. This is a real proof, not a
   new assumption.
3. **The eight `Float` order axioms are irreducible in Lean.** Lean core defines
   `Float` as an opaque structure over an opaque `floatSpec` constant whose
   model type is `Unit`; `Float.le`, `Float.lt`, `Float.isNaN`, and
   `Float.toBits` are all `@[extern] … opaque`. **No order property of `Float`
   is provable.** Removing these axioms requires a scope decision (§4.3), not a
   proof.

Separately, the public documentation **overstates** the result. See §4.5.

---

## 2. Complete audit results

### 2.1 The 12 `axiom` declarations

| # | Axiom | File:line | Dependents | Status |
|---|---|---|---|---|
| 1 | `dlL_prime` | `DiscreteLogReduction.lean:12` | **4** | load-bearing |
| 2 | `ForkingLemma` | `DiscreteLogReduction.lean:120` | **0** | **dead — delete** |
| 3 | `ed25519_uf_cma_from_dlp` | `DiscreteLogReduction.lean:129` | **0** | **dead — delete** |
| 4 | `mimc_collision_resistant` | `Theorem5Cryptography.lean:223` | **0** | **dead — delete** |
| 5 | `float_le_refl` | `MultiKrum.lean:134` | 2 | load-bearing |
| 6 | `float_le_of_lt` | `MultiKrum.lean:135` | 2 | load-bearing |
| 7 | `float_not_lt_iff_le` | `MultiKrum.lean:136` | 2 | load-bearing |
| 8 | `float_not_le_iff_lt` | `MultiKrum.lean:137` | 2 | load-bearing |
| 9 | `float_le_antisymm` | `MultiKrum.lean:138` | 2 | load-bearing |
| 10 | `float_lt_of_lt_of_le` | `MultiKrum.lean:139` | 2 | load-bearing |
| 11 | `float_le_of_le_of_le` | `MultiKrum.lean:141` | 2 | load-bearing |
| 12 | `float_lt_irrefl` | `MultiKrum.lean:143` | 2 | load-bearing |

### 2.2 Dependency map (machine-checked, `#print axioms`)

**`dlL_prime`** → `scalarModInv`, `recoverSecret`, `recovery_yields_secret`,
`recovery_sanity_example`.
Needed because `recovery_yields_secret` works in `ZMod dlL`, and `ZMod p` is a
field only when `p` is prime (`ZMod.instField` needs `Fact (Nat.Prime p)`).

**`Refinement.float_*` (8)** → four theorems:
`IsMinIdx_unique`, `argminAux_spec`, `minFoldPair_spec`,
`multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl`,
`multiKrumSelectManyImpl_one_selects_argmin`.

**`sorryAx`** → `LeanFormalization.supermartingale_convergence_ae` only.

**`native_decide` axioms** (`*.\_native.native_decide.ax_1_1`) → 7 declarations:

| Declaration | File:line | `native_decide` replaceable? |
|---|---|---|
| `theorem2_example_profile` | `Theorem2RDP.lean:109` | **yes** — `norm_num [composeEps]` |
| `theorem2_budget_guard` | `Theorem2RDP.lean:114` | **yes** — `norm_num [composeEps]` |
| `theorem5_ops_guard` | `Theorem5Cryptography.lean:136` | **yes** — `simp [verifyOps]` |
| `theorem5_cost_guard` | `Theorem5Cryptography.lean:140` | **yes** — `simp [verifyCostMicros, verifyOps]` |
| `theorem7_scale_bound` | `Theorem7PQCMigrationContinuity.lean:135` | **yes** — `unfold global_scale; norm_num` |
| `theorem8_scale_non_hijack_guard` | `Theorem8DualSignatureNonHijack.lean:155` | **yes** — `simp [hijackSafe]` |
| `chernoffBoundZ_deployment_scale_tiny` | `Theorem1BFT.lean:579` | **no** — see §4.4 |

All six "yes" rows were **verified by compiling the replacement** on this host
(see §5.2). `theorem7_scale_guard` and
`chernoff_hierarchical_bound_deployment_scale` inherit the fix transitively.

### 2.3 The `sorry`

```
proofs/LeanFormalization/SupermartingaleConvergence.lean:81
  theorem supermartingale_convergence_ae … := by sorry
```

Introduced in PR #286 ("complete L1 supermartingale convergence proof"), which
closed the L1 theorem (`supermartingale_convergence_L1`) but left the almost-sure
strengthening open. It has **no dependents** — nothing else in the repo relies
on it. Closing it is therefore safe and self-contained.

---

## 3. What each remaining axiom actually is

### 3.1 `dlL_prime` — a 253-bit primality fact

`dlL = 7237005577332262213973186563042994240857116359379907606001950938285454250989`
(the Ed25519 subgroup order, `2^252 + 27742317777372353535851937790883648493`).

Measured on this host:

- `by decide` → **`maximum recursion depth has been reached`** (Lean's
  `Nat.Prime` decidability is effectively trial division).
- `by native_decide` → **still running after 120 s** (timed out; it compiles
  the same trial division to native code — ~2^126 iterations).

So this is a genuine number-theory task: a 253-bit primality proof in Lean.
Options are in §4.4.

### 3.2 The eight `Float` axioms — an opaque type

Lean core (`Init/Data/Float.lean`):

```lean
structure FloatSpec where
  float : Type
  val   : float
  lt    : float → float → Prop
  le    : float → float → Prop
  decLt : DecidableRel lt
  decLe : DecidableRel le

opaque floatSpec : FloatSpec := { float := Unit, val := (), lt := fun _ _ => True, … }

structure Float where
  val : floatSpec.float            -- i.e. an opaque wrapper around Unit

def Float.lt : Float → Float → Prop := fun a b => floatSpec.lt a.val b.val
def Float.le : Float → Float → Prop := fun a b => floatSpec.le a.val b.val

@[extern "lean_float_to_bits"]  opaque Float.toBits : Float → UInt64
@[extern "lean_float_isnan"]   opaque Float.isNaN : Float → Bool
```

Verified on this host:

- `LinearOrder Float`, `PartialOrder Float`, `Preorder Float` — **all fail to
  synthesize**, with Mathlib fully imported.
- `Float.le_refl`, `Float.le_antisymm`, `Float.le_trans`, `Float.lt_irrefl`,
  `Float.lt_of_lt_of_le`, `Float.le_of_lt`, `Float.not_lt`, `Float.not_le` —
  **none exist**.
- `Float.toBits_ofBits` / `Float.ofBits_toBits` — **do not exist**; `toBits`
  and `isNaN` are opaque, so even the bit representation is unprovable-from.

**Conclusion: the eight axioms are not provable.** They are a minimal, explicit
statement of a real fact about IEEE-754 `binary64` comparison on non-NaN
values. Any Lean formalization of `Float` ordering must assume exactly this;
the only way to avoid the assumption is to stop reasoning about `Float`'s order.

---

## 4. Removal plan

Ordered by value/effort. Phases 0–2 are unambiguous wins; phases 3–4 need a
scope decision.

### Phase 0 — Delete the three dead axioms (zero risk)

**Effort: minutes. Risk: none.** Nothing depends on them.

Delete from `proofs/LeanFormalization/DiscreteLogReduction.lean`:

```lean
-- lines 115-120
/-- NOTE (audit): `ForkingLemma` is an EXPLICIT, NAMED ASSUMPTION (axiom). … -/
axiom ForkingLemma : Prop

-- lines 122-132
/-- NOTE (audit): `ed25519_uf_cma_from_dlp` is an EXPLICIT, NAMED ASSUMPTION … -/
axiom ed25519_uf_cma_from_dlp :
    ∀ (s : Ed25519Sig) (oracle : SignOracle),
      DiscreteLogHard → ForkingLemma →
      pqcUnforgeable (Ed25519ToPQC s) oracle
```

Delete from `proofs/LeanFormalization/Theorem5Cryptography.lean`:

```lean
-- lines 214-223
/-- Collision resistance of MiMC: … -/
axiom mimc_collision_resistant : ∀ x y : Nat, mimc x = mimc y → x = y
```

Notes:
- `theorem5_mimc_binding`'s doc comment says "up to MiMC collision resistance",
  but its proof does **not** use the axiom — it concludes
  `p1.commitment = p2.commitment` by `rw [hc1, hc2]`. Correct the comment.
- `DiscreteLogHard` (`DiscreteLogReduction.lean:33`) becomes unused. It is a
  `def`, not an axiom; leave it or delete it, but note it in the PR.
- Remove the three entries from `ALLOWED_AXIOMS` in
  `scripts/ci/check_no_unsafe_placeholders.py`.
- Also remove the **spurious** `("LeanFormalization/Theorem5Cryptography.lean",
  "mimc")` allowlist entry: `mimc` is a `def`, never an `axiom`. The allowlist
  has 13 entries for 12 real axioms today.

**Result: 12 → 9 axioms.**

### Phase 1 — Close the `sorry`

**Effort: a day or two of focused proof work. Risk: low — the theorem has no
dependents, so a failed attempt changes nothing.**

The statement is the classical Robbins–Siegmund a.s. convergence theorem. The
proof decomposes into four pieces, every one of which Mathlib v4.30.0-rc2
already provides:

**Step 1 — the transform is a supermartingale.**
Let `M n = V n + ∑_{k<n} a k * V k - ∑_{k<n} b k`. Then

```
E[M (n+1) | F n] = E[V (n+1) | F n] + ∑_{k≤n} a k * V k - ∑_{k≤n} b k
                 ≤ (1 - a n) * V n + b n + ∑_{k<n} a k * V k + a n * V n
                   - ∑_{k<n} b k - b n
                 = M n
```

Discharged by `MeasureTheory.supermartingale_nat`:

```lean
theorem supermartingale_nat [IsFiniteMeasure μ] {f : ℕ → Ω → E}
    (hadp : StronglyAdapted 𝒢 f) (hint : ∀ i, Integrable (f i) μ)
    (hf : ∀ i, μ[f (i + 1) | 𝒢 i] ≤ᵐ[μ] f i) : Supermartingale f 𝒢 μ
```

(`Mathlib/Probability/Martingale/Basic.lean:416` — a one-step constructor, so
no need to iterate the tower property by hand.)

**Step 2 — L¹ boundedness, needed by the convergence theorem.**
`E[M n] ≤ E[M 0] = E[V 0]` by the supermartingale property, and
`M n ≥ -∑' k, b k` from `V ≥ 0`, `a k ≥ 0`, `Finset.sum_le_tsum`. Hence
`E[|M n|] ≤ E[V 0] + 2 * ∑' k, b k < ∞`.

**Step 3 — a.e. convergence of `M`.**
`-M` is a submartingale with the same L¹ bound, so
`MeasureTheory.Submartingale.ae_tendsto_limitProcess`
(`Mathlib/Probability/Martingale/Convergence.lean:209`) gives
`∀ᵐ ω, Tendsto (fun n => M n ω) atTop (𝓝 (…))`.

**Step 4 — the limit is 0.**
From the defining inequality,
`a n * V n ≤ V n - E[V (n+1) | F n] + b n`; summing and taking expectations:

```
∑' n, a n * E[V n] ≤ E[V 0] + ∑' n, b n < ∞
```

so `∑' n, a n * V n < ∞` a.e. — via `MeasureTheory.ae_lt_top`
(`∫⁻ f ≠ ⊤ → ∀ᵐ x, f x < ⊤`) applied to the nonnegative function
`∑' n, a n * V n`, whose integral is `∑' n, a n * E[V n]` by
`MeasureTheory.lintegral_iSup` (monotone convergence).

If `V n ω → L(ω)` with `L(ω) > 0` on a non-null set, then `V n ω ≥ L(ω)/2`
eventually there, and `∑ a n * V n = ∞` because `∑ a n = ∞` and `a n ≥ 0` —
contradiction. Since `M n` converges a.e. and `∑ b` and `∑ a n * V n` both
converge a.e., `V n` converges a.e. to 0.

**Result: 1 `sorry` → 0.**

### Phase 2 — Replace the six trivial `native_decide`s

**Effort: minutes each. Risk: none — all six were compiled successfully with
the replacement on this host.**

| File:line | Replacement |
|---|---|
| `Theorem2RDP.lean:109` | `norm_num [composeEps]` |
| `Theorem2RDP.lean:114` | `norm_num [composeEps]` |
| `Theorem5Cryptography.lean:136` | `simp [verifyOps]` |
| `Theorem5Cryptography.lean:140` | `simp [verifyCostMicros, verifyOps]` |
| `Theorem7PQCMigrationContinuity.lean:135` | `unfold global_scale; norm_num` |
| `Theorem8DualSignatureNonHijack.lean:155` | `simp [hijackSafe]` (keeping the local `global_scale` fact) |

**Result: 7 `native_decide` axioms → 1.**

> **Trust note.** `native_decide` does not prove the goal; it asserts
> `Lean.ofReduceBool`, i.e. that the native compiler's evaluator agrees with the
> kernel's. That is a *different* trust (the compiler) and it is **not** in the
> CI allowlist, because `check_no_unsafe_placeholders.py` only greps for
> `axiom` declarations. Whatever survives this phase should be recorded as a
> toolchain trust, not as a mathematical axiom.

### Phase 3 — The eight `Float` axioms (scope decision required)

> **Status: DONE (Option B, `fix/lean-float-order-laws`).** The eight `axiom`
> declarations are deleted. The laws are packaged as the `FloatOrderLaws`
> structure in `proofs/Refinement/MultiKrum.lean` and passed explicitly to
> `IsMinIdx_unique`, `argminAux_spec`, `minFoldPair_spec`, `argmin?_isMinIdx`,
> `multiKrumSelectManyImpl_one_selects_argmin`, and
> `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl`. `#print axioms` on
> those theorems now reports only Mathlib's foundation; the CI allowlist drops
> from 13 entries to 1 (`dlL_prime`).
>
> Full genericization over `[LinearOrder α]` was tried and rejected: Lean's
> `Float.le` is `floatSpec.le a.val b.val` with `floatSpec` opaque, so a
> generic `[LinearOrder α]` development does **not** transport to the concrete
> `Float` definitions definitionally (verified: `argminAuxG (α := Float) =
> argminAuxF` is not provable by `rfl`). Packaging the laws into one explicit
> structure is the honest achievable form of Option B.

**Effort: not a proof problem — see §3.2.** Three honest options:

**Option A — keep them (recommended if the goal is minimal, honest change).**
They are true, minimal, explicit, non-NaN-scoped, and CI-allowlisted. Lean
*cannot* do better: `Float` is opaque by design because IEEE-754 comparison is
not a total order once NaN is admitted. Document them as the repo already does,
and move on. This is the same trust every Lean program that orders floats
carries.

**Option B — genericize (recommended if the goal is literally zero axioms).**
Restate the four affected theorems over an abstract `[LinearOrder α]` and prove
them with the ordinary lemmas (`le_refl`, `le_antisymm`, `le_trans`, `lt_irrefl`,
`lt_of_lt_of_le`, `le_of_lt`, `not_lt.mp`, `not_le.mp`). The proofs are the same
algebra; only the type changes. The `Float` versions then become conditional:

```lean
/-- The Float instantiation is conditional: Lean provides no `LinearOrder Float`,
    because `Float.le` is opaque. This is the single place the IEEE-754
    comparison assumption survives. -/
example [LinearOrder Float] : <Float statement> := generic_statement
```

This **removes eight axioms** and replaces them with one clearly-labelled
instance requirement. It does not make the algorithm *less* correct; it makes
the assumption *explicit and singular* instead of eight scattered axioms.

**Option C — re-specify over `ℚ` or `ℝ` (strongest, weakest Go link).**
Define the score type as `ℚ` (or `ℝ`) so Mathlib's order applies with no
assumption at all. Cost: the spec no longer mirrors Go's `float64`, so the
`multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl` equivalence becomes a
statement about a rational model, not about `float64`. Only choose this if the
Go correspondence is not the point of the file.

**Do not** attempt to "prove" the eight axioms from `Float.toBits` — `toBits`
and `isNaN` are `opaque`, and the roundtrip lemmas do not exist. That route
dead-ends.

### Phase 4 — `dlL_prime` (hard; two real options)

> **Status: DONE (Option B, `fix/lean-dlL-prime-hypothesis`).** The `axiom
> dlL_prime : Nat.Prime dlL` and the global `instance : Fact (Nat.Prime dlL)`
> are deleted. The primality of the Ed25519 subgroup order is now the explicit
> `Fact (Nat.Prime dlL)` hypothesis on the four declarations that need it:
> `scalarModInv`, `recoverSecret`, `recovery_yields_secret`,
> `recovery_sanity_example`. `dlVerify`, `dlAdversarySucceeds`, and
> `DiscreteLogHard` do not need it and remain unconditional. `#print axioms`
> on all four now reports only Mathlib's foundation; the CI allowlist is empty
> and the Lean development has **zero** `axiom` declarations.

**Effort: high for a full machine-checked proof; low for the honest alternative.**

**Option A — prove it.** Requires a 253-bit primality certificate in Lean.
Mathlib has no ECPP/Pocklington machinery for this size, and both `decide` and
`native_decide` are computationally infeasible (measured, §3.1). Realistic only
as a dedicated number-theory project.

**Option B — demote it to a hypothesis (recommended).** `dlL_prime` is used only
to make `ZMod dlL` a field. Move it out of the global axiom set and into the
statements that need it:

```lean
theorem recovery_yields_secret (r a h1 h2 S1 S2 : Nat)
    (hp : Fact (Nat.Prime dlL))          -- was: the global axiom
    (hS1 : …) (hS2 : …) (hdiff : …) : …
```

This does not reduce the *total* trust — primality is still assumed — but it
removes a global axiom from the proof tree, makes the assumption **local and
visible at each use site**, and lets the four dependent declarations carry their
own assumptions instead of inheriting a hidden one. Combined with a comment
citing RFC 8032 / the standard Ed25519 reference for the primality of `L`, this
is the honest, low-risk choice.

**Option C — keep as an axiom.** Also defensible: primality of the Ed25519
subgroup order is an external, checkable fact, and the axiom is already
documented and allowlisted.

---

## 4.5 Documentation corrections (the audit found real drift)

The machine-checked reality contradicts several public claims. These should be
fixed regardless of which removal options are chosen.

| File | Claim | Reality |
|---|---|---|
| `BLOG_POST_FORMAL_PROOFS.md:7,24` | "52 Lean 4 theorems, **zero axioms**"; "All 52 proofs have **zero axioms** (no sorry/admit/axiom placeholders)" | **False.** 12 axioms + 1 sorry, machine-verified. The repo has 264 theorems/lemmas and 510 declarations. |
| `docs/EXTERNAL_AUDIT_SCOPE.md:87` | "Axioms present in the proof tree (**16 total**, all documented)" | **12**, not 16. |
| `docs/EXTERNAL_AUDIT_SCOPE.md:57` | references `proofs/Refinement/MiMC.lean` | **File does not exist.** The MiMC refinement is `proofs/Refinement/ZKCircuit.lean`; `Theorem5MiMCFormalization.lean` holds the round function. |
| `CHANGELOG.md:61`, `ROADMAP.md:129` | "the **eight** remaining axioms … in `Refinement/MultiKrum.lean`" | **12** axioms across three files; eight are Float, four are cryptographic. |
| `CHANGELOG.md:59` | "Zero `sorry` remain across `proofs/LeanFormalization`, `proofs/Specification`, and `proofs/Refinement`" | **One** `sorry` remains (`supermartingale_convergence_ae`). |
| `scripts/ci/check_no_unsafe_placeholders.py` | 13 allowlist entries | 12 real axioms; the `mimc` entry is a `def`. |

---

## 5. Verification protocol

### 5.1 The audit script

Save as `proofs/axioms_audit.lean` (or run ad hoc):

```lean
import LeanFormalization
import Specification
import Refinement

open Lean Elab Command

def declsIn (ns : Name) : CommandElabM (List Name) := do
  let env ← getEnv
  let mut out : List Name := []
  for (n, _) in env.constants.toList do
    if n.getPrefix == ns && !n.isInternal then out := out ++ [n]
  return out.toArray.qsort (· < ·)

elab "audit " ns:ident : command => do
  for d ← declsIn ns.getId do
    logInfo m!"{d}"
```

```bash
cd proofs
lake build LeanFormalization Specification Refinement
lake env lean axioms_audit.lean          # list every declaration
# then, per declaration:
#   lake env lean --run /dev/stdin <<< '#print axioms <name>'
```

`#print axioms` is the authoritative check: it reports the full transitive
axiom set, including `sorryAx` and `native_decide`'s generated axiom.

### 5.2 Per-phase acceptance criteria

| Phase | Gate | Pass condition |
|---|---|---|
| 0 | `lake build` + `check_no_unsafe_placeholders.py` | build green; 0 axioms deleted, allowlist updated |
| 1 | `lake build` | **no `declaration uses sorry` warning**; `supermartingale_convergence_ae` has `#print axioms` = `[propext, Classical.choice, Quot.sound]` |
| 2 | `lake build` | the six theorems compile without `native_decide`; `#print axioms` shows no `._native.native_decide.ax_1_1` |
| 3 | `lake build` | 0 `Refinement.float_*` axioms; generic theorems compile |
| 4 | `lake build` | 0 `dlL_prime` axiom (Option B/C) or a real primality proof (Option A) |

Final gate, all phases:

```bash
cd proofs && lake build LeanFormalization Specification Refinement
grep -rn '\bsorry\b\|\badmit\b' --include='*.lean' LeanFormalization Refinement Specification *.lean
grep -rn '^\s*axiom\s' --include='*.lean' LeanFormalization Refinement Specification *.lean
python3 scripts/ci/check_no_unsafe_placeholders.py
```

### 5.3 Suggested PR sequence

1. **PR-1 (Phase 0 + 2):** delete 3 dead axioms, drop 6 `native_decide`s, fix
   allowlist + the `mimc_collision_resistant` comment. Pure deletion — easy
   review, immediately reduces 19 trust items to 10.
2. **PR-2 (Phase 1):** close the `sorry`. Self-contained, no dependents.
3. **PR-3 (Phase 3):** Float decision (Option A/B/C). Needs the scope decision.
4. **PR-4 (Phase 4):** `dlL_prime` decision.
5. **PR-5:** documentation corrections (§4.5) — can ride along with any of the
   above, but should not be dropped.

---

## 6. Bottom line

> **Update after execution: all four phases are DONE. The Lean development now
> has zero `axiom` declarations and zero `sorry`s.** `#print axioms` over all
> 272 theorems and lemmas reports only Mathlib's foundation (`propext`,
> `Classical.choice`, `Quot.sound`). The two remaining assumptions are
> explicit hypotheses, not axioms — `FloatOrderLaws` in the Multi-Krum
> refinement, and `Fact (Nat.Prime dlL)` in the discrete-log reduction.

Original assessment, for the record:

- **10 of 20 trust items are removable with modest, low-risk work** (3 dead
  axioms, 6 `native_decide`s, 1 `sorry`). — *Done in #313 and #315.*
- **9 are irreducible without a scope decision**: 8 `Float` order axioms (Lean
  cannot see `Float`'s order) and 1 253-bit primality axiom. — *Resolved in
  #316 and #318 by packaging each as an explicit hypothesis rather than an
  axiom; neither assumption was provable, both are now visible at every use
  site instead of being global.*
- **The `sorry` is real work but very doable** — Mathlib has
  `supermartingale_nat`, `Submartingale.ae_tendsto_limitProcess`,
  `MeasureTheory.ae_lt_top`, and `lintegral_iSup`, which is exactly the toolkit
  the proof needs. — *Done in #315.*
- **The public docs overstate the result.** "Zero axioms" was not true when
  this plan was written and could not be made true without either dropping the
  `Float` ordering reasoning or accepting a documented IEEE-754 assumption.
  That correction was part of the job — and the honest end state turned out to
  be stronger than the original options suggested: both assumptions are now
  local hypotheses, so "zero axioms" is literally true.
