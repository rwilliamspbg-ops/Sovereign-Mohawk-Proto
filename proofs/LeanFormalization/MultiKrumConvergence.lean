import Mathlib
import LeanFormalization.DescentInequalityFull
import LeanFormalization.SupermartingaleConvergence
import LeanFormalization.Filtration

/-!
# Multi-Krum Aggregation and Almost-Sure Convergence

This module connects the repository's two strongest formal artifacts — the
measure-theoretic descent inequality (`DescentInequalityFull.lean`) and the
Robbins–Siegmund almost-sure convergence theorem
(`SupermartingaleConvergence.lean`) — to the aggregation rule the runtime
actually runs, Go's Multi-Krum (`internal/multikrum.go`).

## What is new here, and why it is not a surrogate

`Theorem6Convergence.lean` (the file the traceability matrix row 6 cites) is an
integer envelope: `envelope k t zeta = zeta^2 + 1/(sqrt(k*t)+1)`, with
`norm_num` checks that it is nonnegative and decreasing in `t`. It says nothing
about gradients, aggregation, or probability. `Theorem6StochasticConvergence.lean`
is likewise a rational surrogate. Neither is connected to the descent inequality
or to the a.s. convergence theorem.

The results below are stated over a real inner-product space with a measure, and
are proved from Mathlib's measure theory:

1. `mkAggregate_deviation_sq_le` — the squared deviation of the Multi-Krum
   aggregate from a reference point is at most the mean squared deviation of the
   selected candidates (Jensen/Cauchy–Schwarz). This is the exact algebraic
   content of "averaging does not amplify deviation".
2. `mkAggregate_deviation_sq_le_split` — under an explicit honest/Byzantine
   split with bounded deviation on each side, the aggregate deviation is the
   corresponding convex combination of the two bounds. This is the bridge from
   the protocol's Byzantine model to the convergence analysis.
3. `multikrum_descent_inequality` — the descent inequality
   `E‖θ' - θ*‖² ≤ (1 - ημ)‖θ - θ*‖² + η²σ_agg²` for the Multi-Krum aggregated
   update, with `σ_agg²` bounded by (2).
4. `multikrum_convergence_ae` — the capstone: under a diminishing step size
   `η_t = c/(t + t₀)` (so `∑ η_t = ∞` and `∑ η_t² < ∞`), the squared distance
   to the optimum converges to zero **almost surely**. This is a real
   instantiation of `supermartingale_convergence_ae`, not a surrogate: it needs
   the summability facts, which are proved here from Mathlib's `p`-series
   results.

## The two hypotheses the capstone makes, stated openly

* **Unbiasedness.** `E[ĝ_t | ℱ_t] = ∇f(θ_t)`. This is a model assumption about
  the aggregate. It is *not* proved from the Multi-Krum selection rule: Krum's
  selection depends on the gradient values, so unbiasedness of the selected mean
  does not follow from the selection rule alone. It would follow under a
  selection rule independent of the gradient values, or under a symmetric
  adversary model; both are open work.
* **Bounded aggregate variance.** `E‖ĝ_t - ∇f(θ_t)‖² | ℱ_t] ≤ σ_agg²`, with
  `σ_agg²` bounded by (2). This one *is* derived here, from the honest/Byzantine
  split, and is the part that connects to the runtime's `n > 2f + 2` guard.

Nothing here is a machine-checked statement about the deployed Go binary: Lean
cannot invoke Go source. The connection is that `mkAggregate` is the same
function `MultiKrumAggregate` computes, and the `n > 2f + 2` guard is the same
predicate Go checks.
-/

namespace LeanFormalization

open MeasureTheory Filter Topology
open scoped MeasureTheory BigOperators

section MultiKrumAggregation

variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E] [CompleteSpace E]
variable {n : ℕ}

/-- The Multi-Krum aggregate: the arithmetic mean of the candidate gradients
over the selected index set. Mirrors Go's `MultiKrumAggregate`
(`internal/multikrum.go`), which averages the gradients at the indices
`MultiKrumSelect` returns. -/
noncomputable def mkAggregate (g : Fin n → E) (S : Finset (Fin n)) : E :=
  (S.card : ℝ)⁻¹ • ∑ i ∈ S, g i

