import Specification.System

namespace Specification


def countByzantine (nodes : List Node) : Nat :=
  (nodes.filter Node.isByzantine).length


def honestGradients (nodes : List Node) : List FloatArray :=
  (honestNodes nodes).map Node.gradient


def gradientDistance (a b : FloatArray) : Float :=
  sqDist a b


def multikrumRobustProperty (nodes : List Node) (k : Nat) : Prop :=
  ∀ g,
    multiKrumSelectImpl nodes k = some g ->
      ∃ h, h ∈ honestGradients nodes ∧ g = h


theorem multikrum_robustness_sanity (nodes : List Node) (k : Nat) :
    multikrumRobustProperty nodes k := by
  -- TODO(machine-validation): Prove MultiKrum picks an honest gradient under
  -- the standard Byzantine threshold assumptions.
  sorry

end Specification
