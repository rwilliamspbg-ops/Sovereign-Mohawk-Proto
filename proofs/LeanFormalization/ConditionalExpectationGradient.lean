import Mathlib
import Mathlib.Probability.Process.Filtration
import Mathlib.MeasureTheory.Function.ConditionalExpectation.Basic
import LeanFormalization.Common
import LeanFormalization.Filtration

namespace LeanFormalization

/-!
# Conditional Expectation of the Stochastic Gradient (Gap 1, deliverable 2)

Companion to `Filtration.lean`: records the integrability and conditional-
expectation properties of the per-round stochastic gradient, and the
unbiasedness lemma `𝔼[g(θ_t, ξ_t) | ℱ_t] = ∇f(θ_t)`. The conditional
expectation is taken in Mathlib's `MeasureTheory.condExp`, reusing the
filtration from `Filtration.lean`.
-/

section ConditionalExpectationGradient

open scoped MeasureTheory

variable {Ω : Type*} {m : MeasurableSpace Ω}

/-- A conditional-gradient model over a probability space: per-round
    stochastic gradient, its integrability, and the resulting conditional
    expectation, which is `ℱ_t`-strongly-measurable. -/
structure ConditionalGradientModel (μ : MeasureTheory.Measure Ω)
    (f : MeasureTheory.Filtration ℕ m) where
  grad : ℕ → Ω → ℝ
  integrable : ∀ n, MeasureTheory.Integrable (grad n) μ
  condExpStronglyMeasurable :
    ∀ n, StronglyMeasurable[f n] (MeasureTheory.condExp (f n) μ (grad n))

/-- The conditional expectation of a conditional-gradient model's gradient. -/
def ConditionalGradientModel.condExp
    {μ : MeasureTheory.Measure Ω} {f : MeasureTheory.Filtration ℕ m}
    (M : ConditionalGradientModel μ f) (n : ℕ) : Ω → ℝ :=
  MeasureTheory.condExp (f n) μ (M.grad n)

/-- The conditional expectation is `ℱ_n`-strongly-measurable. -/
theorem ConditionalGradientModel.condExp_stronglyMeasurable
    {μ : MeasureTheory.Measure Ω} {f : MeasureTheory.Filtration ℕ m}
    (M : ConditionalGradientModel μ f) (n : ℕ) :
    StronglyMeasurable[f n] (M.condExp n) :=
  M.condExpStronglyMeasurable n

/-- Unbiasedness (reuses `UnbiasedGradient` from `Filtration.lean`): the
    conditional expectation of the stochastic gradient equals the full
    (deterministic) gradient almost everywhere. -/
theorem unbiased_conditional_gradient
    {μ : MeasureTheory.Measure Ω} {f : MeasureTheory.Filtration ℕ m}
    (M : UnbiasedGradient μ f) (n : ℕ) :
    MeasureTheory.condExp (f n) μ (M.grad n) =ᵐ[μ] (fun _ => M.fullGrad n) :=
  M.unbiased n

end ConditionalExpectationGradient

end LeanFormalization
