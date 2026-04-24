import Mathlib

namespace Specification

inductive SystemState where
  | healthy
  | degraded
  | failed


def transitionScore (pDropout : ℝ) : Nat → ℝ
  | 0 => 1.0
  | Nat.succ redundancy => pDropout * transitionScore pDropout redundancy


def failureBound (pDropout : ℝ) (redundancy t : Nat) : ℝ :=
  min (1.0 : ℝ) ((t : ℝ) * transitionScore pDropout redundancy)


theorem liveness_bound_refl (pDropout : ℝ) (redundancy t : Nat) :
    failureBound pDropout redundancy t = failureBound pDropout redundancy t := by
  rfl


theorem liveness_bound_le_one (pDropout : ℝ) (redundancy t : Nat) :
    failureBound pDropout redundancy t ≤ 1.0 := by
  unfold failureBound
  exact min_le_left _ _

end Specification
