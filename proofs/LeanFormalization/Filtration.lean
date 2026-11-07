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

variable {Ω : Type*} {m : MeasurableSpace Ω}

/-- A federated training filtration: an increasing family of sub-σ-algebras
    `ℱ_0 ⊆ ℱ_1 ⊆ … ⊆ m`, one per round. Directly Mathlib's
    `MeasureTheory.Filtration`. -/
abbrev FederatedFiltration (ι : Type*) [Preorder ι] := MeasureTheory.Filtration ι m

/-- Monotonicity of the filtration (comes from the structure's `mono'`). -/
theorem federated_filtration_monotone {ι : Type*} [Preorder ι]
    (f : FederatedFiltration ι) : Monotone f.seq :=
  f.mono'

/-- Each `ℱ_t` is a sub-σ-algebra of the ambient `m`. -/
theorem federated_filtration_le {ι : Type*} [Preorder ι]
    (f : FederatedFiltration ι) (i : ι) : f i ≤ m :=
  f.le' i

/-- A sequence of per-round stochastic gradients is strongly adapted to the
    filtration: each `g_t` is `ℱ_t`-strongly-measurable. -/
def GradientProcess (ι : Type*) [Preorder ι] (E : Type*) [TopologicalSpace E]
    (f : FederatedFiltration ι) :=
  { g : (i : ι) → Ω → E // MeasureTheory.StronglyAdapted f g }

/-- Conditional expectation of the gradient given round-`t` history exists and
    is `ℱ_t`-strongly-measurable, provided the gradient is integrable. -/
theorem gradient_condExp_stronglyMeasurable
    {μ : MeasureTheory.Measure Ω} {E : Type*} [TopologicalSpace E]
    [MeasurableSpace E] [BorelSpace E] [NormedAddCommGroup E]
    [NormedSpace ℝ E] [CompleteSpace E]
    (f : FederatedFiltration ℕ) (g : ℕ → Ω → E)
    (n : ℕ) (hg : MeasureTheory.Integrable (g n) μ) :
    MeasureTheory.StronglyMeasurable[f n] (μ[g n | f n]) :=
  MeasureTheory.stronglyMeasurable_condExp

/-- Unbiasedness statement (as a hypothesis): the conditional expectation of
    the stochastic gradient equals the full gradient. Recorded as a property of
    the noise distribution, to be discharged per noise model (i.i.d., dropout,
    etc.). -/
structure UnbiasedGradient (μ : MeasureTheory.Measure Ω) (f : FederatedFiltration ℕ)
    (g : ℕ → Ω → (Fin 1 → ℝ)) where
  fullGrad : ℕ → (Fin 1 → ℝ)
  unbiased : ∀ n, μ[g n | f n] =ᵐ[μ] (fun _ => fullGrad n)

end LeanFormalization