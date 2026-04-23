import Mathlib
import Specification.System

namespace Specification

abbrev Database := List ℚ

def adjacent (d1 d2 : Database) : Prop :=
  ∃ pre : Database,
    ∃ x : ℚ,
      ∃ y : ℚ,
        ∃ suffix : Database,
          x ≠ y ∧
          d1 = pre ++ x :: suffix ∧
          d2 = pre ++ y :: suffix

/-- Exact rational RDP composition ledger used by the specification layer. -/
def composeRDP : List ℚ -> ℚ
  | [] => 0
  | x :: xs => x + composeRDP xs

/-- Abstract accountant implementation model: exact additive composition. -/
def rdpAccountant (steps : List ℚ) : ℚ :=
  composeRDP steps

/-- Standard Gaussian-mechanism step in the exact rational specification. -/
def gaussianStepRDP (alpha sigma : ℚ) : ℚ :=
  alpha / (2 * sigma * sigma)

/-- Structural composition lemma for the exact accountant model. -/
theorem composeRDP_append (xs ys : List ℚ) :
    composeRDP (xs ++ ys) = composeRDP xs + composeRDP ys := by
  induction xs with
  | nil =>
      simp [composeRDP]
  | cons x xs ih =>
      simpa [composeRDP, add_assoc] using congrArg (fun z => x + z) ih

/-- Nonnegative steps produce a nonnegative total privacy budget. -/
theorem composeRDP_nonneg (steps : List ℚ)
    (h_nonneg : ∀ e ∈ steps, 0 ≤ e) :
    0 ≤ composeRDP steps := by
  induction steps with
  | nil =>
      simp [composeRDP]
  | cons x xs ih =>
      have hx : 0 ≤ x := h_nonneg x (by simp)
      have hxs : ∀ e ∈ xs, 0 ≤ e := by
        intro e he
        exact h_nonneg e (by simp [he])
      have ih' := ih hxs
      simpa [composeRDP] using add_nonneg hx ih'

/-- A single Gaussian step is recorded exactly by the accountant model. -/
theorem gaussian_rdp_step_exact (alpha sigma : ℚ) :
    rdpAccountant [gaussianStepRDP alpha sigma] = gaussianStepRDP alpha sigma := by
  simp [rdpAccountant, composeRDP, gaussianStepRDP]

/-- Budget soundness in the exact rational specification. -/
theorem accountant_within_budget (steps : List ℚ) (budget : ℚ)
  (_h_nonneg : ∀ e ∈ steps, 0 ≤ e)
    (h_budget : composeRDP steps ≤ budget) :
    rdpAccountant steps ≤ budget := by
  simpa [rdpAccountant] using h_budget

theorem rdp_accountant_sound (steps : List ℚ) :
    rdpAccountant steps = composeRDP steps := by
  rfl

end Specification
