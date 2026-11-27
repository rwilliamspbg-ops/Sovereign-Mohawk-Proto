import Mathlib
import LeanFormalization.Ed25519CurveGroupLaw

/-!
# `affineScalarMulImpl`: base cases and produced-point invariants

`Ed25519CurveGroupLaw.lean` proves identity, commutativity and canonical
preservation for `affineAdd`, and records **associativity** as the open law that
blocks the four group laws consumed by `Ed25519VerificationEquation.lean`.
`docs/MAJOR_WIN_PLAN.md` calls the curve group law "the multi-week item".

This module does not attempt associativity (see the residual-gap section below).
It targets the other half of the brief's Ed25519 item — *"full group-law proofs
for the currently unaudited affine implementations"* — by auditing the
double-and-add loop directly.

## What is proved

* `affineAdd_consistent` — `affineAdd` maps consistent inputs to a consistent
  output. This discharges an explicit `IsConsistent` hypothesis at every future
  use site rather than assuming it.
* `smulStep` / `smulFold` — the loop body factored out, and
  `affineScalarMulImpl_eq_smulFold` identifying the implementation with the
  fold. Everything below is then proved about the fold.
* `affineScalarMulImpl_zero` — `0 · P = affineIdentity`. This is `zeroMul`,
  which `Ed25519VerificationEquation.lean` used to *assume* before #361 removed
  it for having no dependents; here it is **derived**.
* `affineScalarMulImpl_one` — `1 · P = P` for consistent `P`. Likewise a former
  assumption (`oneMul`), now proved.
* `affineScalarMulImpl_consistent` / `affineScalarMulImpl_canonical` — every
  point the loop produces satisfies both invariants, so downstream group-law
  theorems need no extra hypotheses about its outputs.

## Residual gap (stated openly)

**Associativity of `affineAdd` is NOT proved.** It needs the completeness of the
unified twisted-Edwards formula: the denominators `1 ± d·x1·x2·y1·y2` must be
non-zero for on-curve points, which is a statement about the curve equation
(and ultimately about `d` being a non-square mod `p`) rather than a case bash.
Neither the closure identity nor the associativity identity falls to `ring`,
`field_simp` or `linear_combination` on the current Mathlib, so this is recorded
as a gap, not worked around.
-/

namespace LeanFormalization

/-! ### `affineAdd` preserves consistency -/

/-- `affineAdd` never manufactures a false infinity: if both inputs are
    consistent, so is the result. The exceptional branch returns
    `affineIdentity`; the formula branch sets `inf := false`. -/
theorem affineAdd_consistent {P Q : AffinePoint} (hP : IsConsistent P) (hQ : IsConsistent Q) :
    IsConsistent (affineAdd P Q) := by
  unfold IsConsistent
  cases hPi : P.inf with
  | true => simp only [affineAdd, hPi, if_true]; exact hQ
  | false =>
      cases hQi : Q.inf with
      | true => simp only [affineAdd, hPi, if_false, hQi, if_true]; exact hP
      | false =>
          have hPi' : ¬ P.inf := by rw [hPi]; simp
          have hQi' : ¬ Q.inf := by rw [hQi]; simp
          cases hb : IsNegation P Q with
          | true =>
              have h : affineAdd P Q = affineIdentity := by
                simp only [affineAdd, hPi, hQi]
                simp only [IsNegation] at hb ⊢
                rw [hb]
                rfl
              rw [h]
              exact Or.inr rfl
          | false =>
              have h : affineAdd P Q = affineAddFormula P.x P.y Q.x Q.y :=
                affineAdd_eq_formula P Q hPi' hQi' hb
              rw [h]
              exact Or.inl rfl

/-! ### The scalar-multiplication loop, factored out -/

/-- One MSB-first double-and-add step: double the accumulator, conditionally add
    `P`. Exactly the body of the `foldl` in `affineScalarMulImpl`. -/
def smulStep (bit : Nat) (r P : AffinePoint) : AffinePoint :=
  let r2 := affineAdd r r
  if bit == 1 then affineAdd r2 P else r2

/-- The first `n` steps of `affineScalarMulImpl`'s loop, i.e. processing bits
    `n-1 … 0`. `affineScalarMulImpl` is `smulFold k P 256`. -/
noncomputable def smulFold (k : Nat) (P : AffinePoint) (n : Nat) : AffinePoint :=
  (List.range n).reverse.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) affineIdentity