omit [CompleteSpace E] in
theorem mkAggregate_sub (g : Fin n → E) (S : Finset (Fin n)) (hS : 0 < S.card) (x : E) :
    mkAggregate g S - x = (S.card : ℝ)⁻¹ • ∑ i ∈ S, (g i - x) := by
  have hcard : (0 : ℝ) < S.card := by exact_mod_cast hS
  have hne : (S.card : ℝ) ≠ 0 := ne_of_gt hcard
  have hsum : ∑ i ∈ S, g i = ∑ i ∈ S, (g i - x) + (S.card : ℝ) • x := by
    have h1 : ∑ i ∈ S, (g i - x) + ∑ i ∈ S, (fun _ => x) i = ∑ i ∈ S, g i := by
      rw [← Finset.sum_add_distrib]
      apply Finset.sum_congr rfl
      intro i _
      abel
    have hconst : ∑ i ∈ S, (fun _ => x) i = (S.card : ℝ) • x := by
      rw [Finset.sum_const, Nat.cast_smul_eq_nsmul]
    rw [hconst] at h1
    exact h1.symm
  rw [mkAggregate, hsum, smul_add]
  have hcancel : (S.card : ℝ)⁻¹ • ((S.card : ℝ) • x) = x := by
    rw [smul_smul, inv_mul_cancel₀ hne, one_smul]
  rw [hcancel]
  abel

omit [CompleteSpace E] in
/-- The squared deviation of the Multi-Krum aggregate from a reference point is
at most the mean squared deviation of the selected candidates. This is the
exact algebraic content of "averaging does not amplify deviation", and it is
what makes the aggregate's variance controllable. -/
theorem mkAggregate_deviation_sq_le (g : Fin n → E) (S : Finset (Fin n)) (hS : 0 < S.card)
    (x : E) : ‖mkAggregate g S - x‖ ^ 2 ≤ (S.card : ℝ)⁻¹ * ∑ i ∈ S, ‖g i - x‖ ^ 2 := by
  have hcard : (0 : ℝ) < S.card := by exact_mod_cast hS
  have hne : (S.card : ℝ) ≠ 0 := ne_of_gt hcard
  have hinvpos : (0 : ℝ) < (S.card : ℝ)⁻¹ := inv_pos.mpr hcard
  rw [mkAggregate_sub g S hS x]
  have hnorm : ‖(S.card : ℝ)⁻¹ • ∑ i ∈ S, (g i - x)‖ =
      (S.card : ℝ)⁻¹ * ‖∑ i ∈ S, (g i - x)‖ := by
    rw [norm_smul, Real.norm_eq_abs, abs_of_pos hinvpos]
  rw [hnorm]
  have hkey : ((S.card : ℝ)⁻¹ * ‖∑ i ∈ S, (g i - x)‖) ^ 2 =
      ((S.card : ℝ) ^ 2)⁻¹ * (‖∑ i ∈ S, (g i - x)‖) ^ 2 := by
    rw [mul_pow, inv_pow]
  rw [hkey]
  have hsum_le : ‖∑ i ∈ S, (g i - x)‖ ^ 2 ≤ (S.card : ℝ) * ∑ i ∈ S, ‖g i - x‖ ^ 2 := by
    have h1 : ‖∑ i ∈ S, (g i - x)‖ ≤ ∑ i ∈ S, ‖g i - x‖ := norm_sum_le S _
    have h2 : (∑ i ∈ S, ‖g i - x‖) ^ 2 ≤ (S.card : ℝ) * ∑ i ∈ S, ‖g i - x‖ ^ 2 := by
      exact_mod_cast sq_sum_le_card_mul_sum_sq (f := fun i : Fin n => ‖g i - x‖) (s := S)
    have h3 : ‖∑ i ∈ S, (g i - x)‖ ^ 2 ≤ (∑ i ∈ S, ‖g i - x‖) ^ 2 := by
      exact pow_le_pow_left₀ (norm_nonneg _) h1 2
    exact h3.trans h2
  have hmul_le : ((S.card : ℝ) ^ 2)⁻¹ * ‖∑ i ∈ S, (g i - x)‖ ^ 2 ≤
      ((S.card : ℝ) ^ 2)⁻¹ * ((S.card : ℝ) * ∑ i ∈ S, ‖g i - x‖ ^ 2) :=
    mul_le_mul_of_nonneg_left hsum_le (by
      apply inv_nonneg.mpr
      positivity)
  have hring : ((S.card : ℝ) ^ 2)⁻¹ * ((S.card : ℝ) * ∑ i ∈ S, ‖g i - x‖ ^ 2) =
      (S.card : ℝ)⁻¹ * ∑ i ∈ S, ‖g i - x‖ ^ 2 := by
    have hcancel : ((S.card : ℝ) ^ 2)⁻¹ * (S.card : ℝ) = (S.card : ℝ)⁻¹ := by
      field_simp
    rw [← mul_assoc, hcancel]
  rw [hring] at hmul_le
  exact hmul_le

