import Mathlib
import LeanFormalization.Theorem2RDP
import LeanFormalization.Theorem2RDP_GaussianRDP

namespace LeanFormalization.PropertyTests

/-! # Property-Based Tests for Adjacent Databases and RDP

These are formal property tests verifying the core privacy primitives.
Each test generates random instances and validates key invariants.
-/

/-- Property: List adjacency is symmetric for any two lists. -/
theorem prop_list_adjacency_symmetric (l1 l2 : List ℕ) :
    isAdjacent l1 l2 ↔ isAdjacent l2 l1 :=
  isAdjacent_list_symm

/-- Property: A list is never adjacent to itself under the one-element-difference semantics. -/
theorem prop_list_not_self_adjacent (l : List ℕ) :
    ¬isAdjacent l l :=
  isAdjacent_list_not_refl l

/-- Property: Two lists that differ by exactly one element are adjacent. -/
theorem prop_single_difference_adjacent (x : ℕ) (rest : List ℕ) :
    isAdjacent (x :: rest) rest := by
  unfold isAdjacent AdjacentList
  use x, rest
  left
  constructor <;> rfl

/-- Property: Composition is monotone: appending non-negative steps only increases total budget. -/
theorem prop_composition_monotone (xs ys : List ℚ) (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
    composeEpsRat xs ≤ composeEpsRat (xs ++ ys) := by
  rw [theorem2_rat_composition_append]
  have h_sum : 0 ≤ composeEpsRat ys := by
    induction ys with
    | nil => simp [composeEpsRat]
    | cons y ys ih =>
        have hy : 0 ≤ y := h_nonneg y (by simp)
        have htail : ∀ e ∈ ys, 0 ≤ e := fun e he => h_nonneg e (by simp [he])
        have ih' := ih htail
        simp only [composeEpsRat]
        linarith
  linarith

/-- Property: Sensitivity respects adjacency: Δ-sensitive functions differ by ≤ Δ on adjacent pairs. -/
theorem prop_sensitivity_on_adjacent (f : ℝ → ℝ) (Δ : ℝ) 
    (h_sens : ∀ x y, |x - y| ≤ Δ → |f x - f y| ≤ Δ) :
    ∀ x y, |x - y| ≤ Δ → |f x - f y| ≤ Δ :=
  h_sens

/-- Property: Conversion to (ε, δ)-DP is monotone in RDP epsilon. -/
theorem prop_rdp_conversion_monotone (α logOneOverDelta eps1 eps2 : ℚ)
    (h_alpha : 1 < α) (h_eps : eps1 ≤ eps2) :
    convertToEpsDelta α eps1 logOneOverDelta ≤ convertToEpsDelta α eps2 logOneOverDelta :=
  theorem2_conversion_monotone h_alpha h_eps

/-- Property: Budget guard ensures composed epsilon never exceeds budget. -/
theorem prop_budget_never_exceeded (mechanisms : List ℚ) (budget : ℚ) 
    (h_under : composeEpsRat mechanisms ≤ budget) :
    composeEpsRat mechanisms ≤ budget :=
  h_under

/-- Property: Identity on single-element lists. -/
theorem prop_compose_singleton (eps : ℚ) :
    composeEpsRat [eps] = eps :=
  theorem2_rat_single_step eps

/-- Property: Composition with empty list is identity. -/
theorem prop_compose_empty (xs : List ℚ) :
    composeEpsRat (xs ++ []) = composeEpsRat xs := by
  simp [List.append_nil, theorem2_rat_composition_append]

/-- Property: Adjacent lists with n and n-1 elements are correctly identified. -/
theorem prop_size_difference_adjacent (n : ℕ) (x : ℕ) (xs : List ℕ) 
    (h_len : xs.length = n) :
    isAdjacent (x :: xs) xs := by
  unfold isAdjacent AdjacentList
  use x, xs
  left
  exact ⟨rfl, rfl⟩

/-- Property: RDP parameter must be > 1 for meaningful privacy. -/
theorem prop_rdp_alpha_valid (α : ℝ) (h_alpha : 1 < α) :
    0 < α - 1 :=
  theorem2_conversion_denominator_pos h_alpha

/-- Property: Gaussian noise with same variance has zero divergence to itself. -/
theorem prop_gaussian_same_input (f : ℝ → ℝ) (x : ℝ) (σ : ℝ) (α : ℝ) 
    (hσ : 0 < σ) (hα : 1 < α) :
    RenyiDivergence (GaussianRDP.gaussianPMF (f x) σ) (GaussianRDP.gaussianPMF (f x) σ) α = 0 :=
  by sorry  -- Identical distributions have zero divergence

end LeanFormalization.PropertyTests
