import Lean.Data.Json
import Refinement.RDPAccountant

/-!
# RDP Accountant Trace Validator

Replays a JSONL execution trace of `internal.RDPAccountant` (recorded via
its `TraceSink`, see `internal/rdp_trace.go` and
`test/rdp_accountant_trace_test.go`) through the already-proven
`Specification.composeRDP` / `Refinement.accountantImpl` ledger model and
checks the two things a live trace can establish that the four fixed test
vectors cited in `FORMAL_TRACEABILITY_MATRIX.md` row 13 cannot:

1. The Lean ledger model matches Go's `TotalEpsilon` exactly across an
   arbitrary, dynamic sequence of `record_step`/`record_shard_step` calls
   (not just four pinned scenarios) — exact rational comparison, since
   both sides use exact rational arithmetic (`RatString()` on the Go side,
   `Rat` here).
2. Every `check_budget` event's recorded `budget_ok` is the correct
   conclusion from that same exact ledger value plus Go's own recorded
   conversion term, against `max_budget` — i.e. `CheckBudget` really was
   computed from the ledger this replay independently arrives at, not a
   stale or diverged one.

This does **not** independently re-derive Go's `log(1/δ)/(α-1)` conversion
term: `Real.log` is noncomputable in Lean, so that formula itself remains
outside what any executable can check — see `Refinement.rdpToApproxDP` /
`Refinement.rdp_budget_conversion_shift`, which formalize its *shape* and
properties, not a numeric value. `conversion_term` is taken from the trace
as Go's own value and used only to check internal consistency of the
recorded decision against the independently-replayed ledger, not to
validate the conversion formula itself.

Usage: `rdp_trace_validator <path-to-trace.jsonl>`
-/

open Lean Specification Refinement

namespace TraceValidator

/-- Parse a Go `big.Rat.RatString()` value (`"a"` or `"a/b"`, optional
leading `-`) into a `Rat`. `Rat.divInt` normalizes automatically, so no
coprimality/positivity proof obligations arise here. -/
def parseRat (s : String) : Except String Rat :=
  match s.splitOn "/" with
  | [n] =>
      match n.toInt? with
      | some num => .ok (Rat.divInt num 1)
      | none => .error s!"invalid integer literal: {s}"
  | [n, d] =>
      match n.toInt?, d.toInt? with
      | some num, some den => .ok (Rat.divInt num den)
      | _, _ => .error s!"invalid rational literal: {s}"
  | _ => .error s!"unexpected rational format: {s}"

def getStrField (j : Json) (field : String) : Except String String :=
  (j.getObjValD field).getStr?

def getBoolField (j : Json) (field : String) : Except String Bool :=
  (j.getObjValD field).getBool?

def getRatField (j : Json) (field : String) : Except String Rat := do
  let s ← getStrField j field
  parseRat s

/-- Running validator state: the flat list of every `record_step` /
`record_shard_step` epsilon seen so far, in trace order. Grouping into
shards vs. a flat sequence doesn't affect `accountantImpl`'s total (that's
exactly what `accountant_impl_append` proves), so a single flat list is
sufficient to replay the whole ledger. -/
structure ValidatorState where
  steps         : List Rat := []
  lineNo        : Nat := 0
  checkedRecords : Nat := 0
  checkedBudgets : Nat := 0

/-- Print a diagnostic and exit nonzero. Polymorphic return type: `main`
never returns from `IO.Process.exit`, so this can be used anywhere an
`IO α` is expected regardless of `α`. -/
def fail (state : ValidatorState) (msg : String) : IO α := do
  IO.eprintln s!"line {state.lineNo}: {msg}"
  IO.Process.exit 1

/-- Process one already-parsed JSON trace event, updating state or failing
loudly with a diagnostic on any mismatch. -/
def step (state : ValidatorState) (j : Json) : IO ValidatorState := do
  let event ← match getStrField j "event" with
    | .ok e => pure e
    | .error e => fail state s!"missing/invalid 'event' field: {e}"
  match event with
  | "record_step" | "record_shard_step" =>
      let eps ← match getRatField j "epsilon" with
        | .ok r => pure r
        | .error e => fail state s!"invalid 'epsilon': {e}"
      let want ← match getRatField j "cumulative_epsilon" with
        | .ok r => pure r
        | .error e => fail state s!"invalid 'cumulative_epsilon': {e}"
      let newSteps := state.steps ++ [eps]
      let got := accountantImpl newSteps
      if got ≠ want then
        fail state
          s!"ledger mismatch after {event}: accountantImpl replay = {repr got}, trace recorded cumulative_epsilon = {repr want}"
      pure { state with steps := newSteps, checkedRecords := state.checkedRecords + 1 }
  | "check_budget" =>
      let cumulative ← match getRatField j "cumulative_epsilon" with
        | .ok r => pure r
        | .error e => fail state s!"invalid 'cumulative_epsilon': {e}"
      let maxBudget ← match getRatField j "max_budget" with
        | .ok r => pure r
        | .error e => fail state s!"invalid 'max_budget': {e}"
      let conversion ← match getRatField j "conversion_term" with
        | .ok r => pure r
        | .error e => fail state s!"invalid 'conversion_term': {e}"
      let budgetOk ← match getBoolField j "budget_ok" with
        | .ok b => pure b
        | .error e => fail state s!"invalid 'budget_ok': {e}"
      -- Cross-check the trace's own recorded ledger snapshot against the
      -- independent replay before trusting it for the budget check below.
      let replayed := accountantImpl state.steps
      if replayed ≠ cumulative then
        fail state
          s!"check_budget's own recorded cumulative_epsilon ({repr cumulative}) disagrees with the ledger replayed from prior record events ({repr replayed})"
      let leanExceeds := decide (cumulative + conversion > maxBudget)
      -- budgetOk should be exactly (not leanExceeds); a match means they
      -- disagree.
      if leanExceeds = budgetOk then
        fail state
          s!"check_budget mismatch: cumulative_epsilon ({repr cumulative}) + conversion_term ({repr conversion}) vs max_budget ({repr maxBudget}) implies budget_ok = {!leanExceeds}, but trace recorded budget_ok = {budgetOk}"
      pure { state with checkedBudgets := state.checkedBudgets + 1 }
  | other => fail state s!"unknown event type: {other}"

/-- Read `path`, replay every JSONL line through `step`, and report a
summary on success (any failure exits nonzero from within `step`/`fail`
before this returns). -/
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
    s!"OK: {state.checkedRecords} record event(s), {state.checkedBudgets} check_budget event(s), all matched the Lean ledger replay exactly."

end TraceValidator

def main (args : List String) : IO Unit := do
  match args with
  | [path] => TraceValidator.run path
  | _ =>
      IO.eprintln "usage: rdp_trace_validator <path-to-trace.jsonl>"
      IO.Process.exit 2
