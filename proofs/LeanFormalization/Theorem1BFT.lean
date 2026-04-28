import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- Strategy:
  Model tiered Byzantine resistance with natural-number arithmetic over tier lists.

  Tactics used:
  - `simp` for list and sum normalization
  - `omega` and `linarith` for concrete threshold inequalities
  - `decide` for finite profile checks

  Future work:
  Extend the deterministic 5/9 guard with the probabilistic Chernoff tail model
  proven in `Theorem4ChernoffBounds.lean`.
-/

/-- System-level BFT bound used in protocol docs. -/
def bftBound (tiers : List Tier) : Prop :=
  9 * totalByzantine tiers < 5 * totalNodes tiers

/-- Honest-majority checker per tier (`2f < n`). -/
def honestMajority (t : Tier) : Prop :=
  2 * t.f < t.n

instance (t : Tier) : Decidable (honestMajority t) :=
  inferInstanceAs (Decidable (2 * t.f < t.n))

/-- If all tiers satisfy strict honest majority, their aggregate is still below 50%. -/
theorem theorem1_half_bound_of_forall_cons (t : Tier) (ts : List Tier)
    (h_t : honestMajority t)
    (h_ts : ∀ x ∈ ts, honestMajority x) :
    2 * totalByzantine (t :: ts) < totalNodes (t :: ts) := by
  induction ts with
  | nil =>
      -- totalByzantine (t :: []) reduces to t.f; totalNodes to t.n; both are abbrev.
      simp only [totalByzantine, totalNodes, sumN, List.map, Nat.add_zero]
      exact h_t
  | cons u us ih =>
      have h_u : honestMajority u := h_ts u (by simp)
      have h_us : ∀ x ∈ us, honestMajority x := by
        intro x hx
        exact h_ts x (by simp [hx])
      have h_rec := ih h_us
      simp only [totalByzantine, totalNodes, sumN, List.map, honestMajority] at *
      linarith

/-- Nonempty-tier composition form of Theorem 1 at the 1/2 boundary. -/
theorem theorem1_half_bound_of_forall (tiers : List Tier)
    (h_nonempty : tiers ≠ [])
    (h_all : ∀ t ∈ tiers, honestMajority t) :
    2 * totalByzantine tiers < totalNodes tiers := by
  cases tiers with
  | nil => contradiction
  | cons t ts =>
      have h_t : honestMajority t := h_all t (by simp)
      have h_ts : ∀ x ∈ ts, honestMajority x := by
        intro x hx
        exact h_all x (by simp [hx])
      exact theorem1_half_bound_of_forall_cons t ts h_t h_ts

/-- The 1/2-bound implies the published 5/9 global tolerance inequality. -/
theorem theorem1_five_ninths_of_half_bound (tiers : List Tier)
    (h_half : 2 * totalByzantine tiers < totalNodes tiers) :
    bftBound tiers := by
  unfold bftBound
  omega

/-- Concrete 4-tier Sovereign-Mohawk profile.
    Tier 1: 9M nodes with up to 4,999,999 Byzantine (just under 5/9 ratio).
    Global BFT check: 9 × 5,430,999 = 48,878,991 < 50,000,000 = 5 × 10,000,000.
-/
def mohawkProfile : List Tier :=
  [
    { n := 9000000, f := 4999999 },
    { n := 900000,  f := 400000 },
    { n := 90000,   f := 30000 },
    { n := 10000,   f := 1000 }
  ]

/-- Every tier in the concrete profile satisfies the per-tier 5/9 BFT bound
    (9f < 5n), the same ratio as the system-level guarantee. -/
theorem theorem1_tier_majority_checked :
    ∀ t ∈ mohawkProfile, 9 * t.f < 5 * t.n := by
  decide

/-- Concrete profile satisfies the global 5/9 BFT bound:
    9 × totalByzantine < 5 × totalNodes. -/
theorem theorem1_global_bound_checked : bftBound mohawkProfile := by
  unfold bftBound
  decide

/-- 10M-scale corollary: 5,555,555 Byzantine nodes remains below 5/9 of total. -/
theorem theorem1_ten_million_corollary :
    9 * (5555555 : Nat) < 5 * (10000000 : Nat) := by
  native_decide

end LeanFormalization
