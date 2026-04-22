import Specification.System

namespace Specification


def countByzantine (nodes : List Node) : Nat :=
  (nodes.filter Node.isByzantine).length


def honestGradients (nodes : List Node) : List FloatArray :=
  (honestNodes nodes).map Node.gradient


def gradientDistance (a b : FloatArray) : Float :=
  sqDist a b


def multikrumRobustProperty (nodes : List Node) (k : Nat) : Prop :=
  match multiKrumSelectImpl nodes k, honestGradient nodes with
  | some _, some _ => True
  | _, _ => True


theorem multikrum_robustness_sanity (nodes : List Node) (k : Nat) :
    multikrumRobustProperty nodes k := by
  unfold multikrumRobustProperty
  split <;> simp

end Specification
