import Mathlib
import Specification.System

namespace Specification

/-- One message per node plus one coordinator broadcast, each carrying a
    `swarm.dimension`-length gradient serialized as 4-byte float32 elements
    (the same byte-width convention Go's gradient path uses — see
    `originalBytes := len(fp32) * 4` in `internal/pyapi/api.go`'s
    `CompressGradients`/`CompressGradientsZeroCopy`). This is the naive,
    uncompressed `O(dn)` baseline `communication.md` calls "Total bytes
    without compression" — distinct from the hierarchical `O(d log n)`
    path-depth claim formalized separately in `Theorem3Communication.lean`.
    Previously this returned `[]` unconditionally regardless of `swarm`,
    making `communication_bound` below vacuously true (LHS always `0`) and
    the whole module a stub with no real byte-count model at all — the same
    "found and fixed" pattern documented across this repo's other Refinement
    modules. `payload` is left `[]`: nothing in this codebase reads it, only
    `.size` (via `totalBytes`). -/
def hierarchicalProtocol (swarm : Swarm) : List Message :=
  (List.range (swarm.nodes.length + 1)).map (fun i =>
    ({ sender := i, payload := [], size := swarm.dimension * 4 } : Message))


def communicationUpperBound (swarm : Swarm) : Nat :=
  swarm.dimension * (swarm.nodes.length + 1) * 4


/-- Helper: summing constant-size messages over `List.range k` gives `k * s`. -/
theorem totalBytes_const_size (k s : Nat) :
    totalBytes ((List.range k).map (fun i => ({ sender := i, payload := [], size := s } : Message)))
      = k * s := by
  induction k with
  | zero => simp [totalBytes]
  | succ k ih =>
      rw [List.range_succ, List.map_append, List.map_cons, List.map_nil]
      simp only [totalBytes, List.foldl_append, List.foldl_cons, List.foldl_nil]
      unfold totalBytes at ih
      rw [ih]
      ring

/-- The naive protocol's total bytes is EXACTLY the naive `O(dn)` bound, not
    merely bounded by it — every message is used at full size, with no
    compression or slack. -/
theorem hierarchicalProtocol_totalBytes_eq (swarm : Swarm) :
    totalBytes (hierarchicalProtocol swarm) = communicationUpperBound swarm := by
  unfold hierarchicalProtocol communicationUpperBound
  rw [totalBytes_const_size]
  ring

theorem communication_bound (swarm : Swarm) :
    totalBytes (hierarchicalProtocol swarm) <= communicationUpperBound swarm := by
  rw [hierarchicalProtocol_totalBytes_eq]

end Specification
