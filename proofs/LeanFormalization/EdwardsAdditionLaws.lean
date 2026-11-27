import LeanFormalization.MontgomeryEdwardsAdditionCompat

/-!
# Generic Edwards addition-law identities

`edAddField` is the unified twisted-Edwards addition formula over an arbitrary
field `K`. This module records the unconditional structural laws that hold
before any completeness or on-curve hypothesis is imposed:

* `edAddField_identity_left`, `edAddField_identity_right`: the affine identity
  `(0, 1)` is a two-sided identity **definitionally**, because the cross terms
  vanish and both denominators become `1`. No `d`, non-squareness, or on-curve
  hypothesis is needed.
* `edAddField_comm`: the formula is symmetric under exchanging the operands.
* `edAddField_neg_self_eq_identity`: on-curve negation, under an explicit
  denominator hypothesis with a machine-checked load-bearing control.

These laws are used in the exceptional-case analysis of the Ed25519 bridge;
they are deliberately weaker than the conditional associativity theorem and
make no claim about completeness of the denominators.

Residual: nothing is claimed about associativity, on-curve closure, or the
`torsion` / `u₁ = u₂` cases here; negation requires `1 + d·x²·y² ≠ 0`. They remain the subject of
`MontgomeryEdwardsAdditionCompat.lean` and `Ed25519CurveGroupLaw.lean`.
-/
namespace LeanFormalization

variable {K : Type*} [Field K]

/-- The Edwards identity `(0, 1)` on the left. Unconditional. -/
lemma edAddField_identity_left (d x y : K) :
    edAddField d 0 1 x y = (x, y) := by
  ext <;> simp [edAddField]

/-- The Edwards identity `(0, 1)` on the right. Unconditional. -/
lemma edAddField_identity_right (d x y : K) :
    edAddField d x y 0 1 = (x, y) := by
  ext <;> simp [edAddField, add_comm, mul_comm]

/-- Symmetry of the unified addition formula, unconditional. -/
lemma edAddField_comm (d x1 y1 x2 y2 : K) :
    edAddField d x1 y1 x2 y2 = edAddField d x2 y2 x1 y1 := by
  ext <;> simp [edAddField, add_comm, mul_comm, mul_left_comm]


/-- Adding an Edwards point to its negation yields the identity, provided the
    denominator `1 + d·x²·y²` is nonzero. The on-curve equation makes the second
    coordinate's numerator equal to that denominator. -/
lemma edAddField_neg_self_eq_identity {d x y : K}
    (hE : edwardsEq d x y) (hden : 1 + d * x ^ 2 * y ^ 2 ≠ 0) :
    edAddField d x y (-x) y = (0, 1) := by
  have hnum : y ^ 2 - x ^ 2 = 1 + d * x ^ 2 * y ^ 2 := by
    unfold edwardsEq at hE
    linear_combination hE
  ext
  · change (x * y + y * (-x)) / (1 + d * x * (-x) * y * y) = 0
    have hz : x * y + y * (-x) = 0 := by ring
    rw [hz, zero_div]
  · change (y * y + x * (-x)) / (1 - d * x * (-x) * y * y) = 1
    have hden' : 1 - d * x * (-x) * y * y ≠ 0 := by
      intro h
      apply hden
      ring_nf at h ⊢
      exact h
    rw [div_eq_iff hden']
    ring_nf at hnum ⊢
    exact hnum


/-- The symmetric negation law, obtained from commutativity of the formula. -/
lemma edAddField_neg_self_eq_identity_right {d x y : K}
    (hE : edwardsEq d x y) (hden : 1 + d * x ^ 2 * y ^ 2 ≠ 0) :
    edAddField d (-x) y x y = (0, 1) := by
  rw [edAddField_comm]
  exact edAddField_neg_self_eq_identity hE hden

/-- The denominator hypothesis of `edAddField_neg_self_eq_identity` is
    load-bearing: over `ZMod 11` with `d = 2`, the on-curve point `(2, 2)` has
    `1 + d·x²·y² = 0`, and the unified formula returns `(0, 0)`, not the
    identity. -/
lemma edAddField_neg_self_requires_hden :
    haveI : Fact (Nat.Prime 11) := ⟨by norm_num⟩
    edAddField (2 : ZMod 11) 2 2 (-2) 2 ≠ (0, 1) := by
  decide

end LeanFormalization
