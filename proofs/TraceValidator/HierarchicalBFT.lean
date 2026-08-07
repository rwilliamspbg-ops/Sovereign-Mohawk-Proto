import Lean.Data.Json
import Specification.System

/-!
# Hierarchical BFT Trace Validator (Technique A: structural replay)

Replays a JSONL execution trace of `internal/hbft.Simulator`
(`internal/hbft/trace.go`, `test/hbft_trace_test.go`) and checks two
things a live, dynamic trace can establish that
`internal/multikrum_lean_correspondence_test.go`'s four fixed vectors
(row 12 of `FORMAL_TRACEABILITY_MATRIX.md`) cannot:

1. **Independent selection replay.** For every `committee_selection`
   event, re-run Multi-Krum selection on the trace's recorded `Gradients`
   using `Specification.neighborScore` (unmodified — the exact scoring
   primitive `Specification.multiKrumSelectImpl` itself uses) and check
   the result matches Go's recorded `SelectedIdx` exactly, including
   order (both sides rank ascending by score with lower-index-wins
   tie-breaking, so this is a genuine list-equality check, not just a
   set comparison).
2. **Structural/bookkeeping replay.** Fold each committee's outcome into
   per-tier weighted-safety bookkeeping using the *same* credited-weight
   rule `proofs/LeanFormalization/Theorem1BFT.lean`'s `HTree.safe` states,
   and check the running totals against Go's recorded `tier_aggregate`
   values, then check the final `round_summary` verdict.

## Scope: what this file does NOT do

**Selection replay now uses the official, row-12-closing spec function.**
This file previously carried its own validator-scoped
`selectManyLowestScoring` (a generalization of `argmin?`'s single-winner
selection to `m` winners), built here because `multiKrumSelectImpl`
(`Specification/System.lean`) only ever returned a single gradient --
row 12's then-open "`m = 1` only" gap. That gap is now closed:
`Specification.multiKrumSelectManyImpl` is the official general-`m` spec
function (promoted from this file's original code), and
`proofs/Refinement/MultiKrum.lean`'s `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl`
proves it agrees with `multiKrumSelectImpl` exactly at `m = 1`. This file
now calls that official function directly instead of maintaining a
duplicate implementation.

**Does not say anything about global resilience.** `CommitteeOutcome`/
`TierAccumulator` reuse `HTree.safe`'s exact weighted-credit rule (same
formula, not a reinterpretation), applied to a trace's *realized* labels
instead of `HTree`'s one fixed hand-built instance. This file passing
does **not** imply hierarchical resilience holds in general --
`hierarchical_composition_counterexample` already closed that question,
negatively, permanently, regardless of what any trace shows. This file
only checks that the mechanism's bookkeeping was computed correctly from
the realized inputs.

**Does not touch the Chernoff tail bound.** `chernoff_hierarchical_bound`
(`proofs/LeanFormalization/Theorem4ChernoffBounds.lean`) is a probability
bound over a distribution of random committee samplings; a single trace
is one draw from that distribution and cannot confirm or refute a tail
probability. See the statistical sanity-check (Technique B, a separate,
explicitly non-machine-checked effort) for the empirical-only complement.

Usage: `hbft_trace_validator <path-to-trace.jsonl>`
-/

open Lean Specification

namespace TraceValidator

/-! ## Structural bookkeeping (reuses HTree.safe's rule, see module doc) -/

structure CommitteeOutcome where
  committeeId  : String
  tierId       : Nat
  memberLabels : List Bool
  selectedIdx  : List Nat

def CommitteeOutcome.byzantineCount (c : CommitteeOutcome) : Nat :=
  (c.memberLabels.filter id).length

def CommitteeOutcome.total (c : CommitteeOutcome) : Nat := c.memberLabels.length

/-- Same weighted-majority rule `Theorem1BFT.lean`'s `HTree.safe` states,
applied to one committee's own realized labels. -/
def CommitteeOutcome.locallySafe (c : CommitteeOutcome) : Bool :=
  decide (2 * (c.total - c.byzantineCount) > c.total)

structure TierAccumulator where
  totalLeaves     : Nat := 0
  byzantineLeaves : Nat := 0
  safeLeafWeight  : Nat := 0

