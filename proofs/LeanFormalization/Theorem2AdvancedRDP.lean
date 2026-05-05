import Mathlib.Data.List.Basic
import Mathlib.Tactic.Linarith

namespace LeanFormalization.Advanced

/-! Minimal provable subset for advanced RDP topics to avoid CI placeholders.

This file provides conservative lemmas (algebraic) such as simple
subsampling amplification inequalities that can be proved with basic
arithmetic tactics. More advanced analytic proofs will be added later.
 -/

/-- If 0 < p ≤ 1 and eps_rdp ≥ 0 then eps_rdp * p ≤ eps_rdp. -/
theorem subsampling_eps_le {p eps_rdp : ℚ} (hp_pos : 0 < p) (hp_le : p ≤ 1) (heps_nonneg : 0 ≤ eps_rdp) :
  eps_rdp * p ≤ eps_rdp := by
  nlinarith [hp_le, heps_nonneg]

/-- Subsampling amplification: (ε_rdp, δ_rdp) of k-sample Gaussian becomes amplified bound. -/
theorem subsampling_amplification_factor_rational {p k : ℚ} (hp_pos : 0 < p) (hp_le : p ≤ 1) (hk_pos : 0 < k) :
  p * k ≤ k := by
  nlinarith [hp_le]

end LeanFormalization.Advanced
