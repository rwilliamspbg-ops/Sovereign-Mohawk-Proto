import Mathlib
import Mathlib.MeasureTheory.MeasurableSpace.Basic
import Mathlib.MeasureTheory.Function.StronglyMeasurable.Basic

namespace LeanFormalization

/-!
# Measurability of Stochastic Gradient Noise (Gap 2)

Bridges custom noise distributions (client heterogeneity, adversarial dropouts)
into Mathlib's `Measurable`/`StronglyMeasurable` definitions. The key results are
composition lemmas: if the base gradient and the dropout mask are measurable,
then the masked (stochastic) gradient is measurable — for fixed parameters and
jointly in `(θ, ω)`.
-/

section MeasurabilityGap

variable {Ω Θ E : Type*} [MeasurableSpace Ω] [MeasurableSpace Θ] [MeasurableSpace E]
  [TopologicalSpace E]

/-- A stochastic gradient operator: `grad θ ω` is the gradient at parameters `θ`
    under noise draw `ω`. -/
def StochasticGradient (grad : Θ → Ω → E) : Θ → Ω → E := grad

/-- For fixed parameters `θ`, if `grad θ` is measurable in `ω`, then the
    stochastic gradient is measurable in the noise. -/
theorem stochastic_gradient_measurable_fixed
    (grad : Θ → Ω → E) (θ : Θ)
    (h : Measurable (grad θ)) :
    Measurable (StochasticGradient grad θ) :=
  h

/-- Joint measurability: if `grad` is jointly measurable in `(θ, ω)`, then the
    stochastic gradient is jointly measurable. -/
theorem stochastic_gradient_jointly_measurable
    (grad : Θ → Ω → E)
    (h : Measurable (Function.uncurry grad)) :
    Measurable (Function.uncurry (StochasticGradient grad)) :=
  h

/-- Dropout mask: a measurable Bernoulli indicator. -/
def DropoutMask (mask : Ω → Bool) : Prop := Measurable mask

/-- Masked gradient: applies the dropout mask to the base gradient, zeroing out
    dropped contributions. -/
def maskedGradient (grad : Θ → Ω → E) (mask : Ω → Bool)
    (zero : E) : Θ → Ω → E :=
  fun θ ω => if mask ω then grad θ ω else zero

/-- If `grad` is jointly measurable and `mask` is measurable, then the masked
    gradient is jointly measurable (via `Measurable.ite`). -/
theorem masked_gradient_jointly_measurable
    (grad : Θ → Ω → E) (mask : Ω → Bool) (zero : E)
    (hgrad : Measurable (Function.uncurry grad))
    (hmask : Measurable mask) :
    Measurable (Function.uncurry (maskedGradient grad mask zero)) := by
  -- The masked gradient is an if-then-else on a measurable predicate.
  -- `Measurable.ite` requires the predicate measurable and both branches
  -- measurable in `(θ, ω)`.
  have hpred : Measurable (fun p : Θ × Ω => mask p.2) :=
    hmask.comp measurable_snd
  have hthen : Measurable (fun p : Θ × Ω => grad p.1 p.2) := hgrad
  have helf : Measurable (fun _ : Θ × Ω => zero) := measurable_const
  exact Measurable.ite hpred hthen helf

/-- For fixed parameters, the masked gradient is measurable in `ω`. -/
theorem masked_gradient_measurable_fixed
    (grad : Θ → Ω → E) (mask : Ω → Bool) (zero : E) (θ : Θ)
    (hgrad : Measurable (grad θ)) (hmask : Measurable mask) :
    Measurable (fun ω => maskedGradient grad mask zero θ ω) := by
  have hpred : Measurable mask := hmask
  have hthen : Measurable (grad θ) := hgrad
  have helf : Measurable (fun _ : Ω => zero) := measurable_const
  exact Measurable.ite hpred hthen helf

/-- A PMF-based discrete noise distribution: any `PMF α` is a probability
    measure on a discrete (countable) type. Recorded as a type alias for
    downstream use (mirrors Theorem4ChernoffBounds.lean). -/
abbrev DiscreteNoise (α : Type*) [MeasurableSpace α] := PMF α

end MeasurabilityGap

end LeanFormalization