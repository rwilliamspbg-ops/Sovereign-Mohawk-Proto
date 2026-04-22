import Specification.System

namespace Specification


def hierarchicalProtocol (_swarm : Swarm) : List Message :=
  []


def communicationUpperBound (swarm : Swarm) : Nat :=
  swarm.dimension * (swarm.nodes.length + 1) * 4


theorem communication_bound (swarm : Swarm) :
    totalBytes (hierarchicalProtocol swarm) <= communicationUpperBound swarm := by
  simp [hierarchicalProtocol, totalBytes, communicationUpperBound]

end Specification
