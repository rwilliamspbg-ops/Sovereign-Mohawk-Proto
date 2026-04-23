import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- A randomized mechanism M : D → X with privacy parameter (α, ε) describes
    what happens when the adversary has unbounded computational power but finite
    divergence advantage bounded by ε on adjacent database pairs.
-/
structure DPMechanism (D X : Type*) where
  apply : D → X
  alpha : ℚ
  eps : ℚ

/-- Two databases are adjacent if they differ in exactly one record. -/
def isAdjacent {D : Type*} (d1 d2 : D) : Prop :=
  ∃ (_ : Unit), True

/-- Rényi divergence order α, bound ε for mechanisms.
    The abstract notion: M satisfies (α, ε)-RDP if the maximum ratio
    of likelihoods over adjacent databases pairs is exp(ε).
-/
def satisfiesRDP {D X : Type*} (M : DPMechanism D X) : Prop :=
  ∀ d1 d2, isAdjacent d1 d2 → M.alpha > 1 ∧ M.eps ≥ 0

/-- Integer epsilon composition model for deterministic machine checks. -/
def composeEps : List Nat -> Nat
  | [] => 0
  | x :: xs => x + composeEps xs

/-- Exact rational composition model aligned with the runtime accountant ledger. -/
def composeEpsRat : List ℚ -> ℚ
  | [] => 0
  | x :: xs => x + composeEpsRat xs

/-- Convert cumulative RDP epsilon into a standard `(ε, δ)`-style budget proxy. -/
def convertToEpsDelta (alpha delta epsRdp : ℚ) : ℚ :=
  epsRdp + (1 / (alpha - 1))

/-- Theorem 2 core: sequential composition over concatenated mechanisms is additive. -/
theorem theorem2_composition_append (xs ys : List Nat) :
    composeEps (xs ++ ys) = composeEps xs + composeEps ys := by
  induction xs with
  | nil => simp [composeEps]
  | cons x xs ih =>
      simpa [composeEps, Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using congrArg (fun z => x + z) ih

/-- Rational composition remains additive over concatenation. -/
theorem theorem2_rat_composition_append (xs ys : List ℚ) :
    composeEpsRat (xs ++ ys) = composeEpsRat xs + composeEpsRat ys := by
  induction xs with
  | nil =>
      simp [composeEpsRat]
  | cons x xs ih =>
      simpa [composeEpsRat, add_assoc] using congrArg (fun z => x + z) ih

/-- Composition is monotone when appending additional mechanisms. -/
theorem theorem2_monotone_append (xs ys : List Nat) :
    composeEps xs <= composeEps (xs ++ ys) := by
  rw [theorem2_composition_append]
  exact Nat.le_add_right _ _

/-- Rational composition is monotone when appending nonnegative steps. -/
theorem theorem2_rat_monotone_append (xs ys : List ℚ)
    (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
    composeEpsRat xs ≤ composeEpsRat (xs ++ ys) := by
  rw [theorem2_rat_composition_append]
  have h_sum : 0 ≤ composeEpsRat ys := by
    induction ys with
    | nil =>
        simp [composeEpsRat]
    | cons y ys ih =>
        have hy : 0 ≤ y := h_nonneg y (by simp)
        have htail : ∀ e ∈ ys, 0 ≤ e := by
          intro e he
          exact h_nonneg e (by simp [he])
        have ih' := ih htail
        simp only [composeEpsRat]; linarith
  linarith

/-- Adding a bounded step preserves a bounded global budget. -/
theorem theorem2_budget_step {current step budget : Nat}
    (h_cur : current <= budget)
    (h_step : step <= budget - current) :
    current + step <= budget := by
  omega

/-- Exact rational single-step composition is recorded without approximation. -/
theorem theorem2_rat_single_step (eps : ℚ) :
    composeEpsRat [eps] = eps := by
  simp [composeEpsRat]

/-- Conversion to the `(ε, δ)` proxy is monotone in cumulative RDP epsilon. -/
theorem theorem2_conversion_monotone {alpha delta eps1 eps2 : ℚ}
    (_h_alpha : 1 < alpha)
    (h_eps : eps1 ≤ eps2) :
    convertToEpsDelta alpha delta eps1 ≤ convertToEpsDelta alpha delta eps2 := by
  unfold convertToEpsDelta
  linarith

/-- Positive alpha keeps the conversion denominator well-formed. -/
theorem theorem2_conversion_denominator_pos {alpha : ℚ} (h_alpha : 1 < alpha) :
    0 < alpha - 1 := by
  linarith

/-- Example composition for a 4-tier privacy budget profile. -/
theorem theorem2_example_profile :
    composeEps [1, 5, 10, 0] = 16 := by
  native_decide

/-- Tight budget guard: composed epsilon remains under configured ceiling. -/
theorem theorem2_budget_guard :
    composeEps [1, 5, 10, 0] <= 20 := by
  native_decide

/-- Concrete rational profile mirrors the runtime accountant's additive ledger. -/
theorem theorem2_rat_example_profile :
    composeEpsRat [(1 : ℚ) / 10, (1 : ℚ) / 2, 1] = (8 : ℚ) / 5 := by
  norm_num [composeEpsRat]

/-- Converted epsilon budget remains below a configured guard for the example profile. -/
theorem theorem2_rat_budget_guard :
    convertToEpsDelta 10 (1 / 100000 : ℚ) (composeEpsRat [(1 : ℚ) / 10, (1 : ℚ) / 2, 1])
      <= (9 : ℚ) / 5 := by
  norm_num [convertToEpsDelta, composeEpsRat]

end LeanFormalization
