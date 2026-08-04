# Quarantined Lean Files

Files here are **not part of any Lake build target** (`lean_lib` in
`proofs/lakefile.lean` covers only `LeanFormalization/`, `Specification/`,
and `Refinement/` — this directory is a sibling, deliberately outside all
three). They are not compiled by `lake build`, not checked by CI, and not
referenced by `proofs/FORMAL_TRACEABILITY_MATRIX.md` or any public claim in
`README.md` / the white paper.

They exist here (rather than being deleted outright) because the underlying
topics — exact Gaussian-mechanism RDP bounds, the moment accountant method —
are legitimate roadmap items for closing Theorem 2's open `sorry`s (see the
matrix's row 2 notes). Anyone picking that work up should treat these files
as a discarded first draft, not a starting point to import: each has a
specific, documented reason it doesn't establish what its name claims — see
the header comment in each file. Rewriting from the actual mathematical
definition of a Gaussian distribution (not the stand-ins used here) is
almost certainly less work than debugging what's here.

## Contents

- **`Theorem2RDP_GaussianRDP.lean`** — `gaussian_RDP_bound`'s statement
  compares `RenyiDivergence` between two *identical* constant functions
  (`fun _ => (1 : ℝ)`) rather than real Gaussian likelihoods.
  `GaussianMechanism` is defined as the identity function (`x`), per its own
  comment: "Simplified; in practice this would be `x + sample_from_gaussian(sigma)`."
  The theorem type-checks (when it compiles — see below) but establishes
  nothing about actual Gaussian mechanisms, contradicting the doc comment's
  claim that it's "used directly in Sovereign Mohawk's accountant."
- **`Theorem2RDP_MomentAccountant.lean`** — `moment_rdp_equivalence`
  concludes bare `True` (proved `by trivial`) despite a doc comment
  claiming it "shows the two methods are equivalent for privacy
  accounting" — the `rdp_budget`/`moment_budget` quantities it defines via
  `let` are never actually compared. This is the same vacuous-conclusion
  pattern documented in the traceability matrix's Theorem 3 row (True-stub
  theorems that `lake build` type-checks without proving anything).
  `moment_accountant_concentration`'s core inequality is discharged via
  `norm_num` over a chain of comments asserting a Chernoff-bound argument
  that isn't actually encoded as Lean hypotheses or Mathlib lemmas — worth
  independent scrutiny before ever treating it as established.

## How they got here

Both files were added to `proofs/LeanFormalization/` in an earlier phase
(referenced in now-archived docs under
`docs/archive/root-cleanup-2026-07/PHASE_3E_*` and `PHASE_3F_*`) but were
never imported by `LeanFormalization.lean` and never added to the
traceability matrix. Lake's default `lean_lib` glob compiles every `.lean`
file under a library's directory regardless of the import graph, so they
were silently built as part of `lake build LeanFormalization` — consuming
CI time and, to anyone browsing the tree, looking like checked, load-bearing
proofs — without ever being part of the actual claim surface. Moved out
during a Phase 0 (formal-verification claim hygiene) pass; see
`proofs/FORMAL_TRACEABILITY_MATRIX.md`'s "Quarantined Modules" section.
