import Mathlib

namespace LeanFormalization.RDPEnhanced

/-!
Enhanced / runtime-focused variants.
These are kept in a sub-namespace to avoid collisions.
-/

/-- Exact rational composition (runtime accountant version). -/
def composeEpsRat : List ℚ → ℚ
  | [] => 0
  | x :: xs => x + composeEpsRat xs

/-- Convert RDP to `(ε, δ)` proxy. -/
def convertToEpsDelta (alpha epsRdp logOneOverDelta : ℚ) : ℚ :=
  epsRdp + (logOneOverDelta / (alpha - 1))

/-- Four-tier budget example used in tests. -/
def fourTierBudgetExample : List ℚ :=
  [(1 : ℚ) / 10, (1 : ℚ) / 20, (3 : ℚ) / 100, (1 : ℚ) / 50]

theorem theorem2_four_tier_total :
  composeEpsRat fourTierBudgetExample = (1 : ℚ) / 5 := by
  norm_num [composeEpsRat, fourTierBudgetExample]

end LeanFormalization.RDPEnhanced
