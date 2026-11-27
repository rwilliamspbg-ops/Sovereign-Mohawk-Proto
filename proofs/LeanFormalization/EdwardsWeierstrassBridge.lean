import Mathlib

/-
# Birational bridge: twisted Edwards -> Montgomery

The Ed25519 group law is the unified twisted-Edwards addition with `a = -1`:

    E_d : -x² + y² = 1 + d·x²·y².

`affineAdd` implements it (`LeanFormalization/Ed25519ScalarMulStructure.lean`), and its
**associativity** is the open law blocking the four group laws consumed by
`Ed25519VerificationEquation.lean`. This file is one step on the route to
that proof: Mathlib proves associativity for a cubic model
(`WeierstrassCurve.Affine.Point.instAddCommGroup`, transported through the class
group of the coordinate ring), so Edwards associativity has to be reached by a
birational change of variables followed by an addition-law compatibility argument.

## What is proved here

* `edwardsToMont_montgomery`: every point `(x, y)` of `E_d` with `y ≠ 1` maps into
  the Montgomery model `M_{A,B} : B·v² = u³ + A·u² + u`, where

      A = 2(1-d)/(1+d),   B = -1/(1+d),
      u = (1+y)/(1-y),    v = 2x(1+d·y²)/(1-y)².

  under the sole extra hypothesis `1 + d ≠ 0`. The lemma is conditional on the
  curve equation `edwardsEq d x y`; it is stated over an arbitrary `Field K` and is
  axiom-free.

* `montgomeryToEdwards_edwards`: the converse direction -- a Montgomery point
  `(u, v)` with `u + 1 ≠ 0` and `Q(u) ≠ 0` maps back onto `E_d`.

* The two **round-trip composites** are proved, so the maps are mutually inverse on
  their admissible loci: `edwardsToMont_roundtrip` (`montgomeryToEdwards` undoes
  `edwardsToMont`, needing `y ≠ 1`, `1 + d ≠ 0`, `1 + d·y² ≠ 0` and `2 ≠ 0`) and
  `montgomeryToEdwards_roundtrip` (`edwardsToMont` undoes `montgomeryToEdwards`,
  needing only `u + 1 ≠ 0`, `Q(u) ≠ 0` and `2 ≠ 0` -- it does not even use the
  curve equation). `2 ≠ 0` is characteristic-agnostic bookkeeping: in
  characteristic two `u = (1+y)/(1-y) = 1` identically, so there is nothing to
  recover.

## What is NOT proved here (stated openly)

* **Addition-law compatibility.** Nothing here shows that `affineAdd` corresponds to
  the Montgomery (or Weierstrass) addition under this map. Without that, no group
  law — not associativity — can be inherited. This is the next step.
* **Exceptional loci / denominator completeness.** Both directions state their
  non-vanishing hypotheses explicitly (`1 - y = 0`, `1 + d = 0`, `Q(u) = 0`). This
  is where the two maps are undefined; showing the implementation never divides
  by zero additionally needs `d` to be a non-square modulo `p`, which is
  number-theoretic and separate.
  hiding them.
-/

namespace LeanFormalization

noncomputable section

variable {K : Type*} [Field K]

/-- Coefficient `A = 2(1-d)/(1+d)` of the Montgomery model of `E_d`. -/
def montA (d : K) : K := 2 * (1 - d) / (1 + d)

/-- Coefficient `B = -1/(1+d)` of the Montgomery model of `E_d`. -/
def montB (d : K) : K := -(1 : K) / (1 + d)

/-- The Montgomery curve `M_{A,B} : B·v² = u³ + A·u² + u`. -/
def montgomeryEq (d : K) (u v : K) : Prop :=
  montB d * v ^ 2 = u ^ 3 + montA d * u ^ 2 + u

/-- The twisted-Edwards curve `E_d : -x² + y² = 1 + d·x²·y²`. -/
def edwardsEq (d : K) (x y : K) : Prop :=
  -x ^ 2 + y ^ 2 = 1 + d * x ^ 2 * y ^ 2

