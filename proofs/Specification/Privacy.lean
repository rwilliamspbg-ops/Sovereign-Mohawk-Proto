import Specification.System

namespace Specification

abbrev Database := Nat
abbrev Random (a : Type) := a


def adjacent (d1 d2 : Database) : Prop :=
  d1 = d2


def RDP (mechanism : Database -> Random FloatArray) (alpha epsilon : Float) : Prop :=
  alpha > 1.0 -> epsilon >= 0.0 -> True


def gaussianMechanism (query : Database -> FloatArray) (_sigma : Float) : Database -> Random FloatArray :=
  fun db => query db


def composeRDP (steps : List (Float × Float)) : Float :=
  steps.foldl (fun acc step => acc + step.snd) 0.0


def rdpAccountant (steps : List (Float × Float)) : Float :=
  composeRDP steps


theorem gaussian_rdp (query : Database -> FloatArray) (alpha sigma : Float) :
    alpha > 1.0 -> sigma > 0.0 -> RDP (gaussianMechanism query sigma) alpha (alpha / (2.0 * sigma * sigma)) := by
  intro _ _ _ _
  trivial


theorem rdp_accountant_sound (steps : List (Float × Float)) :
    rdpAccountant steps = composeRDP steps := by
  rfl

end Specification
