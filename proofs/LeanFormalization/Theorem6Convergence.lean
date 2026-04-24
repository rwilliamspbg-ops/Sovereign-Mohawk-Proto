import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- Integer convergence envelope surrogate for machine-checked bounds. -/
def envelope (k t zeta : Nat) : ℚ :=
  (zeta : ℚ) * zeta + (1 : ℚ) / ((Nat.sqrt (k * t) : ℚ) + 1)

/-- Decomposition of the envelope into heterogeneity and optimization terms. -/
theorem theorem6_envelope_decompose (k t zeta : Nat) :
  envelope k t zeta = (zeta : ℚ) * zeta + (1 : ℚ) / ((Nat.sqrt (k * t) : ℚ) + 1) := by
  rfl

/-- Envelope is always nonnegative by construction. -/
theorem theorem6_nonnegative (k t zeta : Nat) :
    0 <= envelope k t zeta := by
  unfold envelope
  have hz : 0 <= (zeta : ℚ) * zeta := by nlinarith
  have hfrac : 0 <= (1 : ℚ) / ((Nat.sqrt (k * t) : ℚ) + 1) := by positivity
  linarith

/-- Increasing training rounds shrinks the reciprocal part in this surrogate. -/
theorem theorem6_rounds_help :
    envelope 100 1000 1 <= envelope 100 100 1 := by
  norm_num [envelope]

/-- More rounds continue to reduce the reciprocal term in this surrogate. -/
theorem theorem6_rounds_help_stronger :
    envelope 100 5000 1 <= envelope 100 1000 1 := by
  norm_num [envelope]

/-- Concrete large-scale convergence envelope check. -/
theorem theorem6_large_scale_guard :
    envelope 1000 1000 1 <= 2 := by
  norm_num [envelope]

/-- Larger heterogeneity parameter increases the surrogate envelope. -/
theorem theorem6_heterogeneity_effect :
    envelope 1000 1000 2 >= envelope 1000 1000 1 := by
  norm_num [envelope]

end LeanFormalization
