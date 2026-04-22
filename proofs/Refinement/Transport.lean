import Specification.Communication

namespace Refinement

open Specification


def transportSpecBytes (swarm : Swarm) : Nat :=
  communicationUpperBound swarm


def transportImplBytes (swarm : Swarm) : Nat :=
  totalBytes (hierarchicalProtocol swarm)


theorem transport_impl_bounded (swarm : Swarm) :
    transportImplBytes swarm <= transportSpecBytes swarm := by
  simpa [transportImplBytes, transportSpecBytes] using communication_bound swarm

end Refinement
