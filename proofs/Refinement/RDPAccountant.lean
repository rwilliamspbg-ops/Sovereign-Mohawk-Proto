import Specification.Privacy

namespace Refinement

open Specification


def accountantSpec (steps : List ℚ) : ℚ :=
  composeRDP steps

def accountantImpl (steps : List ℚ) : ℚ :=
  rdpAccountant steps

theorem accountant_impl_refines_spec (steps : List ℚ) :
    accountantImpl steps = accountantSpec steps := by
  rfl

theorem accountant_impl_append (xs ys : List ℚ) :
    accountantImpl (xs ++ ys) = accountantImpl xs + accountantImpl ys := by
  simp [accountantImpl, rdpAccountant, composeRDP_append]

theorem accountant_impl_monotone_append (xs ys : List ℚ)
    (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
    accountantImpl xs ≤ accountantImpl (xs ++ ys) := by
  rw [accountantImpl, rdpAccountant, composeRDP_append]
  have hsum : 0 ≤ composeRDP ys := composeRDP_nonneg ys h_nonneg
  linarith

theorem accountant_impl_preserves_budget (steps : List ℚ) (budget : ℚ)
    (h_nonneg : ∀ e ∈ steps, 0 ≤ e)
    (h_budget : accountantSpec steps ≤ budget) :
    accountantImpl steps ≤ budget := by
  simpa [accountantImpl, accountantSpec, rdpAccountant] using h_budget

end Refinement
