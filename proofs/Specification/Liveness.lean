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
    failureBound pDropout redundancy t >= 0.0 := by
  -- TODO(machine-validation): Show non-negativity and derive a tight liveness
  -- failure bound from the concrete dropout model.
  sorry

end Specification
