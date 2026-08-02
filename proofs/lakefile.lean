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
