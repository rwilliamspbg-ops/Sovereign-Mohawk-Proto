import Mathlib
import Mathlib.Probability.Martingale.Basic
import Mathlib.Probability.Martingale.Convergence

namespace LeanFormalization

/-!
# Robbins-Siegmund Supermartingale Convergence (Gap 3)
-/

section RobbinsSiegmundGap

variable {Ω : Type*} {m : MeasurableSpace Ω}

structure RobbinsSiegmundHypothesis (V : ℕ → ℚ) (a b : ℕ → ℚ) where
  hV_nonneg : ∀ t, 0 ≤ V t
  ha_nonneg : ∀ t, 0 ≤ a t
  hb_nonneg : ∀ t, 0 ≤ b t
  ha_le_one : ∀ t, a t ≤ 1
  envelope : ∀ t, (1 - a t) * V t + b t ≥ 0

theorem robbins_siegmund_telescoping (V a b : ℕ → ℚ)
    (henv : ∀ t, V (t + 1) ≤ (1 - a t) * V t + b t)
    (ha : ∀ t, 0 ≤ a t) (ha1 : ∀ t, a t ≤ 1)
    (hb : ∀ t, 0 ≤ b t) (hV : ∀ t, 0 ≤ V t)
    (T : ℕ) :
    V T ≤ V 0 + (Finset.range T).sum b := by
  induction T with
  | zero => simp
  | succ T ih =>
    have hstep := henv T
    have ha1T : a T ≤ 1 := ha1 T
    have hVT : 0 ≤ V T := hV T
    have hdecay : (1 - a T) * V T ≤ V T := by
      have h1a : 0 ≤ 1 - a T := by linarith [ha1T]
      nlinarith [h1a, hVT, ha T]
    calc
      V (T + 1) ≤ (1 - a T) * V T + b T := hstep
      _ ≤ V T + b T := by linarith [hdecay]
      _ ≤ V 0 + (Finset.range T).sum b + b T := by linarith [ih]
      _ = V 0 + (Finset.range (T + 1)).sum b := by
        rw [Finset.sum_range_succ]
        ring

theorem robbins_siegmund_weighted_sum_bound (V a b : ℕ → ℚ)
    (henv : ∀ t, V (t + 1) ≤ (1 - a t) * V t + b t)
    (ha : ∀ t, 0 ≤ a t) (ha1 : ∀ t, a t ≤ 1)
    (hb : ∀ t, 0 ≤ b t) (hV : ∀ t, 0 ≤ V t)
    (T : ℕ) :
    (Finset.range T).sum (fun t => a t * V t) ≤ V 0 + (Finset.range T).sum b := by
  have hterm : ∀ t, a t * V t ≤ V t - V (t + 1) + b t := by
    intro t
    linarith [henv t]
  calc
    (Finset.range T).sum (fun t => a t * V t)
      ≤ (Finset.range T).sum (fun t => V t - V (t + 1) + b t) := by
        apply Finset.sum_le_sum
        intro t _
        exact hterm t
    _ = (Finset.range T).sum (fun t => V t - V (t + 1)) +
        (Finset.range T).sum b := by
      rw [Finset.sum_add_distrib]
    _ = (V 0 - V T) + (Finset.range T).sum b := by
      have htel : (Finset.range T).sum (fun t => V t - V (t + 1)) = V 0 - V T := by
        have heq : V T = V 0 + (Finset.range T).sum (fun t => V (t + 1) - V t) :=
          Finset.eq_sum_range_sub V T
        linarith [heq]
      rw [htel]
    _ ≤ V 0 + (Finset.range T).sum b := by
      linarith [hV T]

theorem robbins_siegmund_concrete_guard :
    (0 : ℚ) ≤ (1 : ℚ) / 32 := by
  norm_num

end RobbinsSiegmundGap

end LeanFormalization