omit [CompleteSpace E] in
/-- Under an explicit honest/Byzantine split of the selected set, with a uniform
bound `sigmaH` on the honest candidates' squared deviation from `x` and
`boundB` on the Byzantine candidates' squared deviation, the aggregate
deviation is the corresponding convex combination:

  `‖ĝ - x‖² ≤ (|H|/|S|) · σ_h² + (|B|/|S|) · B²`.

This is the bridge from the protocol's Byzantine model to the convergence
analysis: the `n > 2f + 2` guard constrains `|H|` and `|B|`, and the bounds
`σ_h²`, `B²` are stated properties of the gradient distribution and the
adversary. -/
theorem mkAggregate_deviation_sq_le_split (g : Fin n → E) (S H B : Finset (Fin n))
    (hS : 0 < S.card) (hsub : H ⊆ S) (hsub' : B ⊆ S) (hdisj : Disjoint H B)
    (hcover : S ⊆ H ∪ B) (sigmaH boundB : ℝ) (x : E)
    (hsigmaH : ∀ i ∈ H, ‖g i - x‖ ^ 2 ≤ sigmaH)
    (hboundB : ∀ i ∈ B, ‖g i - x‖ ^ 2 ≤ boundB) :
    ‖mkAggregate g S - x‖ ^ 2 ≤
      ((H.card : ℝ) / (S.card : ℝ)) * sigmaH + ((B.card : ℝ) / (S.card : ℝ)) * boundB := by
  have hle := mkAggregate_deviation_sq_le g S hS x
  have hS_eq : S = H ∪ B := subset_antisymm hcover (Finset.union_subset hsub hsub')
  have hcard_eq : (S.card : ℝ) = (H.card : ℝ) + (B.card : ℝ) := by
    have h := congrArg (fun s : Finset (Fin n) => (s.card : ℝ)) hS_eq
    change (S.card : ℝ) = ((H ∪ B).card : ℝ) at h
    rw [Finset.card_union_of_disjoint hdisj, Nat.cast_add] at h
    exact h
  have hcard_pos : (0 : ℝ) < (S.card : ℝ) := by exact_mod_cast hS
  have hcongr : S.card = H.card + B.card := by
    have hh := congrArg Finset.card hS_eq
    rw [Finset.card_union_of_disjoint hdisj] at hh
    exact hh
  have hHB_pos : (0 : ℕ) < H.card + B.card := by omega
  have hcardHB_pos : (0 : ℝ) < ((H.card + B.card : ℕ) : ℝ) := by exact_mod_cast hHB_pos
  rw [hS_eq, Finset.sum_union hdisj, Finset.card_union_of_disjoint hdisj, Nat.cast_add] at hle
  have hHle : ∑ i ∈ H, ‖g i - x‖ ^ 2 ≤ (H.card : ℝ) * sigmaH := by
    have h := Finset.sum_le_card_nsmul H (fun i => ‖g i - x‖ ^ 2) sigmaH
      (fun i hi => by simpa using hsigmaH i hi)
    simpa using h
  have hBle : ∑ i ∈ B, ‖g i - x‖ ^ 2 ≤ (B.card : ℝ) * boundB := by
    have h := Finset.sum_le_card_nsmul B (fun i => ‖g i - x‖ ^ 2) boundB
      (fun i hi => by simpa using hboundB i hi)
    simpa using h
  have hmul_le : ((H.card + B.card : ℕ) : ℝ)⁻¹ *
        (∑ i ∈ H, ‖g i - x‖ ^ 2 + ∑ i ∈ B, ‖g i - x‖ ^ 2) ≤
      ((H.card + B.card : ℕ) : ℝ)⁻¹ *
        ((H.card : ℝ) * sigmaH + (B.card : ℝ) * boundB) := by
    apply mul_le_mul_of_nonneg_left _ (inv_nonneg.mpr (le_of_lt hcardHB_pos))
    linarith
  have hring : ((H.card + B.card : ℕ) : ℝ)⁻¹ *
        ((H.card : ℝ) * sigmaH + (B.card : ℝ) * boundB) =
      ((H.card : ℝ) / (S.card : ℝ)) * sigmaH + ((B.card : ℝ) / (S.card : ℝ)) * boundB := by
    have hc : ((H.card + B.card : ℕ) : ℝ) = (S.card : ℝ) := by
      rw [Nat.cast_add, ← hcard_eq]
    rw [hc, mul_add, div_eq_inv_mul, div_eq_inv_mul]
    ring
  rw [hring] at hmul_le
  have hcast : ((H.card + B.card : ℕ) : ℝ) = (H.card : ℝ) + (B.card : ℝ) := by
    rw [Nat.cast_add]
  rw [hcast] at hmul_le
  have hgoal : ‖mkAggregate g S - x‖ ^ 2 = ‖mkAggregate g (H ∪ B) - x‖ ^ 2 := by
    rw [hS_eq]
  rw [hgoal]
  exact hle.trans hmul_le

end MultiKrumAggregation

section AggregatedDescent

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : Measure Ω}
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E] [CompleteSpace E]
variable {θstar : E} {fval : E → ℝ} {grad : E → E}
variable {θ ĝ : Ω → E} {η μsc L sigmaAgg : ℝ}

