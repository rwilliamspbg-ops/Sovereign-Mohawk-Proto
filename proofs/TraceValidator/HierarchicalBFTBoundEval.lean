import LeanFormalization.Theorem1BFT

/-!
# Hierarchical BFT Statistical Sanity-Check: Bound Evaluator (Technique B)

**This is not verification.** `chernoff_hierarchical_bound` (and its
deployment-scale instance `chernoff_hierarchical_bound_deployment_scale`)
is a probability bound over a *distribution* of random committee
samplings -- a single execution, or even many executions, is a set of
draws from that distribution, not a proof that the distribution's tail is
bounded the way `chernoff_hierarchical_bound`'s own machine-checked proof
already establishes. What this file does is evaluate the *already-proven*
bound at fixed, CI-feasible parameters and compare it against an empirical
failure rate `test/hbft_statistical_sanity_test.go` measures by running
many independent trials -- a regression tripwire (did something change
the simulator's independence/labeling assumptions badly enough that the
empirical rate now exceeds a bound that's supposed to hold), not a
machine-checked confirmation that the bound itself is correct (it already
is, via `chernoff_hierarchical_bound`'s own proof) or that any specific
deployment scenario is safe.

**Not the deployment-scale parameters.** `chernoff_hierarchical_bound_
deployment_scale` uses T=200 committees of c=50,000 nodes -- not
CI-feasible for repeated empirical trials (`MultiKrumSelect`-adjacent
combinatorics are polynomial in committee size, and this needs thousands
of trials). The toy-scale parameters below are chosen so the true failure
probability is small but not so astronomically small that thousands of
trials would trivially observe zero failures either way (which would make
the "sanity check" numerically meaningless, unable to actually catch a
regression). This means the comparison below corroborates the *same bound
formula* at parameters CI can run, not the specific 200x50,000 figure the
traceability matrix cites for deployment scale -- do not conflate the two
when reading results.

**Matches the bound's literal statement, not the trace validator's
`RootSafe`.** `Technique A` (`TraceValidator/HierarchicalBFT.lean`)
checks a *weighted-credit* bookkeeping rule (`HTree.safe`) that is known
to diverge from raw per-committee Byzantine counts
(`hierarchical_composition_counterexample`). `chernoff_hierarchical_bound`
is about something more direct: the probability that *any* one of `T`
committees' *realized* Byzantine count reaches a threshold `k` at all,
with no weighted-credit mechanism involved. `test/hbft_statistical_
sanity_test.go` deliberately measures that literal event (a fresh, minimal
trial generator, not `internal/hbft.Simulator`), so this comparison is
apples to apples with what the theorem actually states.

Usage: `hbft_statcheck_bound_eval <failures> <trials>` -- both natural
numbers, as reported by the matching Go trial run.
-/

open LeanFormalization

/-! ## Toy-scale parameters (must match test/hbft_statistical_sanity_test.go exactly) -/

def toyCommittees : Nat := 12          -- T
def toyCommitteeSize : Nat := 27       -- c
def toyFailureThreshold : Nat := 14    -- k (majority-breaking threshold for c=27)
def toyByzantineRate : Rat := 3 / 10   -- p
def toyChernoffBase : Rat := 5 / 2     -- z (>= 1 required by chernoff_hierarchical_bound)

/-- The RHS of `chernoff_hierarchical_bound` at the toy-scale parameters:
a proven upper bound on the probability that any of `toyCommittees`
committees' realized Byzantine count reaches `toyFailureThreshold`. Reuses
`chernoffBoundZ` -- the exact function `chernoff_hierarchical_bound`'s own
proof is stated and proved in terms of -- not a re-derivation. -/
def toyBoundRHS : Rat :=
  (toyCommittees : Rat) * chernoffBoundZ toyCommitteeSize toyFailureThreshold toyByzantineRate toyChernoffBase

def main (args : List String) : IO Unit := do
  match args with
  | [failuresStr, trialsStr] =>
      match failuresStr.toNat?, trialsStr.toNat? with
      | some failures, some trials =>
          if trials = 0 then
            IO.eprintln "trials must be positive"
            IO.Process.exit 2
          let empirical : Rat := (failures : Rat) / (trials : Rat)
          IO.println s!"empirical failure rate: {failures}/{trials} = {empirical}"
          IO.println
            s!"chernoff_hierarchical_bound RHS at T={toyCommittees}, c={toyCommitteeSize}, k={toyFailureThreshold}, p={toyByzantineRate}, z={toyChernoffBase}: {toyBoundRHS}"
          if empirical ≤ toyBoundRHS then
            IO.println "OK (statistical sanity check only -- not a machine-checked proof; see this file's doc comment): empirical failure rate is within the proven Chernoff bound."
          else
            IO.eprintln
              s!"FAIL: empirical failure rate {empirical} exceeds the proven bound {toyBoundRHS} -- this should essentially never happen if the trial generator's independence/labeling assumptions match chernoff_hierarchical_bound's hypotheses. Investigate before dismissing as sampling noise."
            IO.Process.exit 1
      | _, _ =>
          IO.eprintln "usage: hbft_statcheck_bound_eval <failures> <trials> -- both must be natural numbers"
          IO.Process.exit 2
  | _ =>
      IO.eprintln "usage: hbft_statcheck_bound_eval <failures> <trials>"
      IO.Process.exit 2
