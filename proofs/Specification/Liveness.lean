namespace Specification

inductive SystemState where
  | healthy
  | degraded
  | failed


def transitionScore (pDropout : Float) (redundancy : Nat) : Float :=
  pDropout * Float.ofNat redundancy


def failureBound (pDropout : Float) (redundancy t : Nat) : Float :=
  transitionScore pDropout redundancy * Float.ofNat t


theorem liveness_bound_refl (pDropout : Float) (redundancy t : Nat) :
    failureBound pDropout redundancy t = failureBound pDropout redundancy t := by
  rfl

end Specification
