import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem6ConvergenceReals

namespace Refinement

/-!
# Convergence Refinement: Lean Spec ↔ Go Implementation

This module documents and formalizes the correspondence between the Lean
convergence envelope (Theorem6ConvergenceReals.convergence_envelope) and
Go's convergence monitor (internal/convergence.go).

## Go correspondence

`internal/convergence.go`:
- `ConvergenceMonitor.EnvelopeBound(clients, rounds)`:
    if clients > 0 && rounds > 0: 1/(2*clients*rounds) + Heterogeneity
    else: Heterogeneity (floor)
- `EffectiveThreshold()`: Threshold + Heterogeneity
- `IsConverging(gradNorm)`: gradNorm <= EffectiveThreshold()

## Gap pinned

The Lean spec uses `zeta^2` (heterogeneity squared) while the Go monitor
stores `Heterogeneity` (ζ² directly) and adds it linearly. The refinement
holds when Go's `Heterogeneity` field equals Lean's `zeta^2`. The
non-positive parameter fallback differs: Go returns the heterogeneity floor,
Lean returns 0 — a documented gap.
-/

/-- Spec (Lean) convergence envelope: 1/(2*K*T) + zeta^2 for positive
    params, 0 otherwise. -/
def convergenceSpecEnvelope (K T : ℕ) (zeta : ℚ) : ℚ :=
  if K > 0 ∧ T > 0 then 1 / (2 * (K : ℚ) * (T : ℚ)) + zeta ^ 2 else 0

/-- Impl (Go) convergence envelope: 1/(2*K*T) + heterogeneity for positive
    params, heterogeneity (floor) otherwise. -/
def convergenceImplEnvelope (K T : ℕ) (heterogeneity : ℚ) : ℚ :=
  if K > 0 ∧ T > 0 then 1 / (2 * (K : ℚ) * (T : ℚ)) + heterogeneity
  else heterogeneity

/-- Refinement: when Go's heterogeneity field equals Lean's zeta^2, the two
    envelopes coincide for positive client/round counts. -/
theorem convergence_impl_refines_spec (K T : ℕ) (zeta heterogeneity : ℚ)
    (hhet : heterogeneity = zeta ^ 2) (hK : 0 < K) (hT : 0 < T) :
    convergenceImplEnvelope K T heterogeneity = convergenceSpecEnvelope K T zeta := by
  unfold convergenceImplEnvelope convergenceSpecEnvelope
  have hcond : K > 0 ∧ T > 0 := ⟨hK, hT⟩
  rw [if_pos hcond, if_pos hcond]
  rw [hhet]

/-- Conservativeness: the Go floor (heterogeneity) is ≥ the Lean fallback (0)
    for nonnegative heterogeneity, so the runtime guard is never below the
    spec's degenerate case. -/
theorem convergence_impl_floor_ge_spec (heterogeneity : ℚ) (hh : 0 ≤ heterogeneity) :
    heterogeneity ≥ (0 : ℚ) := hh

/-- Monotonicity in rounds: more rounds never increases the envelope. -/
theorem convergence_envelope_rounds_monotone (K : ℕ) (zeta : ℚ) (T1 T2 : ℕ)
    (hK : 0 < K) (hT1 : 0 < T1) (hT2 : 0 < T2) (hle : T1 ≤ T2) :
    convergenceSpecEnvelope K T2 zeta ≤ convergenceSpecEnvelope K T1 zeta := by
  unfold convergenceSpecEnvelope
  have hc1 : K > 0 ∧ T1 > 0 := ⟨hK, hT1⟩
  have hc2 : K > 0 ∧ T2 > 0 := ⟨hK, hT2⟩
  rw [if_pos hc1, if_pos hc2]
  have hKpos : 0 < (K : ℚ) := by positivity
  have hinv : 1 / (2 * (K : ℚ) * (T2 : ℚ)) ≤ 1 / (2 * (K : ℚ) * (T1 : ℚ)) := by
    apply div_le_div_of_nonneg_left (by norm_num : (0 : ℚ) ≤ 1)
    · positivity
    · have hmul : 2 * (K : ℚ) * (T1 : ℚ) ≤ 2 * (K : ℚ) * (T2 : ℚ) := by
        nlinarith [hKpos, (show (T1 : ℚ) ≤ (T2 : ℚ) from by exact_mod_cast hle)]
      exact hmul
  linarith [hinv]

end Refinement