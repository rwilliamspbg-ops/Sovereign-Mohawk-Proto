import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- System-level BFT bound used in protocol docs. -/
def bftBound (tiers : List Tier) : Prop :=
  9 * totalByzantine tiers < 5 * totalNodes tiers

/-- Honest-majority checker per tier (`2f < n`). -/
def honestMajority (t : Tier) : Prop :=
  2 * t.f < t.n

/-- If all tiers satisfy strict honest majority, their aggregate is still below 50%. -/
theorem theorem1_half_bound_of_forall_cons (t : Tier) (ts : List Tier)
    (h_t : honestMajority t)
    (h_ts : ∀ x ∈ ts, honestMajority x) :
    2 * totalByzantine (t :: ts) < totalNodes (t :: ts) := by
  induction ts with
  | nil =>
      simpa [totalByzantine, totalNodes, sumN, honestMajority] using h_t
  | cons u us ih =>
      have h_u : honestMajority u := h_ts u (by simp)
      have h_us : ∀ x ∈ us, honestMajority x := by
        intro x hx
        exact h_ts x (by simp [hx])
      have h_tail : 2 * totalByzantine (u :: us) < totalNodes (u :: us) :=
        ih h_u h_us
      have h_head : 2 * t.f < t.n := h_t
      have h_add : 2 * t.f + 2 * totalByzantine (u :: us) < t.n + totalNodes (u :: us) :=
        Nat.add_lt_add h_head h_tail
      simpa [totalByzantine, totalNodes, sumN, Nat.left_distrib, Nat.add_assoc,
        Nat.add_left_comm, Nat.add_comm] using h_add

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
      simpa using theorem1_half_bound_of_forall_cons t ts h_t h_ts

/-- The 1/2-bound implies the published 5/9 global tolerance inequality. -/
theorem theorem1_five_ninths_of_half_bound (tiers : List Tier)
    (h_half : 2 * totalByzantine tiers < totalNodes tiers) :
    bftBound tiers := by
  let fb := totalByzantine tiers
  let nn := totalNodes tiers
  have h_nn_pos : 0 < nn := by
    have h_fb_nonneg : 0 <= 2 * fb := Nat.zero_le _
    exact lt_of_le_of_lt h_fb_nonneg (by simpa [fb, nn] using h_half)
  have h18 : 18 * fb < 9 * nn := by
    simpa [fb, nn, Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm] using
      Nat.mul_lt_mul_of_pos_left h_half (by decide : 0 < 9)
  have h9lt10 : 9 * nn < 10 * nn := by
    simpa [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm] using
      Nat.mul_lt_mul_of_pos_right (show 9 < 10 by decide) h_nn_pos
  have h18lt10 : 18 * fb < 10 * nn := lt_trans h18 h9lt10
  have h_target : 9 * fb < 5 * nn := by
    by_contra h_not
    have h_ge : 5 * nn <= 9 * fb := Nat.le_of_not_lt h_not
    have h10le18 : 10 * nn <= 18 * fb := by
      simpa [Nat.mul_assoc, Nat.mul_comm, Nat.mul_left_comm] using
        Nat.mul_le_mul_left 2 h_ge
    exact (not_le_of_gt h18lt10) h10le18
  simpa [bftBound, fb, nn] using h_target

/-- Concrete 4-tier profile for machine checking. -/
def mohawkProfile : List Tier :=
  [
    { n := 9000000, f := 4999999 },
    { n := 900000,  f := 400000 },
    { n := 90000,   f := 30000 },
    { n := 10000,   f := 1000 }
  ]

/-- Every tier in the concrete profile has strict honest majority. -/
theorem theorem1_tier_majority_checked :
    (mohawkProfile.all (fun t => decide (honestMajority t))) = true := by
  native_decide

/-- Concrete profile satisfies the global 5/9 BFT bound. -/
theorem theorem1_global_bound_checked : bftBound mohawkProfile := by
  have h_nonempty : mohawkProfile ≠ [] := by decide
  have h_all : ∀ t ∈ mohawkProfile, honestMajority t := by
    intro t ht
    native_decide
  exact theorem1_five_ninths_of_half_bound _
    (theorem1_half_bound_of_forall _ h_nonempty h_all)

/-- 10M-scale corollary: 5,555,555 Byzantine nodes remains below 5/9 of total. -/
theorem theorem1_ten_million_corollary :
    9 * (5555555 : Nat) < 5 * (10000000 : Nat) := by
  native_decide

end LeanFormalization
