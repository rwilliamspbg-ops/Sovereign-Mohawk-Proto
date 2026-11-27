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
proof therefore needed this repository's **first proof-relevant assumptions
beyond Mathlib's own foundations**: facts about IEEE 754 double comparison,
restricted (non-NaN-scoped), explicitly documented as a trust boundary rather
than presented as derived. **Update (PR #316): these are no longer `axiom`
declarations.** They were originally eight global axioms in
`Refinement/MultiKrum.lean`; they are now the `FloatOrderLaws` structure,
passed as an explicit hypothesis to each theorem that needs it, so the
development is axiom-free. The trust boundary itself is unchanged and remains
documented in the matrix row's own Notes, including why the non-NaN
restriction is load-bearing (an unconditional reflexivity law would be
observably false: `NaN <= NaN` evaluates to `false`).

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

- **PR:** #174

### 2026-11-07 -- Row 6 (Surrogate convergence envelope): status promoted to measure-theoretic verified (Gaps 1-3 scaffolding)

`surrogate_verified_with_cast_bridge` ->
`measure_theoretic_verified (Gaps 1-3 scaffolding)`

Closed the measure-theoretic scaffolding gaps behind Theorem 6: discrete
filtrations and conditional-expectation (Filtration.lean), strong
measurability of stochastic-gradient operators including masked/dropout
paths (Measurability.lean), and the Robbins-Siegmund telescoping core
(RobbinsSiegmund.lean). All modules machine-checked with no `sorry` and
wired into `LeanFormalization.lean`. The full descent-inequality derivation
from smoothness/convexity remains future work.

- **PR:** #278, #279, #280

### 2026-11-07 -- Row 11 (Real-valued convergence envelope): status promoted to measure-theoretic verified (Gaps 1-4 scaffolding)

`Surrogate verified` ->
`measure_theoretic_verified (Gaps 1-4 scaffolding)`

Extended Row 6's measure-theoretic scaffolding with the async refinement
bridge (Refinement/AsyncConvergence.lean, PR #276) including the
floating-point refinement guard, plus a Go property test
(internal/federation/async_refinement_test.go, PR #277). Gaps 1-4 now
all have machine-checked modules. Full measure-theoretic descent-inequality
derivation remains future work.

- **PR:** #276, #277

### 2026-11-07 -- Row 6/11 (Convergence): full measure-theoretic descent-inequality derivation landed (PR #281)

`measure_theoretic_verified (Gaps 1-3 scaffolding)` ->
`measure_theoretic_verified (Gaps 1-4 scaffolding + descent derivation)`

Closed the remaining "full measure-theoretic derivation of the descent
inequality" item: new module `LeanFormalization/DescentInequalityFull.lean`
proves `descent_inequality_derived` (and `sgd_step_expand`) from
smoothness (L), strong convexity (μ_sc), bounded variance (σ²) and step
size (η ≤ 1/L), with the measurability of V and the inner-product
pull-out recorded as explicit hypotheses (`hVmeas`, `hpull`), consistent
with the module's other regularity assumptions. All CI checks green
(Verify Formal Proofs run 42406701459). No `sorry`/`axiom`/`admit`.

- **PR:** #281

Remaining roadmap items (not in scope here): full supermartingale
convergence (Gap 3 capstone), floating-point refinement (Gap 4
deepening), Kani (Unix-only, blocked on Windows host), and the
ed25519 UF-CMA / Forking Lemma / MiMC collision axioms (separate track).

### 2026-11-20 -- Row 2 (RDP composition): the Gaussian bound is a witness, not an axiom

`surrogate_verified_with_gaussian_axiom; core composition closed for both independent and adaptive mechanisms` ->
`surrogate_verified_gaussian_witness; core composition closed for both independent and adaptive mechanisms`

`gaussianRDPBound` is a theorem, not an axiom: it exhibits a nonnegative
`eps = alpha/(2*sigma^2)` and does not derive the Gaussian mechanism's RDP
from the density. The old status, the row's Notes and the theorem's own
docstring all described it as an axiom / as "satisfies (alpha,
alpha/(2*sigma^2))-RDP", which misdescribed a standing gap as a settled
fact and cut against the repo-wide "Declared axioms: 0" claim. Renamed and
reworded; the derivation remains roadmap work.

- **PR:** #363

### 2026-11-21 -- Row 2 (RDP composition): the Gaussian RDP bound is derived, closing the existence-witness gap

`surrogate_verified_gaussian_witness; core composition closed for both independent and adaptive mechanisms` ->
`gaussian_rdp_derived; the integer/rational additive ledger remains a surrogate; core composition closed for both independent and adaptive mechanisms`

#373 (`LeanFormalization/RenyiDivergenceMeasure.lean`) defines the measure-theoretic Rényi divergence, proves the finite-support `RenyiDivergence` is exactly its counting-measure special case, and derives `D_α = α·Δ²/(2σ²)` unconditionally (only `σ ≠ 0`, `α ≠ 1`) from the **proved** completed-square integral `gaussianRDP_integral`. The existence witness `Theorem2RDP.gaussianRDPBound` is superseded, and `theorem_claims.json`'s `blocking_gaps` entry that called the derivation impossible in the then-current framework is rewritten to record what is actually still open: the multivariate mechanism, composition across rounds in the measure-theoretic framework, and the `(ε,δ)`-DP conversion.

This transition was previously **invisible to the gate**. Row 2 has been wrapped across physical lines since #366, and `check_claim_transitions.py` parsed physical lines, so the main table's parse stopped at its first wrapped row and only row 1 plus the Workstream 4 table were checked -- a Status change on rows 2-34 required no transition entry. The parser now rejoins wrapped rows (`logical_table_rows`), and `tests/scripts/ci/test_claim_transitions.py` pins that behaviour against the real matrix and against synthetic wrapped rows.

- **PR:** #375

### 2026-11-22 -- Row 38 (Ed25519 field bridge): `fInv` bridged; all five field operations closed

"fully_formalized for `fadd`/`fsub`/`fmul` and `fPow`; **`fInv` NOT bridged** (see notes)" -> "fully_formalized - all five field operations; the curve group law remains open"

`card_units_zmod` proves `Fintype.card (ZMod p)ˣ = p - 1` for prime `p` from
`Fintype.card_units` and `ZMod.card`; `zmod_pow_sub_one` derives `a ^ (p-1) = 1`
via Lagrange (`pow_card_eq_one`); and `fmul_fInv` concludes `fInv a * a = 1` for
`a` not divisible by `p`, carrying `Fact (Nat.Prime ed25519P)` explicitly. A local
`units_val_pow` supplies the power form of `Units.val` that Mathlib omits (it has
`Units.val_mul`). The remaining Ed25519 gap is the **curve group law**, which is not a
field question; see the row's Notes for the full reasoning.

- **PR:** #388

### 2026-11-23 -- Row 40 (Ed25519 affine addition law): new row, commutativity and identity proved

`(new row)` -> `group_law_partially_formalized`

Adds `LeanFormalization/Ed25519CurveGroupLaw.lean`, the first increment on row 26's assumed group laws. `affineAdd_comm`, `affineAdd_identity`, `affineAdd_identity_left` and `affineAdd_canonical` are proved about the real implementation; associativity and the four consumed scalar-multiplication laws remain open, so row 26's assumption bundle is unchanged. Both new hypotheses (`IsConsistent`, reduced coordinates) carry machine-checked counterexamples.

### 2026-11-23 -- Row 41 (adaptive random-oracle queries): new row, bound shown unchanged

`(new row)` -> `fully_formalized for adaptive query schedules; classical loss NOT recovered`

Adds `LeanFormalization/RenyiDivergenceAdaptiveRO.lean`. The prefix lemma shows an adaptive
adversary's queries up to the fork index depend only on the answer prefix, so its induced
accepting set lives on row 36's sample space and `roForkProb >= epsilon^2` carries over
unchanged. The classical `epsilon^2 - epsilon/N` loss is not recovered and is recorded as
the residual (it needs the forgery's own query index and a bad-event bound). Also corrects
the loss form previously quoted in row 36 and in `RenyiDivergenceBoundedRO.lean`'s docstring.

### 2026-11-23 -- Row 42 (Multi-Krum under adversarial clustering): new row

`(new row)` -> `fully_formalized for the split-Byzantine model; the clustering assumption remains`

Adds `LeanFormalization/KrumSelectionAdversarial.lean`. `krum_selection_safe` is generalised to an
explicit separated subset `Far`, and the infiltrators `Near` are bounded: a Krum minimizer is honest
or in `Near`, so Byzantine winners <= infiltrators. The separation hypothesis is machine-checked as
load-bearing by `krum_selection_separation_necessary`, and `krum_separation_margin` makes the
sufficient condition an explicit threshold.

### 2026-11-24 -- Row 46 (Ed25519 birational bridge): Montgomery -> Edwards direction proved

`bridge_partial` (change of variables proved; no group law inherited) -> `bridge_partial` (change of variables both ways proved; no group law inherited)

Adds `montgomeryToEdwards_edwards`: a Montgomery point `(u, v)` with `u + 1 != 0` and `Q(u) != 0`
maps back onto `-x^2 + y^2 = 1 + d*x^2*y^2`, where `Q(u) = (1+d)u^2 + 2(1-d)u + (1+d)`. Together
with #404's forward lemma this makes the two maps mutually inverse between the admissible loci.
No group law is inherited yet, so the headline status remains `bridge_partial`; the round-trip
composites, addition-law compatibility and denominator completeness stay explicitly unproved.

- **PR:** #405

### 2026-11-26 -- Row 46 (Ed25519 birational bridge): addition-law compatibility proved in row 47

`bridge_partial` (change of variables both ways proved; no group law inherited) -> `bridge_partial` (change of variables both ways proved; addition-law compatibility now proved in row 47; associativity conditional)

PR #429 proves the Edwards to Montgomery addition-law compatibility over an arbitrary field, including the x3 = 0 torsion case, and proves twisted-Edwards completeness under IsSquare (-1) plus nonsquare d. Row 46 itself still claims only the change of variables; its Status parenthetical now points at row 47 rather than denying the compatibility.

- **PR:** #429

### 2026-11-26 -- Row 47 (Edwards-Montgomery addition bridge): new row

`(new row)` -> `group_law_partially_formalized` (field-level compatibility, completeness and conditional associativity proved; concrete affineAdd associativity NOT proved)

Adds row 47 for the machine-checked Edwards to Montgomery addition bridge, twisted-Edwards completeness, the derived compatibility bundle, the conditional associativity theorem and the exact Nat/ZMod lifting statement for the concrete affineAdd. All nine changed theorems are axiom-free under #print axioms; concretely, affineAdd associativity remains an explicit gap.

- **PR:** #429

### 2026-11-26 -- Row 47 (Edwards-Montgomery addition bridge): concrete affineAdd associativity now conditional theorem

`group_law_partially_formalized` (field-level compatibility, completeness and conditional associativity proved; concrete affineAdd associativity NOT proved) -> `group_law_partially_formalized` (field-level compatibility, completeness and conditional associativity proved; concrete affineAdd associativity proved conditionally, not unconditionally)

PR #430 adds `affineAdd_associative_of_complete`, transporting the field associativity theorem through the Nat/ZMod coercion bridge. It also proves `IsSquare (-1)` from p % 4 = 1, removing one hypothesis. Unconditional associativity is still not claimed: the residual hypotheses are listed in the theorem statement.

- **PR:** #430

### 2026-11-27 -- Row 47 (Edwards-Montgomery addition bridge): base-field facts proved

`group_law_partially_formalized` (field-level compatibility, completeness and conditional associativity proved; concrete `affineAdd` associativity proved conditionally, not unconditionally) -> `group_law_partially_formalized` (base-field primality and nonsquareness now proved; concrete `affineAdd` associativity still conditionally proved)

`ed25519P_prime` is proved from a machine-checked Lucas/Pratt certificate over `ZMod ed25519P`, and `ed25519D_not_isSquare` from a kernel-checked Jacobi-symbol computation. Both are axiom-free. `affineAdd_associative_of_complete` no longer takes `Fact (Nat.Prime ed25519P)` or `¬ IsSquare ed25519D` as hypotheses. All other admissibility, on-curve, branch and distinctness hypotheses remain explicit; no unconditional group law is claimed.

- **PR:** #445
