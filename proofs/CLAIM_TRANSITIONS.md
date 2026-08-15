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
### <YYYY-MM-DD> -- Row <id> (<claim short name>): <short description>

`<old status>` -> `<new status>`

<1-3 sentences: what changed and why. Can point back to the matrix row's
own Notes column for the full technical reasoning -- this log exists to
record THAT a transition happened and its headline direction, not to
duplicate the matrix's detailed rationale.>

- **PR:** #<number>
```

`<id>` must exactly match that row's first-column value in the matrix
(`1`-`15` for the main table, `Theorem7`/`Theorem8` for the Workstream 4
table). The checker (`scripts/ci/check_claim_transitions.py`) only
requires a heading of any level starting with a real `YYYY-MM-DD` date and
mentioning `Row <id>` somewhere on that line -- a real date is what
distinguishes an actual entry from this template itself (which the
checker must NOT match; note the literal, non-date text `<YYYY-MM-DD>`
above). The `<old status>` / `<new status>` body text does not need to be
character-for-character identical to the matrix cells, but should
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

### 2026-08-07 -- Row 13 (RDP accountant refinement): added trace-based validation

`empirically_verified_ledger; conversion_gap_formalized_not_closed` ->
`empirically_verified_ledger; conversion_gap_formalized_not_closed;
check_budget_decision_empirically_validated_via_trace`

Additive, not a closure: `proofs/TraceValidator/RDPAccountant.lean` now
replays an arbitrary dynamic execution trace (not just the four fixed
vectors already covered) through `accountantImpl`, and separately checks
that every `CheckBudget` decision follows correctly from that exactly-
replayed ledger plus Go's own recorded conversion term. The conversion
formula itself (`Real.log`-based) remains outside what any executable can
check -- unchanged, still `formalized_not_closed`, per `rdpToApproxDP`/
`rdp_budget_conversion_shift`. See the matrix row's own Notes for the full
reasoning.

### 2026-08-07 -- Row 1 (hierarchical BFT): added structural trace validation

`fully_formalized (single-tier); compositional claim disproven
deterministically; probabilistic repair proved AND genuinely useful at
deployment scale (Phase 3, Chernoff bound)` ->
`fully_formalized (single-tier); compositional claim disproven
deterministically; probabilistic repair proved AND genuinely useful at
deployment scale (Phase 3, Chernoff bound);
hierarchical_bookkeeping_and_selection_replay_validated_via_trace
(structural only; does not confirm the Chernoff tail bound, see Notes)`

Additive, not a closure, and explicitly NOT the same tier of guarantee as
row 13's RDP trace validation: `proofs/TraceValidator/HierarchicalBFT.lean`
replays a real, dynamic multi-tier, multi-round hierarchical Multi-Krum
execution trace, independently re-running selection (new validator-scoped
code, not a change to `multiKrumSelectImpl` -- row 12's "m=1 only" gap
stays open) and checking committee/tier bookkeeping against the same
credited-weight rule `HTree.safe` already states. This says nothing about
global resilience (`hierarchical_composition_counterexample` already
closed that negatively and permanently) and nothing about the Chernoff
tail bound itself (a probability-distribution claim; a separate,
explicitly non-machine-checked statistical sanity-check is tracked for a
later pass, not to be confused with this structural guarantee). See the
matrix row's own Notes for the full reasoning.

- **PR:** #158 (PR 4 of 6 for trace-based runtime verification of row 1;
  PR 1: #155, PR 2: #156, PR 3: #157)

### 2026-08-07 -- Row 1 (hierarchical BFT): added statistical sanity-check (Technique B)

`fully_formalized (single-tier); compositional claim disproven
deterministically; probabilistic repair proved AND genuinely useful at
deployment scale (Phase 3, Chernoff bound);
hierarchical_bookkeeping_and_selection_replay_validated_via_trace
(structural only; does not confirm the Chernoff tail bound, see Notes)` ->
same, plus `chernoff_bound_statistical_sanity_check_added (empirical
regression tripwire at CI-feasible scale, NOT machine-checked
verification of the deployment-scale bound, see Notes)`

Additive, and explicitly a different, weaker kind of check than every
other transition in this log: this does not machine-check anything new.
`proofs/TraceValidator/HierarchicalBFTBoundEval.lean` evaluates the
already-proven `chernoff_hierarchical_bound` (no new theorems) at
CI-feasible toy-scale parameters and compares it against an empirical
failure rate from 5,000 independent trials of a minimal generator
matching the theorem's literal statement (raw per-committee Byzantine
counts, deliberately not the weighted-credit `HTree.safe` mechanism the
prior transition's trace validator checks). A representative run: 776/5000
empirical vs. a proven bound of ~0.733 -- consistent with a wide margin.
This is a regression tripwire, not a proof; the underlying bound was
already machine-checked before this PR and remains so regardless of any
run's empirical outcome. See the matrix row's own Notes for the full
reasoning and why this must not be confused with the structural
guarantee the previous transition added.

- **PR:** #159 (PR 5 of 6 for trace-based runtime verification of row 1;
  PR 1: #155, PR 2: #156, PR 3: #157, PR 4: #158) -- #159 was stacked on
  #158's branch and merged into that branch after #158 itself had already
  merged into `main`, so its content never actually reached `main`; #160
  re-targets the same commit directly at `main` and is the PR that
  actually landed this transition.

- **PR:** #154 (PR 3 of 3 for trace-based runtime verification; PR 1:
  #152, PR 2: #153)

### 2026-08-07 -- Row 12 (MultiKrum refinement): closed both documented gaps

`empirically_verified_scoped (m=1 only; precondition gap documented, not
closed)` -> `empirically_verified_general_m; precondition_envelope_closed`

Both gaps this row had left open since it was written are now closed,
additively -- `multiKrumSelectImpl` itself is unchanged, so the four
original pinned `m=1` Go correspondence vectors and `go_neighbors_valid`/
`go_neighbors_no_clamp` still hold exactly as before. Two new sibling
functions in `Specification/System.lean` close the gaps instead of
touching the existing tested function. **Precondition gap**:
`multiKrumSelectSafe` gates selection behind Go's exact `n > 2f+2` check;
`multiKrumSelectSafe_eq_impl`/`multiKrumSelectSafe_none_outside_envelope`
prove its accepted-input set now equals Go's safety envelope exactly (both
inclusion directions, not just the one `go_neighbors_valid` already
covered). **`m=1`-only gap**: `multiKrumSelectManyImpl` implements
general-`m` selection (promoted from `proofs/TraceValidator/
HierarchicalBFT.lean`'s validator-scoped `selectManyLowestScoring`, which
now calls this official function instead of duplicating it -- verified to
produce identical results on a fresh real trace before and after). Two new
pinned Go correspondence vectors (`m=2`, `m=3`) extend the empirical
Go-side evidence. Critically, `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl`
is a **real, machine-checked Lean theorem** proving the new function
agrees with `multiKrumSelectImpl` exactly at `m=1` -- not an `#eval`-pinned
vector, since both sides are Lean functions here (unlike the Go-facing
correspondence, which remains necessarily empirical). This needed a
genuine two-algorithm-correctness proof (`argminAux_spec` for the existing
`argmin?`'s loop-invariant correctness, `minFoldPair_spec` for the new
sort-based selection's structural correctness, unified via a shared
`IsMinIdx` characterization and its uniqueness lemma) and surfaced a real
finding along the way: Lean's `Float` type carries zero order axioms at
all (`floatSpec` is opaque with no asserted reflexivity, antisymmetry,
transitivity, or totality), and neither does Mathlib define any order
instance for it -- both confirmed by direct inspection, not assumed. The
proof therefore introduces this repository's **first proof-relevant axioms
beyond Mathlib's own foundations**: eight axioms in `Refinement/
MultiKrum.lean` stating real, restricted (non-NaN-scoped) facts about IEEE
754 double comparison, explicitly documented as a trust boundary rather
than presented as derived. See the matrix row's own Notes for the full
reasoning, including why the non-NaN restriction is load-bearing (an
unconditional reflexivity axiom would be observably false: `NaN <= NaN`
evaluates to `false`).

- **PR:** #162

### 2026-08-15 -- Row 13 (RDP accountant refinement): closed the (ε, δ)-DP conversion gap via a computable bound

`empirically_verified_ledger; conversion_gap_formalized_not_closed;
check_budget_decision_empirically_validated_via_trace` ->
`empirically_verified_ledger; conversion_bound_closed_via_computable_sandwich;
check_budget_decision_empirically_validated_via_trace`

Closed the "(ε, δ)-DP conversion... formalized separately, not closed" gap
for real, not by making `Real.log` computable (impossible) but by proving
a genuine two-sided *rational bound* on it. New file
`proofs/Refinement/RDPLogBound.lean`: `rdpLog_sandwich` bounds `Real.log x`
for any `x > 0` via a power-of-2 argument reduction `x = r·2^k`,
`r ∈ [1,2)`, combining Mathlib's own already-proven `Real.log_two_near_10`
(the `k·log 2` term) with the elementary near-1 inequalities
`Real.one_sub_inv_le_log_of_pos`/`Real.log_le_sub_one_of_pos` (the residual
`log r` term) -- deliberately not a Taylor-remainder bound, which is also
available in this pinned Mathlib but converges too slowly near the `[1,2)`
window's edge for this reduction. `rdpToApproxDP_bound` specializes to
`alpha=10` (Go's fixed production value) and connects directly to
`Refinement.rdpToApproxDP`. Concrete `#eval`-pinned instances at three
representative delta values (Go's `1e-5` default, plus `1e-3`/`1e-8`) are
checked against Go's actual `math.Log`-based `GetCurrentEpsilonRat()`
output in `test/rdp_conversion_bound_test.go`, all passing, with a
negative-control pass (not itself committed) confirming the test actually
discriminates a wrong bound. See the matrix row's own Notes for the full
technical reasoning, including the explicit precision tradeoff (a coarse
but real bound, chosen because this gap's use case -- a privacy-budget
safety-margin check -- doesn't need Taylor-level tightness).
