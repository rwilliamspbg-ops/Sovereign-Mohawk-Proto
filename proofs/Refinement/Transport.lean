import Specification.Communication

/-!
# Transport Refinement: Lean Spec ↔ Go Byte-Size Convention

This module documents the correspondence between `Specification.hierarchicalProtocol`
/`communicationUpperBound` (the naive, uncompressed `O(dn)` total-bytes model —
see `Specification/Communication.lean` for why this is a *different*, orphaned
claim from the hierarchical `O(d log n)` path-depth claim in
`LeanFormalization/Theorem3Communication.lean`) and Go's actual gradient
byte-size convention.

## Narrower scope than the other Refinement modules

Unlike `Refinement/MultiKrum.lean` and `Refinement/RDPAccountant.lean`, there
is no single Go function that computes "total bytes sent in one FedAvg
round" end-to-end — gradient serialization happens per-node, across a cgo
FFI boundary (`CompressGradients`/`CompressGradientsZeroCopy` in
`internal/pyapi/api.go`, `//export`-annotated for Python/C callers, not
directly invocable as a plain Go function from a test). So this row's
correspondence claim is narrower and formula-level, not an end-to-end
empirical match: it grounds the "4 bytes per dimension element" constant
`communicationUpperBound` bakes in against the literal formula Go actually
uses (`originalBytes := len(fp32) * 4` — the same line appears at
`internal/pyapi/api.go:830` and `:891`), via `test/transport_byte_size_test.go`.
That test also confirms the "4" is not an arbitrary literal on either side:
`unsafe.Sizeof(float32(0))` is `4` by the IEEE-754 single-precision format
both languages target, not a coincidence of matching magic numbers.

## What was fixed here

`Specification.hierarchicalProtocol` previously returned `[]`
unconditionally regardless of `swarm` — a stub, not a real model. That made
`Specification.communication_bound` (and therefore `transport_impl_bounded`
below) vacuously true: `totalBytes [] = 0 ≤` anything nonnegative,
independent of the swarm's actual size or dimension. It is now a real
construction (one message per node plus one coordinator broadcast, each
sized `dimension * 4` bytes) with an exact-equality theorem, not just a
bound — see `Specification.hierarchicalProtocol_totalBytes_eq`.
-/

namespace Refinement

open Specification

def transportSpecBytes (swarm : Swarm) : Nat :=
  communicationUpperBound swarm


def transportImplBytes (swarm : Swarm) : Nat :=
  totalBytes (hierarchicalProtocol swarm)


/-- The naive protocol achieves its own bound exactly, with no slack — a
    strictly stronger and more informative fact than `transport_impl_bounded`
    below, now that `hierarchicalProtocol` is a real construction instead of
    a stub. -/
theorem transport_impl_exact (swarm : Swarm) :
    transportImplBytes swarm = transportSpecBytes swarm := by
  simpa [transportImplBytes, transportSpecBytes] using
    Specification.hierarchicalProtocol_totalBytes_eq swarm

theorem transport_impl_bounded (swarm : Swarm) :
    transportImplBytes swarm <= transportSpecBytes swarm := by
  simpa [transportImplBytes, transportSpecBytes] using communication_bound swarm

end Refinement
