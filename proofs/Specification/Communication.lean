import Specification.System

namespace Specification


def hierarchicalProtocol (_swarm : Swarm) : List Message :=
  []


def communicationUpperBound (swarm : Swarm) : Nat :=
  swarm.dimension * (swarm.nodes.length + 1) * 4


theorem communication_bound (swarm : Swarm) :
    totalBytes (hierarchicalProtocol swarm) <= communicationUpperBound swarm := by
  -- TODO(machine-validation): Model the concrete protocol message schedule and
  -- prove the byte complexity bound from that model.
  sorry

end Specification
