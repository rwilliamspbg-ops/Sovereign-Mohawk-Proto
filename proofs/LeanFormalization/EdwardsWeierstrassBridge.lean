import Mathlib

/-
# Birational bridge: twisted Edwards -> Montgomery

The Ed25519 group law is the unified twisted-Edwards addition with `a = -1`:

    E_d : -x² + y² = 1 + d·x²·y².

`affineAdd` implements it (`LeanFormalization/Ed25519ScalarMulStructure.lean`), and its
**associativity** is the open law blocking the four group laws consumed by
`Ed25519VerificationEquation.lean`. This file is the **first leg** of the route to
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

## What is NOT proved here (stated openly)

* **Addition-law compatibility.** Nothing here shows that `affineAdd` corresponds to
  the Montgomery (or Weierstrass) addition under this map. Without that, no group
  law — not associativity — can be inherited. This is the next step.
* **Denominator completeness.** Both directions exclude exceptional points
  explicitly (`1 - y = 0`, i.e. the Edwards identity `(0,1)`, and `1 + d = 0`).
  Showing the implementation never divides by zero needs `d` to be a non-square
  modulo `p`, which is number-theoretic and separate.
* The inverse direction `montgomeryToEdwards` is defined but **not yet proved**
  to land back on `E_d`.
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

/-- **Montgomery → Edwards.** Inverse of `edwardsToMont` on the admissible locus:
    recover `y = (u-1)/(u+1)` and `x = 2v / Q(u)`. -/
def montgomeryToEdwards (d : K) (u v : K) : K × K :=
  let y := (u - 1) / (u + 1)
  let q := (1 + d) * u ^ 2 + 2 * (1 - d) * u + (1 + d)
  (2 * v / q, y)

/-- **Every Edwards point (with `y ≠ 1`) maps to the Montgomery model.** -/
theorem edwardsToMont_montgomery {d x y : K} (hE : edwardsEq d x y)
    (hy : 1 - y ≠ 0) (hd : 1 + d ≠ 0) :
    montgomeryEq d (edwardsToMont d x y).1 (edwardsToMont d x y).2 := by
  unfold edwardsEq at hE
  -- `1 + d·y²` cannot vanish: otherwise `y = -1` and then `d = -1`.
  have hdy : 1 + d * y ^ 2 ≠ 0 := by
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

end

end LeanFormalization
