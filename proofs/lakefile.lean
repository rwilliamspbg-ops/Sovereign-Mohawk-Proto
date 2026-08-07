import Lake
open Lake DSL

package lean_formalization where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.30.0-rc2"

-- Marked `@[default_target]` so the documented verification command
-- (`cd proofs && lake build`, see FORMAL_TRACEABILITY_MATRIX.md) actually
-- builds these libraries instead of silently building 0 jobs. Previously
-- none of the three had a default target, so a bare `lake build` reported
-- "Build completed successfully (0 jobs)" without type-checking anything.
@[default_target]
lean_lib LeanFormalization where

@[default_target]
lean_lib Specification where

@[default_target]
lean_lib Refinement where

-- TraceValidator/RDPAccountant.lean (PR 2 of the trace-based-runtime-
-- verification effort) is deliberately NOT declared as a `lean_exe`
-- target here. `Refinement.RDPAccountant` pulls in the unrestricted
-- `import Mathlib`, and a `lean_exe` needs the whole transitive import
-- closure natively compiled to object code for linking -- unlike a
-- `lean_lib`, which only needs `.olean` interface files. Attempting
-- `lake build` on a `lean_exe` here triggered ~16600 native Mathlib C
-- compilation steps (most of them entirely unrelated to RDPAccountant)
-- and did not finish in a reasonable time. Interpreted execution avoids
-- this entirely and reuses the same `.olean` cache the `lean_lib` targets
-- above already warm: `lake env lean --run TraceValidator/
-- RDPAccountant.lean <path-to-trace.jsonl>` -- see that file's usage
-- comment and the CI workflow that invokes it this way.