def TierAccumulator.absorb (acc : TierAccumulator) (c : CommitteeOutcome) : TierAccumulator :=
  { totalLeaves     := acc.totalLeaves + c.total
  , byzantineLeaves := acc.byzantineLeaves + c.byzantineCount
  , safeLeafWeight  := acc.safeLeafWeight + (if c.locallySafe then c.total else 0) }

def getTierAcc (accs : List (Nat × TierAccumulator)) (tierId : Nat) : TierAccumulator :=
  match accs.find? (fun p => p.1 = tierId) with
  | some (_, acc) => acc
  | none => {}

def setTierAcc (accs : List (Nat × TierAccumulator)) (tierId : Nat) (acc : TierAccumulator) :
    List (Nat × TierAccumulator) :=
  (tierId, acc) :: accs.filter (fun p => p.1 ≠ tierId)

/-! ## JSON field extraction -/

def getStrField (j : Json) (field : String) : Except String String :=
  (j.getObjValD field).getStr?

def getNatField (j : Json) (field : String) : Except String Nat :=
  (j.getObjValD field).getNat?

def getBoolField (j : Json) (field : String) : Except String Bool :=
  (j.getObjValD field).getBool?

def getFloatField (j : Json) : Except String Float := do
  let n ← j.getNum?
  pure n.toFloat

def getBoolArrayField (j : Json) (field : String) : Except String (List Bool) := do
  let arr ← (j.getObjValD field).getArr?
  arr.toList.mapM Json.getBool?

def getNatArrayField (j : Json) (field : String) : Except String (List Nat) := do
  let arr ← (j.getObjValD field).getArr?
  arr.toList.mapM Json.getNat?

def getFloatMatrixField (j : Json) (field : String) : Except String (List (List Float)) := do
  let arr ← (j.getObjValD field).getArr?
  arr.toList.mapM (fun row => do
    let rowArr ← row.getArr?
    rowArr.toList.mapM getFloatField)

/-! ## Replay driver -/

structure ValidatorState where
  lineNo            : Nat := 0
  pendingCommittee  : Option (String × Nat × List Bool) := none
  tierAccumulators  : List (Nat × TierAccumulator) := []
  checkedCommittees : Nat := 0
  checkedTiers      : Nat := 0
  checkedRounds     : Nat := 0

/-- Print a diagnostic and exit nonzero. Polymorphic return type, same
pattern as `TraceValidator/RDPAccountant.lean`'s `fail`. -/
def fail (state : ValidatorState) (msg : String) : IO α := do
  IO.eprintln s!"line {state.lineNo}: {msg}"
  IO.Process.exit 1

