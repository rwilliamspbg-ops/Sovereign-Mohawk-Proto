import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- Integer epsilon composition model for deterministic machine checks. -/
def composeEps : List Nat -> Nat
  | [] => 0
  | x :: xs => x + composeEps xs

/-- Theorem 2 core: sequential composition over concatenated mechanisms is additive. -/
theorem theorem2_composition_append (xs ys : List Nat) :
    composeEps (xs ++ ys) = composeEps xs + composeEps ys := by
  induction xs with
  | nil => simp [composeEps]
  | cons x xs ih =>
      simpa [composeEps, Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using congrArg (fun z => x + z) ih

/-- Composition is monotone when appending additional mechanisms. -/
theorem theorem2_monotone_append (xs ys : List Nat) :
    composeEps xs <= composeEps (xs ++ ys) := by
  rw [theorem2_composition_append]
  exact Nat.le_add_right _ _

/-- Adding a bounded step preserves a bounded global budget. -/
theorem theorem2_budget_step {current step budget : Nat}
    (h_cur : current <= budget)
    (h_step : step <= budget - current) :
    current + step <= budget := by
  exact Nat.add_le_of_le_sub h_step

/-- Example composition for a 4-tier privacy budget profile. -/
theorem theorem2_example_profile :
    composeEps [1, 5, 10, 0] = 16 := by
  native_decide

/-- Tight budget guard: composed epsilon remains under configured ceiling. -/
theorem theorem2_budget_guard :
    composeEps [1, 5, 10, 0] <= 20 := by
  native_decide

end LeanFormalization