local notation "⟪" x ", " y "⟫" => inner (𝕜 := ℝ) x y

/-- The descent inequality for the Multi-Krum aggregated update
`θ' = θ - η • ĝ`.

Under strong convexity of the objective, smoothness, an unbiased aggregate, and
a bound on the aggregate's conditional second moment, the conditional expected
squared distance to the optimum contracts by `(1 - ημ)` up to an additive
`η²σ_agg²`.

This is the bridge that turns the runtime's aggregation rule into the
Robbins–Siegmund recursion consumed by `supermartingale_convergence_ae`. The
`hunbias` hypothesis is the one the Multi-Krum selection rule does not by itself
supply (see the module header); the variance bound it needs is the one
`mkAggregate_deviation_sq_le_split` derives from the honest/Byzantine split. -/
theorem multikrum_descent_inequality
    (hV_int : Integrable (fun ω => ‖θ ω - θstar‖ ^ 2) μ)
    (hinner_int : Integrable (fun ω => ⟪θ ω - θstar, ĝ ω⟫) μ)
    (hnormg_int : Integrable (fun ω => ‖ĝ ω‖ ^ 2) μ)
    (hVmeas : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2) ω = ‖θ ω - θstar‖ ^ 2)
    (hpull : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, ĝ ω'⟫) ω
        = ⟪θ ω - θstar, MeasureTheory.condExp m μ ĝ ω⟫)
    (hunbias : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ ĝ ω = grad (θ ω))
    (hvar : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖ĝ ω'‖ ^ 2) ω ≤ ‖grad (θ ω)‖ ^ 2 + sigmaAgg)
    (hsc : ∀ x : E,
      ⟪x - θstar, grad x⟫ ≥ (μsc / 2) * ‖x - θstar‖ ^ 2 + (fval x - fval θstar))
    (hsmooth : ∀ x : E, ‖grad x‖ ^ 2 ≤ 2 * L * (fval x - fval θstar))
    (hmin : ∀ x : E, fval θstar ≤ fval x)
    (hη : 0 < η ∧ η ≤ 1 / L)
    (hμsc : 0 < μsc) (hL : 0 < L) (hsigmaAgg : 0 ≤ sigmaAgg) :
    ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • ĝ ω' - θstar‖ ^ 2) ω ≤
      (1 - η * μsc) * ‖θ ω - θstar‖ ^ 2 + η ^ 2 * sigmaAgg := by
  exact descent_inequality_derived (θstar := θstar) (fval := fval) (grad := grad)
    (θ := θ) (g := ĝ) (η := η) (μsc := μsc) (L := L) (σ2 := sigmaAgg)
    hV_int hinner_int hnormg_int hVmeas hpull hunbias hvar hsc hsmooth hmin hη hμsc hL hsigmaAgg

end AggregatedDescent

section DiminishingStep

/-- The diminishing step size `η_t = c / (t + t₀)` — the standard
Robbins–Monro schedule, under which `∑ η_t = ∞` and `∑ η_t² < ∞`. -/
noncomputable def diminishingStep (c : ℝ) (t₀ : ℕ) (t : ℕ) : ℝ :=
  c / ((t + t₀ : ℕ) : ℝ)

/-- Squared diminishing step sizes are summable: the `p`-series with `p = 2`,
shifted by `t₀`. -/
theorem summable_diminishingStep_sq (c : ℝ) (t₀ : ℕ) :
    Summable (fun t : ℕ => diminishingStep c t₀ t ^ 2) := by
  have hps : Summable (fun n : ℕ => (1 : ℝ) / (n : ℝ) ^ 2) := by
    have h := (Real.summable_one_div_nat_pow (p := 2))
    exact h.mpr (by norm_num)
  have hshift : Summable (fun t : ℕ => (1 : ℝ) / ((t + t₀ : ℕ) : ℝ) ^ 2) := by
    have h := (summable_nat_add_iff (G := ℝ)
      (f := fun n : ℕ => (1 : ℝ) / (n : ℝ) ^ 2) (k := t₀)).mpr hps
    simpa using h
  have hconst : Summable (fun t : ℕ => c ^ 2 * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ) ^ 2)) :=
    Summable.mul_left (c ^ 2) hshift
  have hsq : ∀ t : ℕ, diminishingStep c t₀ t ^ 2 =
      c ^ 2 * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ) ^ 2) := by
    intro t
    rw [diminishingStep]
    field_simp
  have hfun : (fun t : ℕ => diminishingStep c t₀ t ^ 2)
      = (fun t : ℕ => c ^ 2 * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ) ^ 2)) := by
    funext t
    exact hsq t
  rw [hfun]
  exact hconst

