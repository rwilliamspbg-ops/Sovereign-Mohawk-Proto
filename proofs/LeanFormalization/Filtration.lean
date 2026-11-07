import Mathlib
import Mathlib.Probability.Process.Filtration
import Mathlib.Probability.Process.Adapted
import Mathlib.MeasureTheory.Function.ConditionalExpectation.Basic

namespace LeanFormalization

/-!
# Filtration and Conditional Expectation for Federated Training (Gap 1)

Machine-checked, measure-theoretic scaffolding for Theorem 6's stochastic
convergence: an increasing family of sub-σ-algebras `ℱ_t` (one per training
round) and conditional-expectation properties of the stochastic gradient.

This module stays at the *type/structure* level: it instantiates Mathlib's
`Filtration`, `StronglyAdapted`, and `condExp` so the convergence proofs in
`Theorem6MeasureTheoreticConvergence.lean` can be lifted from rational
surrogates to real measure spaces. Full derivation of the descent inequality
is Gap 3 (Robbins–Siegmund).
-/

section FiltrationGap

variable {Ω : Type*} {m : MeasurableSpace Ω}

/-- A federated training filtration: an increasing family of sub-σ-algebras
    `ℱ_0 ⊆ ℱ_1 ⊆ … ⊆ m`, one per round. Directly Mathlib's
    `MeasureTheory.Filtration`. -/
abbrev FederatedFiltration (ι : Type*) [Preorder ι] := MeasureTheory.Filtration ι m

/-- Monotonicity of the filtration (comes from the structure's `mono'`). -/
theorem federated_filtration_monotone {ι : Type*} [Preorder ι]
    (f : MeasureTheory.Filtration ι m) : ∀ a b, a ≤ b → f a ≤ f b :=
  fun a b h => f.mono' h

/-- Each `ℱ_t` is a sub-σ-algebra of the ambient `m`. -/
theorem federated_filtration_le {ι : Type*} [Preorder ι]
    (f : MeasureTheory.Filtration ι m) (i : ι) : f i ≤ m :=
  f.le' i

/-- A sequence of per-round stochastic gradients is strongly adapted to the
    filtration: each `g_t` is `ℱ_t`-strongly-measurable. -/
def GradientStronglyAdapted {E : Type*} [TopologicalSpace E]
    (f : MeasureTheory.Filtration ℕ m) (g : (i : ℕ) → Ω → E) : Prop :=
  MeasureTheory.StronglyAdapted f g

/-- Conditional expectation of the gradient given round-`t` history exists and
    is `ℱ_t`-strongly-measurable, provided the gradient is integrable. -/
theorem gradient_condExp_stronglyMeasurable
    {μ : MeasureTheory.Measure Ω}
    (f : MeasureTheory.Filtration ℕ m) (g : ℕ → Ω → ℝ)
    (n : ℕ) (hg : MeasureTheory.Integrable (g n) μ) :
    MeasureTheory.StronglyMeasurable (f n) (MeasureTheory.condExp (f n) μ (g n)) :=
  MeasureTheory.stronglyMeasurable_condExp (m₀ := m) (m := f n) (μ := μ) (f := g n)

/-- Unbiasedness structure: the conditional expectation of the stochastic
    gradient equals the full gradient. Recorded as a property of the noise
    distribution, to be discharged per noise model. -/
structure UnbiasedGradient (μ : MeasureTheory.Measure Ω)
    (f : MeasureTheory.Filtration ℕ m) where
  grad : ℕ → Ω → ℝ
  fullGrad : ℕ → ℝ
  integrable : ∀ n, MeasureTheory.Integrable (grad n) μ
  unbiased : ∀ n, MeasureTheory.condExp (f n) μ (grad n) =ᵐ[μ] (fun _ => fullGrad n)

end FiltrationGap

end LeanFormalization