/-- The implementation *is* this fold; nothing has changed definitionally. -/
theorem affineScalarMulImpl_eq_smulFold (k : Nat) (P : AffinePoint) :
    affineScalarMulImpl k P = smulFold k P 256 := rfl

/-- A zero bit is a no-op when the accumulator is the identity: doubling
    `affineIdentity` gives `affineIdentity` back, and no addition happens. -/
theorem smulStep_zero_identity (P : AffinePoint) :
    smulStep 0 affineIdentity P = affineIdentity := by
  unfold smulStep
  have hb : ((0 : Nat) == 1) = false := by decide
  rw [hb]
  simp
  exact affineAdd_identity_left affineIdentity (Or.inr rfl)

/-- A `1` bit applied to the identity accumulator yields `P` exactly. This is
    unconditional: `affineAdd affineIdentity P = P` holds by the implementation's
    first branch, so no `IsConsistent` hypothesis is needed. It is the step-level
    counterpart of the already-derived `oneMul` law. -/
lemma smulStep_one_identity (P : AffinePoint) :
    smulStep 1 affineIdentity P = P := by
  unfold smulStep
  have hb : ((1 : Nat) == 1) = true := by decide
  rw [if_pos hb]
  change affineAdd (affineAdd affineIdentity affineIdentity) P = P
  rw [show affineAdd affineIdentity affineIdentity = affineIdentity by rfl]
  rfl

/-- Folding a run of zero-valued bits starting from the identity leaves the
    identity unchanged. -/
theorem foldl_zero_bits_eq_identity {l : List Nat} {f : Nat → Nat} {P : AffinePoint}
    (hl : ∀ b ∈ l, f b = 0) :
    l.foldl (fun r b => smulStep (f b) r P) affineIdentity = affineIdentity := by
  induction l with
  | nil => rfl
  | cons a l ih =>
      rw [List.foldl_cons]
      have ha : f a = 0 := hl a (by simp)
      rw [show smulStep (f a) affineIdentity P = affineIdentity by
        rw [ha]; exact smulStep_zero_identity P]
      exact ih (fun b hb => hl b (by simp [hb]))

/-- **`0 · P = affineIdentity`** — the `zeroMul` law, derived rather than
    assumed. -/
theorem affineScalarMulImpl_zero (P : AffinePoint) :
    affineScalarMulImpl 0 P = affineIdentity := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  exact foldl_zero_bits_eq_identity (fun b _ => by simp)

/-- Splitting off the most significant index of the loop range:
    `(range (n+1)).reverse = [n] ++ (range n).reverse`. -/
