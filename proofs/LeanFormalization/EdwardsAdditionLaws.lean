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

These laws are used in the exceptional-case analysis of the Ed25519 bridge;
they are deliberately weaker than the conditional associativity theorem and
make no claim about completeness of the denominators.

Residual: nothing is claimed about associativity, on-curve closure, or the
`torsion` / `u₁ = u₂` cases here. They remain the subject of
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

end LeanFormalization