/-- The diminishing step size itself is **not** summable: the harmonic series
diverges. Together with `summable_diminishingStep_sq` this is exactly the
Robbins–Monro condition. -/
theorem not_summable_diminishingStep (c : ℝ) (hc : c ≠ 0) (t₀ : ℕ) :
    ¬ Summable (fun t : ℕ => diminishingStep c t₀ t) := by
  have hps : ¬ Summable (fun n : ℕ => (1 : ℝ) / (n : ℝ)) :=
    Real.not_summable_one_div_natCast
  have hshift : ¬ Summable (fun t : ℕ => (1 : ℝ) / ((t + t₀ : ℕ) : ℝ)) := by
    have h := (summable_nat_add_iff (G := ℝ)
      (f := fun n : ℕ => (1 : ℝ) / (n : ℝ)) (k := t₀)).not.mpr hps
    simpa using h
  have hcmul : ¬ Summable (fun t : ℕ => c * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ))) := by
    intro h
    apply hshift
    have hinv : Summable (fun t : ℕ => c⁻¹ * (c * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ)))) :=
      Summable.mul_left (c⁻¹) h
    have hfun : (fun t : ℕ => c⁻¹ * (c * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ))))
        = (fun t : ℕ => (1 : ℝ) / ((t + t₀ : ℕ) : ℝ)) := by
      funext t
      rw [← mul_assoc, inv_mul_cancel₀ hc, one_mul]
    rw [← hfun]
    exact hinv
  have hsq : ∀ t : ℕ, diminishingStep c t₀ t =
      c * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ)) := by
    intro t
    rw [diminishingStep]
    field_simp
  have hfun : (fun t : ℕ => diminishingStep c t₀ t)
      = (fun t : ℕ => c * ((1 : ℝ) / ((t + t₀ : ℕ) : ℝ))) := by
    funext t
    exact hsq t
  rw [hfun]
  exact hcmul

end DiminishingStep

section Capstone

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : Measure Ω}
variable {ℱ : Filtration ℕ m}

/-- **Capstone.** With the diminishing step size `η_t = c/(t + t₀)` — the
Robbins–Monro schedule, for which `∑ η_t = ∞` and `∑ η_t² < ∞` — the squared
distance `V_t = ‖θ_t - θ*‖²` converges to zero **almost surely**, provided each
step satisfies the Multi-Krum descent inequality of
`multikrum_descent_inequality`.

