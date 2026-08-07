# Claim Transition Log

Append-only record of every change to a `Status` column value in
[`FORMAL_TRACEABILITY_MATRIX.md`](FORMAL_TRACEABILITY_MATRIX.md) (both its
main table and its Workstream 4 table). This is the audit/sign-off
mechanism for Phase 4 of the Formal Verification Completion effort: a
claim's Status can move for good reasons (a `sorry` closed for real, a
vacuous theorem replaced, a gap honestly demoted and documented) or bad
ones (quietly inflating or weakening a claim without explanation), and
this log is what lets a reviewer tell the two apart without re-deriving
the whole history from `git blame`.

## How this is enforced

`scripts/ci/check_claim_transitions.py`, run as part of the
`full-validation-fast` required status check, diffs every row's `Status`
column between `origin/main` and the PR's working tree. Any row whose
`Status` changed must have a matching **new** heading added to this file
in the same PR -- "new" specifically, so a generic entry can't be
pre-seeded once and silently reused to wave through unrelated later
changes. The check fails the PR otherwise.

## Entry format

```
## <date> -- Row <id> (<claim short name>): <old status> -> <new status>

<1-3 sentences: what changed and why. Can point back to the matrix row's
own Notes column for the full technical reasoning -- this log exists to
record THAT a transition happened and its headline direction, not to
duplicate the matrix's detailed rationale.>

- **PR:** #<number>
```

`<id>` must exactly match that row's first-column value in the matrix
(`1`-`15` for the main table, `Theorem7`/`Theorem8` for the Workstream 4
table). The `<old status> -> <new status>` text does not need to be
character-for-character identical to the matrix cells (the checker only
requires the heading to exist and reference the right row id) but should
accurately summarize the real transition.

## Log

### 2026-08-04 -- Row 2 (RDP composition): closed adaptive composition

`surrogate_verified_with_gaussian_axiom; core composition closed for
independent mechanisms (adaptive composition out of scope)` ->
`surrogate_verified_with_gaussian_axiom; core composition closed for both
independent and adaptive mechanisms`

Closed the "adaptive composition ... out of scope" gap for real with
`RDP_adaptive_composition`, using the corrected uniform-bound formulation
(Mironov 2017, Prop. 1) after the originally-cited expectation-based chain
rule turned out not to be a valid Rényi-divergence identity. See the
matrix row's own Notes for the full derivation.

- **PR:** #145

---

*Entries above this line are backfilled for historical context (this log
did not exist yet when they landed) and were not machine-enforced at the
time. Enforcement via `check_claim_transitions.py` begins with the PR
that introduced this file.*
