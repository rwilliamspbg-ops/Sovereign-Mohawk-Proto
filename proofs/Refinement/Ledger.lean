import Mathlib

/-!
# Ledger Refinement: Lean Spec ↔ Go Implementation

This module documents and partially formalizes the correspondence between
`transferSpec`/`applyTransferEntry` (the Lean spec: an integer-balance
ledger with `List (Nat × Int)` account storage) and Go's
`Ledger.TransferWithControls` (`internal/token/ledger.go`).

## Mass conservation for valid transfers: real, machine-checked, and non-trivial

Unlike Go's `map[string]int64` (which *structurally* guarantees each
account key appears at most once), Lean's `List (Nat × Int)` representation
does not — nothing prevents the same account id from appearing twice, or an
account referenced by a transfer from being absent altogether.
`transferSum_conserves` proves total-balance conservation is real but
*conditional* on exactly the invariants Go's map type gets for free: the
account-id list has no duplicates (`Nodup`) and both `sender` and
`receiver` already appear in it. Proved via composing two single-key sum
lemmas (`sum_updateKey`), not asserted.

## Two gaps found and pinned as concrete counterexamples, not closed

1. **Absent accounts silently drop value.** If `sender` or `receiver` is
   not already present in `s.balances`, `applyTransferEntry`'s `List.map`
   leaves it untouched — no new entry is created, so the debit or credit
   is silently lost rather than erroring. Go's `map[string]int64` has no
   such failure mode: an absent key reads as its zero value and the
   mutation always applies. `transferSpec_absent_account_drops_value` is a
   concrete, machine-checked (`decide`) witness: transferring to a
   nonexistent account id measurably changes total balance.
2. **No balance-sufficiency check.** Go's `TransferWithControls` rejects
   the transfer outright (`insufficient balance in %q`, verified in
   `internal/token/ledger_lean_correspondence_test.go`) when
   `l.balances[from] < amountUnits`. `transferSpec` has no analogous guard
   at all — `transferSpec_permits_insufficient_balance` is a concrete
   witness where a sender with balance `10` is "transferred" `50`,
   producing balance `-40` rather than being rejected.

Both are real, previously undocumented gaps between what the Lean spec
permits and what Go's implementation actually allows — the Lean spec's
accepted-input set is strictly larger than Go's, in both dimensions.

## Go correspondence: exact match for the valid-transfer case

`internal/token/ledger_lean_correspondence_test.go` performs a real
`Ledger.Mint`/`TransferWithControls` sequence and checks `BalanceUnits`
against the same scenario computed via `transferSpec` here — exact integer
match, since both sides use exact integer arithmetic (Lean `Int`, Go
`int64` account units) once amounts are chosen to convert to whole units
with no floating-point rounding. It also directly exercises the
insufficient-balance rejection to confirm gap 2 above is real Go behavior,
not just documentation.
-/

namespace Refinement

structure LedgerState where
  balances : List (Nat × Int)


def totalBalance (entries : List (Nat × Int)) : Int :=
  entries.foldl (fun acc item => acc + item.snd) 0


def applyTransferEntry (sender receiver : Nat) (amount : Int) (entry : Nat × Int) : Nat × Int :=
  if entry.fst = sender then
    (entry.fst, entry.snd - amount)
  else if entry.fst = receiver then
    (entry.fst, entry.snd + amount)
  else
    entry


def transferSpec (sender receiver : Nat) (amount : Int) (s : LedgerState) : LedgerState :=
  if sender = receiver ∨ amount < 0 then
    s
  else
    { balances := s.balances.map (applyTransferEntry sender receiver amount) }


def transferImpl (sender receiver : Nat) (amount : Int) (s : LedgerState) : LedgerState :=
  transferSpec sender receiver amount s


theorem transfer_impl_refines_spec (sender receiver : Nat) (amount : Int) (s : LedgerState) :
    transferImpl sender receiver amount s = transferSpec sender receiver amount s := by
  rfl

/-- Update the value at exactly the entries matching key `k` by adding `d`. -/
def updateKey (k : Nat) (d : Int) (entry : Nat × Int) : Nat × Int :=
  if entry.fst = k then (entry.fst, entry.snd + d) else entry

/-- Given `k` appears exactly once (nodup + membership), updating by `d`
    changes the total sum by exactly `d`. -/
