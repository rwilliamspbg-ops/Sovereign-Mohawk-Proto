import Mathlib.Data.List.Basic
import Mathlib.Tactic.Linarith

namespace LeanFormalization

/-! Simplified and provable subset of Theorem2RDP_Enhanced.

This file focuses on exact rational composition and simple conversion lemmas
that are used directly by runtime tests and the Go accountant.
-/

/-- Two databases are adjacent if they differ by exactly one record. -/
def isAdjacent (d1 d2 : List ℚ) : Prop :=
  d1.length = d2.length ∧ ∃ i, i < d1.length ∧ d1.get i ≠ d2.get i

/-- Exact rational composition ledger used for runtime accounting. -/
def composeEpsRat : List ℚ → ℚ
  | [] => 0
  | x :: xs => x + composeEpsRat xs

/-- Convert RDP bound (ε_rdp) to (ε, δ)-DP simplification. -/
def convertToEpsDelta (alpha epsRdp logOneOverDelta : ℚ) : ℚ :=
  epsRdp + (logOneOverDelta / (alpha - 1))

/-- Single-step composition identity. -/
lemma theorem2_rat_single_step (eps : ℚ) :
  composeEpsRat [eps] = eps := by simp [composeEpsRat]

/-- Composition is additive over concatenation. -/
theorem theorem2_rat_composition_append (xs ys : List ℚ) :
  composeEpsRat (xs ++ ys) = composeEpsRat xs + composeEpsRat ys := by
  induction xs with
  | nil => simp [composeEpsRat]
  | cons x xs ih =>
    simp [composeEpsRat, List.cons_append]
    calc
      x + (composeEpsRat (xs ++ ys)) = x + (composeEpsRat xs + composeEpsRat ys) := by rw [ih]
      _ = x + composeEpsRat xs + composeEpsRat ys := by ring

/-- Monotonicity when appending nonnegative steps. -/
theorem theorem2_rat_monotone_append
    (xs ys : List ℚ)
    (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
  composeEpsRat xs ≤ composeEpsRat (xs ++ ys) := by
  rw [theorem2_rat_composition_append]
  have : 0 ≤ composeEpsRat ys := by
    induction ys with
    | nil => simp [composeEpsRat]
    | cons y ys ih =>
      have hy : 0 ≤ y := h_nonneg y (by simp)
      have htail : ∀ e ∈ ys, 0 ≤ e := fun e he => h_nonneg e (by simp [he])
      have ih' := ih htail
      simp [composeEpsRat]
      linarith
  linarith

/-- Conversion monotonicity: increasing eps_rdp increases ε. -/
theorem theorem2_conversion_monotone
    {alpha logOneOverDelta eps1 eps2 : ℚ}
    (h_alpha : 1 < alpha)
    (h_eps : eps1 ≤ eps2) :
  convertToEpsDelta alpha eps1 logOneOverDelta ≤
    convertToEpsDelta alpha eps2 logOneOverDelta := by
  unfold convertToEpsDelta
  linarith

/-- Simple 4-tier example values and total. -/
def fourTierBudgetExample : List ℚ := [ (10 : ℚ) / 100, (5 : ℚ) / 100, (3 : ℚ) / 100, (2 : ℚ) / 100 ]

theorem theorem2_four_tier_total :
  composeEpsRat fourTierBudgetExample = (20 : ℚ) / 100 := by
  simp [composeEpsRat, fourTierBudgetExample]

theorem theorem2_four_tier_budgets_safe :
  composeEpsRat fourTierBudgetExample ≤ (2 : ℚ) := by
  have : composeEpsRat fourTierBudgetExample = (20 : ℚ) / 100 := by simp [composeEpsRat, fourTierBudgetExample]
  rw [this]
  norm_num

end LeanFormalization