theorem smulFold_range_succ (k : Nat) (P : AffinePoint) (n : Nat) :
    smulFold k P (n + 1) =
      (List.range n).reverse.foldl
        (fun r i => smulStep ((k >>> i) &&& 1) r P)
        (smulStep ((k >>> n) &&& 1) affineIdentity P) := by
  unfold smulFold
  rw [List.range_succ, List.reverse_append, List.reverse_singleton,
    List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- Appending one more index does not change the fold when that index's bit is
    `0`, because the leading step then preserves the identity. -/
theorem smulFold_bitZero (k : Nat) (P : AffinePoint) {n : Nat} (hk : k < 2 ^ n) :
    smulFold k P (n + 1) = smulFold k P n := by
  rw [smulFold_range_succ]
  have hbit : (k >>> n) &&& 1 = 0 := by
    rw [Nat.shiftRight_eq_div_pow]
    have hd : k / 2 ^ n = 0 := Nat.div_eq_of_lt hk
    rw [hd]
    norm_num
  rw [show smulStep ((k >>> n) &&& 1) affineIdentity P = affineIdentity by
    rw [hbit]; exact smulStep_zero_identity P]
  rw [smulFold]

/-- If `k < 2^m`, then processing any number of higher zero bits is a no-op:
    the fold over `n` indices equals the fold over `m` indices. -/
theorem smulFold_stable_below (k : Nat) (P : AffinePoint) :
    ∀ {m n : Nat}, m ≤ n → k < 2 ^ m → smulFold k P n = smulFold k P m := by
  intro m n hmn hk
  induction n generalizing m with
  | zero =>
      have hm0 : m = 0 := Nat.le_zero.mp hmn
      subst hm0
      rfl
  | succ n ih =>
      rcases Nat.lt_or_eq_of_le hmn with hlt | heq
      · have hle : m ≤ n := Nat.le_of_lt_succ hlt
        have hk' : k < 2 ^ n :=
          lt_of_lt_of_le hk (Nat.pow_le_pow_right (by norm_num) hle)
        rw [smulFold_bitZero k P hk']
        exact ih hle hk
      · subst heq
        rfl

/-- **`1 · P = P`** for a consistent `P` — the `oneMul` law, derived rather than
    assumed. The high 255 bits of `1` are all zero, so the loop stays at the
    identity until the final bit. -/
theorem affineScalarMulImpl_one (P : AffinePoint) (hc : IsConsistent P) :
    affineScalarMulImpl 1 P = P := by
  rw [affineScalarMulImpl_eq_smulFold]
  have hstable : smulFold 1 P 256 = smulFold 1 P 1 :=
    smulFold_stable_below 1 P (by norm_num) (by norm_num : (1 : Nat) < 2 ^ 1)
  rw [hstable, smulFold, List.range_one, List.reverse_singleton,
    List.foldl_cons, List.foldl_nil]
  have hb : ((1 >>> (0 : Nat)) &&& 1) = 1 := by decide
  rw [hb]
  unfold smulStep
  have hb' : ((1 : Nat) == 1) = true := by decide
  rw [hb']
  simp
  rw [show affineAdd affineIdentity affineIdentity = affineIdentity from
    affineAdd_identity_left affineIdentity (Or.inr rfl)]
  exact affineAdd_identity_left P hc

/-! ### Invariants preserved by the loop -/

/-- One step preserves consistency. -/
theorem smulStep_consistent {b : Nat} {r P : AffinePoint}
    (hr : IsConsistent r) (hP : IsConsistent P) : IsConsistent (smulStep b r P) := by
  unfold smulStep
  by_cases hb : b == 1
  · rw [if_pos hb]
    exact affineAdd_consistent (affineAdd_consistent hr hr) hP
  · rw [if_neg hb]
    exact affineAdd_consistent hr hr

/-- Consistency is preserved along a fold of steps. -/
theorem foldl_smulStep_consistent (l : List Nat) (k : Nat) (P : AffinePoint)
    (hP : IsConsistent P) :
    ∀ r, IsConsistent r →
      IsConsistent (l.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) r) := by
  induction l with
  | nil => intro r hr; simpa using hr
  | cons a l ih =>
      intro r hr
      rw [List.foldl_cons]
      exact ih (smulStep ((k >>> a) &&& 1) r P) (smulStep_consistent hr hP)

/-- Every point produced by `affineScalarMulImpl` is consistent — the loop can
    never manufacture a false infinity. -/
theorem affineScalarMulImpl_consistent (k : Nat) (P : AffinePoint) (hP : IsConsistent P) :
    IsConsistent (affineScalarMulImpl k P) := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  exact foldl_smulStep_consistent (List.range 256).reverse k P hP affineIdentity (Or.inr rfl)

/-- One step preserves reduced coordinates. -/
theorem smulStep_canonical {b : Nat} {r P : AffinePoint}
    (hr : IsCanonical r) (hP : IsCanonical P) : IsCanonical (smulStep b r P) := by
  unfold smulStep
  by_cases hb : b == 1
  · rw [if_pos hb]
    exact affineAdd_canonical (affineAdd r r) P (affineAdd_canonical r r hr hr) hP
  · rw [if_neg hb]
    exact affineAdd_canonical r r hr hr

/-- Reduced coordinates are preserved along a fold of steps. -/
theorem foldl_smulStep_canonical (l : List Nat) (k : Nat) (P : AffinePoint)
    (hP : IsCanonical P) :
    ∀ r, IsCanonical r →
      IsCanonical (l.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) r) := by
  induction l with
  | nil => intro r hr; simpa using hr
  | cons a l ih =>
      intro r hr
      rw [List.foldl_cons]
      exact ih (smulStep ((k >>> a) &&& 1) r P) (smulStep_canonical hr hP)

/-- Every point produced by `affineScalarMulImpl` has reduced coordinates. -/
theorem affineScalarMulImpl_canonical (k : Nat) (P : AffinePoint) (hP : IsCanonical P) :
    IsCanonical (affineScalarMulImpl k P) := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  have hinit : IsCanonical (affineIdentity : AffinePoint) := by
    unfold IsCanonical affineIdentity
    exact ⟨ed25519P_pos, by unfold ed25519P; norm_num⟩
  exact foldl_smulStep_canonical (List.range 256).reverse k P hP affineIdentity hinit

end LeanFormalization
