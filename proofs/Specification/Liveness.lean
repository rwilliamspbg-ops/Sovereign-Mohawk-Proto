import Mathlib

namespace Specification

inductive SystemState where
  | healthy
  | degraded
  | failed


def transitionScore (pDropout : Float) : Nat → Float
  | 0 => 1.0
  | Nat.succ redundancy => pDropout * transitionScore pDropout redundancy


def failureBound (pDropout : Float) (redundancy t : Nat) : Float :=
  min (1.0 : Float) (Float.ofNat t * transitionScore pDropout redundancy)


theorem liveness_bound_refl (pDropout : Float) (redundancy t : Nat) :
    failureBound pDropout redundancy t = failureBound pDropout redundancy t := by
  rfl


theorem liveness_bound_le_one (pDropout : Float) (redundancy t : Nat) :
    failureBound pDropout redundancy t ≤ 1.0 := by
  unfold failureBound
  exact (min_le_left (1.0 : Float) (Float.ofNat t * transitionScore pDropout redundancy))

end Specification