theorem sum_updateKey (k : Nat) (d : Int) (entries : List (Nat × Int))
    (h_nodup : (entries.map Prod.fst).Nodup)
    (h_mem : k ∈ entries.map Prod.fst) :
    ((entries.map (updateKey k d)).map Prod.snd).sum = (entries.map Prod.snd).sum + d := by
  induction entries with
  | nil => simp at h_mem
  | cons e es ih =>
      rw [List.map_cons] at h_mem
      rw [List.mem_cons] at h_mem
      rw [List.map_cons] at h_nodup
      rw [List.nodup_cons] at h_nodup
      obtain ⟨h_notin, h_nodup2⟩ := h_nodup
      simp only [List.map_cons, List.sum_cons]
      by_cases hfe : e.fst = k
      · have hval : (updateKey k d e).snd = e.snd + d := by simp [updateKey, hfe]
        rw [hval]
        have h_not_mem_tail : k ∉ es.map Prod.fst := hfe ▸ h_notin
        have h_es_no_update : es.map (updateKey k d) = es := by
          have := List.map_congr_left (g := id)
            (l := es) (f := updateKey k d) (fun x hx => by
              have hxk : x.fst ≠ k := fun h => h_not_mem_tail (h ▸ List.mem_map_of_mem (f := Prod.fst) hx)
              simp [updateKey, hxk])
          simpa using this
        rw [h_es_no_update]
        ring
      · have hval : (updateKey k d e).snd = e.snd := by simp [updateKey, hfe]
        rw [hval]
        have h_mem' : k ∈ es.map Prod.fst := h_mem.resolve_left (Ne.symm hfe)
        rw [ih h_nodup2 h_mem']
        ring

theorem updateKey_preserves_fst (k : Nat) (d : Int) (entries : List (Nat × Int)) :
    (entries.map (updateKey k d)).map Prod.fst = entries.map Prod.fst := by
  induction entries with
  | nil => simp
  | cons e es ih =>
      simp only [List.map_cons, ih]
      congr 1
      unfold updateKey
      split_ifs with h <;> simp [h]

/-- `applyTransferEntry` is exactly "debit sender, then credit receiver" as
    two independent single-key updates, when sender ≠ receiver. -/
theorem applyTransferEntry_eq_compose (sender receiver : Nat) (amount : Int) (h_ne : sender ≠ receiver)
    (entry : Nat × Int) :
    applyTransferEntry sender receiver amount entry
      = updateKey receiver amount (updateKey sender (-amount) entry) := by
  unfold applyTransferEntry updateKey
  split_ifs with h1 h2 h3 <;> first | rfl | (exfalso; apply h_ne; omega)

/-- Total balance is conserved by `applyTransferEntry`, given the two
    structural invariants Go's `map[string]int64` gets for free and Lean's
    `List (Nat × Int)` does not: no duplicate account ids, and both
    accounts already present. -/
theorem transferSum_conserves
    (sender receiver : Nat) (amount : Int) (h_ne : sender ≠ receiver)
    (entries : List (Nat × Int))
    (h_nodup : (entries.map Prod.fst).Nodup)
    (h_sender : sender ∈ entries.map Prod.fst)
    (h_receiver : receiver ∈ entries.map Prod.fst) :
    ((entries.map (applyTransferEntry sender receiver amount)).map Prod.snd).sum
      = (entries.map Prod.snd).sum := by
  have hcompose : entries.map (applyTransferEntry sender receiver amount)
      = (entries.map (updateKey sender (-amount))).map (updateKey receiver amount) := by
    rw [List.map_map]
    apply List.map_congr_left
    intro x _
    exact applyTransferEntry_eq_compose sender receiver amount h_ne x
  rw [hcompose]
  have h_mid_nodup : ((entries.map (updateKey sender (-amount))).map Prod.fst).Nodup := by
    rw [updateKey_preserves_fst]; exact h_nodup
  have h_mid_receiver : receiver ∈ (entries.map (updateKey sender (-amount))).map Prod.fst := by
    rw [updateKey_preserves_fst]; exact h_receiver
  rw [sum_updateKey receiver amount _ h_mid_nodup h_mid_receiver]
  rw [sum_updateKey sender (-amount) entries h_nodup h_sender]
  ring

/-- `totalBalance` is `List.sum` of the values, restated for readability. -/
theorem totalBalance_eq_sum (entries : List (Nat × Int)) :
    totalBalance entries = (entries.map Prod.snd).sum := by
  unfold totalBalance
  suffices h : ∀ acc, entries.foldl (fun acc item => acc + item.snd) acc = acc + (entries.map Prod.snd).sum by
    rw [h]; ring
  intro acc
  induction entries generalizing acc with
  | nil => simp
  | cons x xs ih =>
      simp only [List.foldl_cons, List.map_cons, List.sum_cons]
      rw [ih]
      ring

/-- Transfer conservation restated in terms of `totalBalance`/`transferSpec`. -/
theorem transfer_impl_conserves_total
    (sender receiver : Nat) (amount : Int) (h_ne : sender ≠ receiver)
    (s : LedgerState)
    (h_nodup : (s.balances.map Prod.fst).Nodup)
    (h_sender : sender ∈ s.balances.map Prod.fst)
    (h_receiver : receiver ∈ s.balances.map Prod.fst) :
    totalBalance (transferImpl sender receiver amount s).balances = totalBalance s.balances := by
  unfold transferImpl transferSpec
  split_ifs with h
  · rfl
  · simp only [totalBalance_eq_sum]
    exact transferSum_conserves sender receiver amount h_ne s.balances h_nodup h_sender h_receiver

/-- Counterexample: transferring to an account id absent from `s.balances`
    silently loses value rather than erroring — Go's map-backed ledger has
    no such failure mode (an absent key defaults to zero and the mutation
    always applies). -/
theorem transferSpec_absent_account_drops_value :
    totalBalance (transferSpec 1 9 30 ⟨[(1, 100), (2, 50), (3, 0)]⟩).balances
      ≠ totalBalance [(1, 100), (2, 50), (3, 0)] := by decide

/-- Counterexample: `transferSpec` has no balance-sufficiency check at all.
    Go's `TransferWithControls` rejects this exact scenario outright
    (`insufficient balance in "acct1"` — see
    `internal/token/ledger_lean_correspondence_test.go`); the Lean spec
    applies it unconditionally and produces a negative balance. -/
theorem transferSpec_permits_insufficient_balance :
    (transferSpec 1 2 50 ⟨[(1, 10), (2, 0)]⟩).balances = [(1, -40), (2, 50)] := by decide

end Refinement
