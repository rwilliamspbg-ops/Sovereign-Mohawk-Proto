import Mathlib
import LeanFormalization.RenyiDivergenceBoundedRO

/-!
# Adaptive random-oracle queries: the forking bound is unchanged

`RenyiDivergenceBoundedRO.lean` proves `roForkProb qH Q ≥ (roAcceptProb qH Q)²`
for a **fixed-schedule** programmed random oracle, and states that adaptive
query histories are not modelled. This module models them and shows that
adaptivity alone does **not** degrade the bound.

## The model

A deterministic adaptive adversary is a schedule

    sched : Tape → (i : Fin qH) → (Fin (i:ℕ) → C) → Q

so the query input at step `i` may depend on the tape and on the answers to the
previous queries, but **only** on that prefix. Given a full answer vector
`a : Fin qH → C`, `adaptiveQueries` evaluates the schedule.

`adaptiveAcceptSet` is the induced accepting set on the *same* finite sample
space `Tape × (Fin qH → C)` that `RenyiDivergenceBoundedRO` uses, so
`roAcceptProb` of it is exactly the adversary's success probability.

## Result

`adaptiveQueries_prefix`: if two answer vectors agree before `j`, the
adversary's queries at every step up to and including `j` are identical. That
is precisely the property the forking rewind needs, and it holds because a
query depends only on the prefix. Consequently

    roForkProb qH (adaptiveAcceptSet qH accept) ≥ (adaptiveSuccess qH accept)²

with **no** `1/q_H` factor and no adaptivity penalty.

## Why this does not recover the Pointcheval–Stern `ε²/q_H`

The `1/q_H` in the classical forking lemma does **not** come from adaptivity.
It comes from the simulator having to guess *which* of the `q_H` queries is the
forgery's own hash query: the extraction needs the two runs to share the forgery
message and differ at the query that computes its challenge. Modelling that
needs (a) identifying the forgery's query index from the transcript and (b) a
bad-event bound for runs whose forgery message was never queried. Neither is
modelled here, and `nonprefix_queries_break_fork` shows the prefix-dependence
itself is load-bearing.

**Scope note on the target.** The classical forking loss is `ε² − ε/N` with
`N` the challenge-space size (rows 31-32); Bellare–Neven's generalised form is
`ε·(ε/Q − 1/h)` for `Q` queries and challenge-space size `h`. An earlier
revision of `RenyiDivergenceBoundedRO.lean`'s docstring wrote `ε² − ε/q_H`,
conflating the query count with the challenge-space size; it is corrected in
this change. Neither form is recovered here, and neither is made worse by
adaptivity.
-/

namespace LeanFormalization

open Finset

variable {u : Type*} {Tape C Q : Type u} [Fintype Tape] [Fintype C] [Nonempty C]
  [DecidableEq C] [Fintype Q] [DecidableEq Q]

/-- A deterministic adaptive query schedule: at step `i` the query input is a
    function of the tape and of the answers to the previous queries. -/
def AdaptiveSchedule (Tape C Q : Type u) (qH : ℕ) : Type u :=
  Tape → (i : Fin qH) → (Fin (i : ℕ) → C) → Q

/-- The query the adversary makes at step `i` when the oracle answers are `a`. -/
def adaptiveQueries (qH : ℕ) (sched : AdaptiveSchedule Tape C Q qH)
    (t : Tape) (a : Fin qH → C) : Fin qH → Q :=
  fun i => sched t i (roPrefix qH i a)

/-- The accepting answer vectors of an adaptive adversary: the same finite
    sample space `Fin qH → C` that the fixed-schedule model uses. -/
noncomputable def adaptiveAcceptSet (qH : ℕ) (accept : Tape → (Fin qH → C) → Bool) :
    Tape → Finset (Fin qH → C) :=
  fun t => Finset.univ.filter (fun a => accept t a)

/-- The adversary's success probability over the uniform tape and the uniform
    answer vector. -/
noncomputable def adaptiveSuccess (qH : ℕ) (accept : Tape → (Fin qH → C) → Bool) : ℚ :=
  roAcceptProb qH (adaptiveAcceptSet qH accept)

omit [Fintype C] [Nonempty C] [DecidableEq C] in
/-- Restricting an agreement before `j` to a shorter prefix. -/
theorem roPrefix_eq_of_roPrefix_eq {qH : ℕ} {i j : Fin qH} (hij : (i : ℕ) < (j : ℕ))
    {a a' : Fin qH → C} (h : roPrefix qH j a = roPrefix qH j a') :
    roPrefix qH i a = roPrefix qH i a' := by
  funext k
  have h' := congrFun h ⟨(k : ℕ), lt_trans k.isLt hij⟩
  simp only [roPrefix] at h' ⊢
  exact h'

/-- **Prefix lemma.** If two answer vectors agree before `j`, the adversary's
    queries at every step up to and including `j` are the same. This is exactly
    what the forking rewind needs, and it holds because a query depends only on
    the prefix of the answers. -/
theorem adaptiveQueries_prefix (qH : ℕ) (j : Fin qH) (sched : AdaptiveSchedule Tape C Q qH)
    (t : Tape) (a a' : Fin qH → C) (h : roPrefix qH j a = roPrefix qH j a') :
    ∀ i : Fin qH, (i : ℕ) < (j : ℕ) →
      adaptiveQueries qH sched t a i = adaptiveQueries qH sched t a' i := by
  intro i hi
  simp only [adaptiveQueries]
  congr 1
  exact roPrefix_eq_of_roPrefix_eq hi h

/-- The forking bound carries over to adaptive adversaries unchanged: their
    induced accepting set lives on the same finite sample space. -/
theorem adaptive_roForkProb_ge (qH : ℕ) (hqH : qH ≠ 0) [Nonempty Tape]
    (accept : Tape → (Fin qH → C) → Bool) :
    roForkProb qH (adaptiveAcceptSet qH accept) ≥ (adaptiveSuccess qH accept) ^ 2 := by
  have h := roForkProb_ge qH hqH (adaptiveAcceptSet qH accept)
  unfold adaptiveSuccess
  exact h

/-- A **non-causal** schedule: the query at step `i` may depend on the whole
    answer vector, so it is not an `AdaptiveSchedule`. -/
def NonCausalSchedule (Tape C Q : Type u) (qH : ℕ) : Type u :=
  Tape → (i : Fin qH) → (Fin qH → C) → Q

/-- The query a non-causal schedule makes at step `i`. -/
def nonCausalQueries (qH : ℕ) (sched : NonCausalSchedule Tape C Q qH)
    (t : Tape) (a : Fin qH → C) : Fin qH → Q :=
  fun i => sched t i a

/-- **Negative control**: prefix-dependence is load-bearing. A non-causal
    schedule that reads the answer at a *later* index breaks the rewind — two
    answer vectors agreeing before `j = 1` (i.e. at index 0) can still induce
    different queries at step 0. -/
theorem nonprefix_queries_break_fork :
    ∃ (sched : NonCausalSchedule PUnit Bool Bool 2) (a a' : Fin 2 → Bool),
      (roPrefix 2 1 a = roPrefix 2 1 a') ∧
      nonCausalQueries 2 sched () a 0 ≠ nonCausalQueries 2 sched () a' 0 := by
  refine ⟨fun _ _ a => a 1, ![false, false], ![false, true], ?_, ?_⟩
  · ext i
    fin_cases i
    simp [roPrefix]
  · simp [nonCausalQueries]

end LeanFormalization