/-- **Edwards → Montgomery.** Send `(x,y)` to
    `(u, w) = ((1+y)/(1-y),  2x(1+d·y²)/(1-y)²)`.

    Equivalently `w = x·Q(u)/2` with `Q(u) = (1+d)u² + 2(1-d)u + (1+d)`, because
    `Q((1+y)/(1-y)) = 4(1+d·y²)/(1-y)²`. The scaled form is used because it keeps
    the proofs below to a single clearing of `1-y`. -/
def edwardsToMont (d x y : K) : K × K :=
  ((1 + y) / (1 - y), 2 * x * (1 + d * y ^ 2) / (1 - y) ^ 2)

@[simp]
lemma edwardsToMont_fst (d x y : K) :
    (edwardsToMont d x y).1 = (1 + y) / (1 - y) := rfl

@[simp]
lemma edwardsToMont_snd (d x y : K) :
    (edwardsToMont d x y).2 = 2 * x * (1 + d * y ^ 2) / (1 - y) ^ 2 := rfl

/-- The auxiliary quadratic `Q(u) = (1+d)u² + 2(1-d)u + (1+d)`. -/
def montQ (d u : K) : K := (1 + d) * u ^ 2 + 2 * (1 - d) * u + (1 + d)

/-- `Q(u)` is the completing-square form `(u+1)² + d(u-1)²`. -/
lemma montQ_completes_square (d u : K) :
    montQ d u = (u + 1) ^ 2 + d * (u - 1) ^ 2 := by
  unfold montQ
  ring

/-- **Montgomery → Edwards.** Inverse of `edwardsToMont` on the admissible locus:
    recover `y = (u-1)/(u+1)` and `x = 2v / Q(u)`. -/
def montgomeryToEdwards (d : K) (u v : K) : K × K :=
  ((2 * v) / montQ d u, (u - 1) / (u + 1))

@[simp]
lemma montgomeryToEdwards_fst (d u v : K) :
    (montgomeryToEdwards d u v).1 = 2 * v / montQ d u := rfl

@[simp]
lemma montgomeryToEdwards_snd (d u v : K) :
    (montgomeryToEdwards d u v).2 = (u - 1) / (u + 1) := rfl

/-- On-curve points satisfy `1 + d·y² ≠ 0`, given `y ≠ 1` and `d ≠ -1`.
    This is the hypothesis that makes both directions of the bridge total on the
    admissible locus. -/