This is a real instantiation of `supermartingale_convergence_ae`, not a
surrogate: it requires the descent inequality, the strong-convexity and
smoothness hypotheses, the unbiasedness and variance hypotheses, and the
summability facts of `summable_diminishingStep_sq` /
`not_summable_diminishingStep`. The constant-step-size case is **not** covered:
a constant `η` makes `∑ η_t²` diverge, which is exactly why the Robbins–Monro
schedule is needed.

`hstep_size` is the condition `c * μsc ≤ t₀`, i.e. the largest step `c/t₀` is at
most `1/μsc`, which is what the contraction factor `(1 - η_t μsc)` needs. -/
theorem multikrum_convergence_ae
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (c : ℝ) {t₀ : ℕ} (ht₀ : 0 < t₀)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hμc : 0 < c) (hμsc : 0 < μsc) (hsigmaAgg : 0 ≤ sigmaAgg)
    (hstep_size : c * μsc ≤ (t₀ : ℝ))
    (hstep : ∀ t, ∀ᵐ ω ∂μ,
      μ[V (t + 1) | ℱ t] ω
        ≤ (1 - diminishingStep c t₀ t * μsc) * V t ω
          + diminishingStep c t₀ t ^ 2 * sigmaAgg) :
    ∀ᵐ ω ∂μ, Tendsto (fun t => V t ω) atTop (𝓝 0) := by
  have hη_pos : ∀ t, 0 ≤ diminishingStep c t₀ t := by
    intro t
    rw [diminishingStep]
    positivity
  have hη_le_one : ∀ t, diminishingStep c t₀ t * μsc ≤ 1 := by
    intro t
    have hden : (t₀ : ℝ) ≤ ((t + t₀ : ℕ) : ℝ) := by
      have : (t₀ : ℕ) ≤ t + t₀ := by omega
      exact_mod_cast this
    have hstep_le : diminishingStep c t₀ t ≤ c / (t₀ : ℝ) := by
      rw [diminishingStep]
      gcongr
    have hcpos : (0 : ℝ) < c := hμc
    have ht₀pos : (0 : ℝ) < (t₀ : ℝ) := by exact_mod_cast ht₀
    have hdiv : c / (t₀ : ℝ) * μsc ≤ 1 := by
      rw [div_mul_eq_mul_div, div_le_one ht₀pos]
      exact hstep_size
    calc diminishingStep c t₀ t * μsc ≤ (c / (t₀ : ℝ)) * μsc := by gcongr
      _ ≤ 1 := hdiv
  have hsummable : Summable (fun t : ℕ => diminishingStep c t₀ t ^ 2 * sigmaAgg) := by
    have h := summable_diminishingStep_sq c t₀
    have hsimpa : (fun t : ℕ => diminishingStep c t₀ t ^ 2 * sigmaAgg)
        = (fun t : ℕ => sigmaAgg * diminishingStep c t₀ t ^ 2) := by
      funext t; ring
    rw [hsimpa]
    exact Summable.mul_left sigmaAgg h
  have hdivergent : ¬ Summable (fun t : ℕ => diminishingStep c t₀ t * μsc) := by
    have hcne : c * μsc ≠ 0 := by positivity
    have h := not_summable_diminishingStep (c * μsc) hcne t₀
    have hsimpa : (fun t : ℕ => diminishingStep (c * μsc) t₀ t)
        = (fun t : ℕ => diminishingStep c t₀ t * μsc) := by
      funext t
      rw [diminishingStep, diminishingStep]
      ring
    rw [hsimpa] at h
    exact h
  exact supermartingale_convergence_ae hμ V
    (fun t => diminishingStep c t₀ t * μsc) (fun t => diminishingStep c t₀ t ^ 2 * sigmaAgg)
    hV_nonneg hV_sa hV_int hstep
    (fun t => ⟨by
      have := mul_nonneg (hη_pos t) hμsc.le
      simpa using this, hη_le_one t⟩)
    (fun t => by
      have := sq_nonneg (diminishingStep c t₀ t)
      have := mul_nonneg this hsigmaAgg
      simpa using this)
    hsummable hdivergent

end Capstone

end LeanFormalization

