import Lake
open Lake DSL

package lean_formalization where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.30.0-rc2"

lean_lib LeanFormalization where

lean_lib Specification where