lemma edwards_one_add_dy_ne_zero {d x y : K} (hE : edwardsEq d x y)
    (hy : 1 - y ≠ 0) (hd : 1 + d ≠ 0) : 1 + d * y ^ 2 ≠ 0 := by
  unfold edwardsEq at hE
  intro h0
  have hx0 : x ^ 2 * (1 + d * y ^ 2) = 0 := by rw [h0]; ring
  have hx0' : x ^ 2 + d * x ^ 2 * y ^ 2 = 0 := by
    calc x ^ 2 + d * x ^ 2 * y ^ 2 = x ^ 2 * (1 + d * y ^ 2) := by ring
      _ = 0 := hx0
  have hsum : (-x ^ 2 + y ^ 2) + (x ^ 2 + d * x ^ 2 * y ^ 2)
      = (1 + d * x ^ 2 * y ^ 2) + 0 := by rw [hE, hx0']
  have hy2 : y ^ 2 = 1 := by
    have h := hsum
    ring_nf at h
    linear_combination h
  have hy_ne_one : y ≠ 1 := fun h => hy (by simp [h])
  have hy_eq_neg_one : y = -1 := by
    have hfac : (y - 1) * (y + 1) = 0 := by
      rw [show (y - 1) * (y + 1) = y ^ 2 - 1 by ring, hy2]; ring
    have hp : y + 1 = 0 := by
      rcases mul_eq_zero.mp hfac with h | h
      · exact (hy_ne_one (eq_of_sub_eq_zero h)).elim
      · exact h
    have hz : y + 1 = -1 + 1 := by rw [hp]; ring
    exact add_right_cancel hz
  have hd0 : (1 + d : K) = 0 := by
    have := h0
    rw [hy_eq_neg_one] at this
    simpa using this
  exact hd hd0

/-- **Every Edwards point (with `y ≠ 1`) maps to the Montgomery model.** -/
theorem edwardsToMont_montgomery {d x y : K} (hE : edwardsEq d x y)
    (hy : 1 - y ≠ 0) (hd : 1 + d ≠ 0) :
    montgomeryEq d (edwardsToMont d x y).1 (edwardsToMont d x y).2 := by
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  unfold edwardsEq at hE
  -- Solve the curve equation for `x²`.
  have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
    rw [eq_div_iff hdy]
    linear_combination -hE
  unfold montgomeryEq montA montB
  simp only [edwardsToMont_fst, edwardsToMont_snd]
  field_simp [hy, hd, hdy]
  rw [hx2]
  field_simp [hy, hd, hdy]
  ring

/-- **Non-vacuity.** The hypotheses are satisfiable: `(d, x, y) = (0, 0, -1)` lies on
    `E_0 : -x² + y² = 1`, has `y ≠ 1`, and `1 + d ≠ 0`. The lemma therefore applies. -/
example : edwardsEq (0 : ℚ) 0 (-1) ∧ (1 - (-1 : ℚ)) ≠ 0 ∧ (1 + (0 : ℚ)) ≠ 0 := by
  unfold edwardsEq
  norm_num

/-- **Montgomery points map back to the Edwards curve** (the inverse direction),
    wherever `Q(u)` does not vanish. -/
theorem montgomeryToEdwards_edwards {d u v : K} (hM : montgomeryEq d u v)
    (hu : u + 1 ≠ 0) (hd : 1 + d ≠ 0) (hq : montQ d u ≠ 0) :
    edwardsEq d (montgomeryToEdwards d u v).1 (montgomeryToEdwards d u v).2 := by
  -- The Montgomery equation is exactly `-v² = u·Q(u)`.
  have hmul : v ^ 2 = -(u * montQ d u) := by
    unfold montQ
    have h := hM
    unfold montgomeryEq montA montB at h
    field_simp [hd] at h
    linear_combination -h
  unfold edwardsEq montgomeryToEdwards
  field_simp [hu, hd, hq]
  rw [hmul]
  unfold montQ
  ring


/-- **Non-vacuity.** `(d,u,v) = (0,0,0)` satisfies every hypothesis of
    `montgomeryToEdwards_edwards` (`Q(0) = 1 ≠ 0`); its image is `(0,-1)`, which
    lies on `E_0 : -x² + y² = 1`. -/
example : montgomeryEq (0 : ℚ) 0 0 ∧ montQ (0 : ℚ) 0 ≠ 0 := by
  unfold montgomeryEq montA montB montQ
  constructor <;> norm_num
/-- `Q((1+y)/(1-y))` collapses to the scaled form used by `edwardsToMont`. -/
lemma montQ_of_edwards (d y : K) (hy : 1 - y ≠ 0) :
    montQ d ((1 + y) / (1 - y)) = 4 * (1 + d * y ^ 2) / (1 - y) ^ 2 := by
  unfold montQ
  field_simp
  ring

/-- The first coordinate of `montgomeryToEdwards (edwardsToMont (x,y))` is `x` again.
    Needs `1 + d·y² ≠ 0` -- without it the formula degenerates and the statement is
    false, since Lean's `a / 0 = 0` convention would give `0 ≠ x`. -/
lemma edwards_x_recover {d x y : K} (hy : 1 - y ≠ 0) (hdy : 1 + d * y ^ 2 ≠ 0)
    (h2 : (2 : K) ≠ 0) :
    2 * (edwardsToMont d x y).2 / montQ d ((edwardsToMont d x y).1) = x := by
  rw [edwardsToMont_fst, edwardsToMont_snd, montQ_of_edwards d y hy]
  have hQ : 4 * (1 + d * y ^ 2) / (1 - y) ^ 2 ≠ 0 := by
    have h4 : (4 : K) ≠ 0 := by
      rw [show (4 : K) = 2 * 2 by norm_num]
      exact mul_ne_zero h2 h2
    exact div_ne_zero (mul_ne_zero h4 hdy) (pow_ne_zero 2 hy)
  have key : 2 * (2 * x * (1 + d * y ^ 2) / (1 - y) ^ 2) =
      x * (4 * (1 + d * y ^ 2) / (1 - y) ^ 2) := by
    field_simp [hy, hdy, mul_ne_zero h2 h2]
    ring
  rw [div_eq_iff hQ]
  exact key

/-- The second coordinate of `montgomeryToEdwards (edwardsToMont (x,y))` is `y` again.
    Requires `2 ≠ 0`, i.e. the field not of characteristic two -- in characteristic two
    `u = (1+y)/(1-y) = 1` identically, so the recovery has no content. -/
lemma edwards_y_recover {d x y : K} (hy : 1 - y ≠ 0) (h2 : (2 : K) ≠ 0) :
    ((edwardsToMont d x y).1 - 1) / ((edwardsToMont d x y).1 + 1) = y := by
  rw [edwardsToMont_fst]
  have hn : (1 + y) / (1 - y) - 1 = 2 * y / (1 - y) := by
    field_simp [hy]
    ring
  have he : (1 + y) / (1 - y) + 1 = 2 / (1 - y) := by
    field_simp [hy]
    ring
  rw [hn, he]
  field_simp [hy, h2]

/-- **Round trip, forward.** On the admissible locus, `montgomeryToEdwards` undoes
    `edwardsToMont`. -/
theorem edwardsToMont_roundtrip {d x y : K} (hE : edwardsEq d x y)
    (hy : 1 - y ≠ 0) (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) :
    montgomeryToEdwards d (edwardsToMont d x y).1 (edwardsToMont d x y).2 = (x, y) := by
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  simp only [montgomeryToEdwards, Prod.mk.injEq]
  rw [edwards_x_recover hy hdy h2, edwards_y_recover hy h2]
  exact ⟨rfl, rfl⟩

/-- The first coordinate of `edwardsToMont (montgomeryToEdwards (u,v))` is `u`
    again -- the exact inverse of `montgomeryToEdwards_fst`. -/
lemma montgomery_u_recover {u : K} (hu : u + 1 ≠ 0) (h2 : (2 : K) ≠ 0) :
    (1 + (u - 1) / (u + 1)) / (1 - (u - 1) / (u + 1)) = u := by
  field_simp [hu, h2]
  rw [show (u + 1 + (u - 1)) = 2 * u by ring,
      show (u + 1 - (u - 1)) = 2 by ring]
  rw [div_eq_iff h2]
  ring

/-- The second coordinate of `edwardsToMont (montgomeryToEdwards (u,v))` is `v`
    again, using `Q(u) = (u+1)² + d(u-1)²` and `(1-y)² = 4/(u+1)²`. -/
lemma montgomery_v_recover {d u v : K} (hu : u + 1 ≠ 0)
    (hq : montQ d u ≠ 0) (h2 : (2 : K) ≠ 0) :
    2 * (2 * v / montQ d u) * (1 + d * ((u - 1) / (u + 1)) ^ 2) /
      (1 - (u - 1) / (u + 1)) ^ 2 = v := by
  have hy'e : (1 : K) - (u - 1) / (u + 1) = 2 / (u + 1) := by
    field_simp [hu]
    ring
  have hy' : (1 : K) - (u - 1) / (u + 1) ≠ 0 := by
    rw [hy'e]
    exact div_ne_zero h2 hu
  have hden : (1 - (u - 1) / (u + 1)) ^ 2 ≠ 0 := pow_ne_zero 2 hy'
  rw [div_eq_iff hden]
  field_simp [hu, hq, h2]
  unfold montQ
  ring

/-- **Round trip, backward.** On the admissible locus, `edwardsToMont` undoes
    `montgomeryToEdwards`. Together with `edwardsToMont_roundtrip` this exhibits
    the two maps as mutually inverse on their admissible loci. -/
theorem montgomeryToEdwards_roundtrip {d u v : K}
    (hu : u + 1 ≠ 0) (hq : montQ d u ≠ 0) (h2 : (2 : K) ≠ 0) :
    edwardsToMont d (montgomeryToEdwards d u v).1 (montgomeryToEdwards d u v).2 = (u, v) := by
  simp only [montgomeryToEdwards, edwardsToMont, Prod.mk.injEq]
  rw [montgomery_u_recover hu h2, montgomery_v_recover hu hq h2]
  exact ⟨rfl, rfl⟩

/-- On the twisted-Edwards curve with `1 + d ≠ 0`, an on-curve point with
    `x ≠ 0` cannot have `y = 1`: substituting `y = 1` gives `x²(1+d) = 0`.
    This discharges the `y ≠ 1` admissibility hypotheses of the affine
    associativity theorem from its `x ≠ 0` hypotheses. -/
lemma edwards_y_ne_one_of_x_ne_zero {d x y : K}
    (hE : edwardsEq d x y) (hd : 1 + d ≠ 0) (hx : x ≠ 0) : y ≠ 1 := by
  intro h
  subst y
  unfold edwardsEq at hE
  have hx2 : x ^ 2 * (1 + d) = 0 := by
    linear_combination -hE
  have hxzero : x ^ 2 = 0 := (mul_eq_zero.mp hx2).resolve_right hd
  have hxx : x * x = 0 := by simpa [pow_two] using hxzero
  rcases mul_eq_zero.mp hxx with hzero | hzero <;> exact hx hzero

/-- Negative control: the hypothesis `1 + d ≠ 0` is load-bearing. At `d = -1`
    every `(x, 1)` is on the curve, so `x ≠ 0` alone does not imply `y ≠ 1`. -/
lemma edwards_y_ne_one_of_x_ne_zero_requires_hd :
    ¬ (∀ {d x y : K}, edwardsEq d x y → x ≠ 0 → y ≠ 1) := by
  intro h
  have hE : edwardsEq (-1 : K) (1 : K) 1 := by
    unfold edwardsEq
    ring
  exact (h hE one_ne_zero) rfl

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

/-- Distinct Montgomery `u` coordinates for distinct non-negation Edwards
    points. Equal `u` forces equal `y` (in characteristic != 2), and the curve
    equation then forces `x₂ = ±x₁`; the two possibilities are exactly the
    same point and the negation. This is the remaining algebraic obligation
    named in the review for the associativity bridge. -/
lemma edwardsToMont_fst_ne_of_ne_of_not_neg {K : Type*} [Field K] {d x1 y1 x2 y2 : K}
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2)
    (hd : 1 + d ≠ 0) (hy1 : 1 - y1 ≠ 0) (hy2 : 1 - y2 ≠ 0) (h2 : (2 : K) ≠ 0)
    (hne : (x1, y1) ≠ (x2, y2))
    (hneg : ¬ (x2 = -x1 ∧ y2 = y1)) :
    (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d x2 y2).1 := by
  intro hu
  rw [edwardsToMont_fst, edwardsToMont_fst] at hu
  field_simp [hy1, hy2] at hu
  ring_nf at hu
  have hy : y1 = y2 := by
    have htwo : (2 : K) * y1 = 2 * y2 := by linear_combination hu
    exact (mul_left_cancel₀ h2 htwo)
  subst y2
  have hdy : 1 + d * y1 ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE1 hy1 hd
  have hsquares : x1 ^ 2 = x2 ^ 2 := by
    unfold edwardsEq at hE1 hE2
    have hc1 : x1 ^ 2 * (1 + d * y1 ^ 2) = y1 ^ 2 - 1 := by linear_combination -hE1
    have hc2 : x2 ^ 2 * (1 + d * y1 ^ 2) = y1 ^ 2 - 1 := by linear_combination -hE2
    rw [← hc1] at hc2
    exact (mul_right_cancel₀ hdy hc2.symm)
  rcases (sq_eq_sq_iff_eq_or_eq_neg.mp hsquares) with hx | hx
  · exact hne (by simp [hx])
  · have hx' : x2 = -x1 := by linear_combination hx
    exact hneg ⟨hx', rfl⟩

end

end LeanFormalization
