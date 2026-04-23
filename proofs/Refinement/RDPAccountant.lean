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
  have hsum : 0 ≤ composeRDP ys := composeRDP_nonneg ys h_nonneg
  calc
    accountantImpl xs = composeRDP xs := by rfl
    _ ≤ composeRDP xs + composeRDP ys := by linarith
    _ = composeRDP (xs ++ ys) := by
      simpa [composeRDP_append] using (composeRDP_append xs ys).symm
    _ = accountantImpl (xs ++ ys) := by rfl

theorem accountant_impl_preserves_budget (steps : List ℚ) (budget : ℚ)
  (_h_nonneg : ∀ e ∈ steps, 0 ≤ e)
    (h_budget : accountantSpec steps ≤ budget) :
    accountantImpl steps ≤ budget := by
  simpa [accountantImpl, accountantSpec, rdpAccountant] using h_budget

end Refinement
