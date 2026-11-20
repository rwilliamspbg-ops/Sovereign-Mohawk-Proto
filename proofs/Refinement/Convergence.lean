import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem6ConvergenceReals

namespace Refinement

/-!
# Convergence Refinement: Lean Spec ↔ Go Implementation

This module formalizes the correspondence between the Lean convergence
envelope (`Theorem6ConvergenceReals.convergence_envelope`) and Go's convergence
monitor (`internal/convergence.go`).

## Go correspondence

`internal/convergence.go`:
- `ConvergenceMonitor.EnvelopeBound(clients, rounds)`:
    if clients > 0 && rounds > 0: 1/(2*clients*rounds) + Heterogeneity
    else: Heterogeneity (floor)
- `EffectiveThreshold()`: Threshold + Heterogeneity
- `IsConverging(gradNorm)`: gradNorm <= EffectiveThreshold()

## What is proved here, and what was removed

The envelopes agree **exactly** when Go's `Heterogeneity` field is Lean's
`zeta^2` (`convergence_impl_refines_spec`), and the runtime guard's
`EffectiveThreshold` **is** the envelope when the configured `Threshold` is the
Lean `1/(2KT)` term (`effectiveThreshold_eq_envelope`). The degenerate-parameter
case is a genuine inequality: Go falls back to the heterogeneity floor while the
spec falls back to `0`, so the runtime guard is never stricter than the spec
(`convergence_impl_floor_ge_spec`).

**Removed as vacuous (2026-11-20).** A previous revision of
`convergence_impl_floor_ge_spec` stated `heterogeneity ≥ 0` with the hypothesis
`0 ≤ heterogeneity` and proved it by `exact hh` — a tautology that said nothing
about the runtime. It is replaced by the inequality above, which uses both the
non-positivity of a parameter and the non-negativity of the heterogeneity.
-/

/-- Spec (Lean) convergence envelope: 1/(2*K*T) + zeta^2 for positive
    params, 0 otherwise. Mirrors `convergence_envelope` in
    `Theorem6ConvergenceReals.lean`. -/
def convergenceSpecEnvelope (K T : ℕ) (zeta : ℚ) : ℚ :=
  if K > 0 ∧ T > 0 then 1 / (2 * (K : ℚ) * (T : ℚ)) + zeta ^ 2 else 0

/-- Impl (Go) convergence envelope: 1/(2*K*T) + heterogeneity for positive
    params, heterogeneity (floor) otherwise. Mirrors
    `ConvergenceMonitor.EnvelopeBound`. -/
def convergenceImplEnvelope (K T : ℕ) (heterogeneity : ℚ) : ℚ :=
  if K > 0 ∧ T > 0 then 1 / (2 * (K : ℚ) * (T : ℚ)) + heterogeneity
  else heterogeneity

/-- **The runtime guard is the envelope.** Go's `EffectiveThreshold` is
    `Threshold + Heterogeneity`; it coincides with `EnvelopeBound` exactly when
    the configured `Threshold` is the Lean `1/(2KT)` term. This is the semantic
    link between the guard the runtime actually applies (`IsConverging`) and the
    envelope the proof talks about. -/
theorem effectiveThreshold_eq_envelope (K T : ℕ) (threshold heterogeneity : ℚ)
    (hK : 0 < K) (hT : 0 < T)
    (hth : threshold = 1 / (2 * (K : ℚ) * (T : ℚ))) :
    threshold + heterogeneity = convergenceImplEnvelope K T heterogeneity := by
  unfold convergenceImplEnvelope
  rw [if_pos ⟨hK, hT⟩, hth]

/-- Refinement: when Go's heterogeneity field equals Lean's zeta^2, the two
    envelopes coincide for positive client/round counts. -/
theorem convergence_impl_refines_spec (K T : ℕ) (zeta heterogeneity : ℚ)
    (hhet : heterogeneity = zeta ^ 2) (hK : 0 < K) (hT : 0 < T) :
    convergenceImplEnvelope K T heterogeneity = convergenceSpecEnvelope K T zeta := by
  unfold convergenceImplEnvelope convergenceSpecEnvelope
  have hcond : K > 0 ∧ T > 0 := ⟨hK, hT⟩
  rw [if_pos hcond, if_pos hcond]
  rw [hhet]

/-- **The floor case, non-vacuously.** When either parameter is non-positive Go
    returns the heterogeneity floor while the spec returns `0`; for nonnegative
    heterogeneity the runtime guard is therefore never STRICTER than the spec's
    degenerate case. Both hypotheses are used: `hnp` to select the branches and
    `hh` for the inequality. -/
theorem convergence_impl_floor_ge_spec (K T : ℕ) (zeta heterogeneity : ℚ)
    (hh : 0 ≤ heterogeneity) (hnp : K ≤ 0 ∨ T ≤ 0) :
    convergenceImplEnvelope K T heterogeneity ≥ convergenceSpecEnvelope K T zeta := by
  unfold convergenceImplEnvelope convergenceSpecEnvelope
  have hnot : ¬ (K > 0 ∧ T > 0) := by
    rintro ⟨hK, hT⟩
    rcases hnp with h | h
    · have hK0 : K = 0 := Nat.eq_zero_of_le_zero h
      omega
    · have hT0 : T = 0 := Nat.eq_zero_of_le_zero h
      omega
  rw [if_neg hnot, if_neg hnot]
  exact hh

/-- **Negative control: the bridge hypothesis `heterogeneity = zeta^2` is
    load-bearing.** With `heterogeneity = 0`, `zeta = 1`, `K = T = 1` the Go
    envelope is `1/2` while the spec is `3/2`. -/
theorem convergence_refines_spec_hhet_needed :
    convergenceImplEnvelope 1 1 0 ≠ convergenceSpecEnvelope 1 1 1 := by
  unfold convergenceImplEnvelope convergenceSpecEnvelope
  norm_num

/-- **Negative control: the non-positivity hypothesis in the floor case is
    load-bearing.** With `K = T = 1` (both positive), `heterogeneity = 0` and
    `zeta = 1`, the Go envelope is `1/2` while the spec is `3/2`: the floor
    inequality FAILS without `hnp`, so the branch selection is what carries the
    theorem. -/
theorem convergence_floor_npos_needed :
    convergenceImplEnvelope 1 1 0 < convergenceSpecEnvelope 1 1 1 := by
  unfold convergenceImplEnvelope convergenceSpecEnvelope
  norm_num

/-- Conservativeness: the Go floor (heterogeneity) is ≥ the Lean fallback (0)
    for nonnegative heterogeneity. Stated as the envelope comparison, not as a
    bare arithmetic tautology. -/
theorem convergence_impl_floor_ge_zero (K T : ℕ) (heterogeneity : ℚ)
    (hh : 0 ≤ heterogeneity) (hnp : K ≤ 0 ∨ T ≤ 0) :
    convergenceImplEnvelope K T heterogeneity ≥ 0 := by
  unfold convergenceImplEnvelope
  have hnot : ¬ (K > 0 ∧ T > 0) := by
    rintro ⟨hK, hT⟩
    rcases hnp with h | h
    · have hK0 : K = 0 := Nat.eq_zero_of_le_zero h
      omega
    · have hT0 : T = 0 := Nat.eq_zero_of_le_zero h
      omega
  rw [if_neg hnot]
  exact hh

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
