import Specification.System

namespace Specification


def countByzantine (nodes : List Node) : Nat :=
  (nodes.filter Node.isByzantine).length


def honestGradients (nodes : List Node) : List FloatArray :=
  (honestNodes nodes).map Node.gradient


def gradientDistance (a b : FloatArray) : Float :=
  sqDist a b


def multikrumRobustProperty (nodes : List Node) (k : Nat) : Prop :=
  countByzantine nodes < nodes.length ∧ multiKrumSelectImpl nodes k ≠ none


theorem multikrum_robustness_sanity (nodes : List Node) (k : Nat)
    (hByz : countByzantine nodes < nodes.length)
    (hSel : multiKrumSelectImpl nodes k ≠ none) :
    multikrumRobustProperty nodes k := by
  unfold multikrumRobustProperty
  exact And.intro hByz hSel

end Specification
