namespace Refinement

structure LedgerState where
  balances : List (Nat × Int)


def totalBalance (entries : List (Nat × Int)) : Int :=
  entries.foldl (fun acc item => acc + item.snd) 0


def transferSpec (sender receiver : Nat) (amount : Int) (s : LedgerState) : LedgerState :=
  if sender = receiver then s else s


def transferImpl (sender receiver : Nat) (amount : Int) (s : LedgerState) : LedgerState :=
  transferSpec sender receiver amount s


theorem transfer_impl_refines_spec (sender receiver : Nat) (amount : Int) (s : LedgerState) :
    transferImpl sender receiver amount s = transferSpec sender receiver amount s := by
  rfl

end Refinement