def step (state : ValidatorState) (j : Json) : IO ValidatorState := do
  let event ← match getStrField j "event" with
    | .ok e => pure e
    | .error e => fail state s!"missing/invalid 'event' field: {e}"
  match event with
  | "round_start" =>
      pure { state with tierAccumulators := [], pendingCommittee := none }
  | "committee_formed" =>
      let cid ← match getStrField j "committee_id" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'committee_id': {e}"
      let tierId ← match getNatField j "tier_id" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'tier_id': {e}"
      let labels ← match getBoolArrayField j "member_labels" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'member_labels': {e}"
      pure { state with pendingCommittee := some (cid, tierId, labels) }
  | "committee_selection" =>
      let (pendingCid, pendingTier, labels) ← match state.pendingCommittee with
        | some p => pure p
        | none => fail state "committee_selection with no preceding committee_formed"
      let cid ← match getStrField j "committee_id" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'committee_id': {e}"
      if cid ≠ pendingCid then
        fail state s!"committee_selection committee_id {cid} doesn't match pending committee_formed {pendingCid}"
      let tierId ← match getNatField j "tier_id" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'tier_id': {e}"
      if tierId ≠ pendingTier then
        fail state s!"committee_selection tier_id {tierId} doesn't match pending committee_formed tier_id {pendingTier}"
      let byzF ← match getNatField j "byzantine_f" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'byzantine_f': {e}"
      let gradients ← match getFloatMatrixField j "gradients" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'gradients': {e}"
      let goSelected ← match getNatArrayField j "selected_idx" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'selected_idx': {e}"
      let locallySafeGo ← match getBoolField j "locally_safe" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'locally_safe': {e}"
      if gradients.length ≠ labels.length then
        fail state s!"committee {cid}: gradients length {gradients.length} != member_labels length {labels.length}"
      if gradients.length ≤ 2 * byzF + 2 then
        fail state s!"committee {cid}: gradients length {gradients.length} violates MultiKrumSelect's n > 2f+2 precondition at f={byzF}"
      let neighbors := gradients.length - byzF - 2
      -- Ground-truth labels/id are irrelevant to selection (Go's MultiKrumSelect
      -- is label-blind, matching multiKrumSelectManyImpl's own signature, which
      -- ignores Node.id/Node.isByzantine entirely); placeholders here.
      let nodes : List Node := gradients.map (fun g => ⟨0, g, false⟩)
      let mySelected := multiKrumSelectManyImpl nodes neighbors neighbors
      if mySelected ≠ goSelected then
        fail state
          s!"committee {cid}: selection mismatch -- replayed multiKrumSelectManyImpl = {mySelected}, trace recorded selected_idx = {goSelected}"
      let outcome : CommitteeOutcome :=
        { committeeId := cid, tierId := tierId, memberLabels := labels, selectedIdx := goSelected }
      if outcome.locallySafe ≠ locallySafeGo then
        fail state
          s!"committee {cid}: locally_safe mismatch -- replayed = {outcome.locallySafe}, trace recorded = {locallySafeGo}"
      let acc := (getTierAcc state.tierAccumulators tierId).absorb outcome
      pure { state with
        tierAccumulators := setTierAcc state.tierAccumulators tierId acc
        pendingCommittee := none
        checkedCommittees := state.checkedCommittees + 1 }
  | "tier_aggregate" =>
      let tierId ← match getNatField j "tier_id" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'tier_id': {e}"
      let totalLeaves ← match getNatField j "total_leaves" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'total_leaves': {e}"
      let byzantineLeaves ← match getNatField j "byzantine_leaves" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'byzantine_leaves': {e}"
      let safeLeafWeight ← match getNatField j "safe_leaf_weight" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'safe_leaf_weight': {e}"
      let acc := getTierAcc state.tierAccumulators tierId
      if acc.totalLeaves ≠ totalLeaves ∨ acc.byzantineLeaves ≠ byzantineLeaves ∨ acc.safeLeafWeight ≠ safeLeafWeight then
        fail state
          s!"tier {tierId}: tier_aggregate mismatch -- replayed (total={acc.totalLeaves}, byzantine={acc.byzantineLeaves}, safeWeight={acc.safeLeafWeight}), trace recorded (total={totalLeaves}, byzantine={byzantineLeaves}, safeWeight={safeLeafWeight})"
      pure { state with checkedTiers := state.checkedTiers + 1 }
  | "round_summary" =>
      let rootSafeGo ← match getBoolField j "root_safe" with
        | .ok v => pure v
        | .error e => fail state s!"invalid 'root_safe': {e}"
      let myRootSafe := state.tierAccumulators.all (fun p => decide (2 * p.2.safeLeafWeight > p.2.totalLeaves))
      if myRootSafe ≠ rootSafeGo then
        fail state s!"round_summary mismatch: replayed root_safe = {myRootSafe}, trace recorded = {rootSafeGo}"
      pure { state with checkedRounds := state.checkedRounds + 1 }
  | other => fail state s!"unknown event type: {other}"

partial def run (path : System.FilePath) : IO Unit := do
  let contents ← IO.FS.readFile path
  let lines := (contents.splitOn "\n").filter (fun l => !l.trimAscii.isEmpty)
  if lines.isEmpty then
    IO.eprintln s!"trace file {path} contained no events"
    IO.Process.exit 1
  let mut state : ValidatorState := {}
  for line in lines do
    state := { state with lineNo := state.lineNo + 1 }
    match Json.parse line with
    | .error e => fail state s!"JSON parse error: {e}"
    | .ok j =>
        state ← step state j
  IO.println
    s!"OK: {state.checkedCommittees} committee_selection event(s), {state.checkedTiers} tier_aggregate event(s), {state.checkedRounds} round_summary event(s), all matched the independent Lean replay exactly."

end TraceValidator

def main (args : List String) : IO Unit := do
  match args with
  | [path] => TraceValidator.run path
  | _ =>
      IO.eprintln "usage: hbft_trace_validator <path-to-trace.jsonl>"
      IO.Process.exit 2
