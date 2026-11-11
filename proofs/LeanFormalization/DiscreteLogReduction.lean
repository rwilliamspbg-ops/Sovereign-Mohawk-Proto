import Mathlib
import LeanFormalization.Common
import LeanFormalization.Ed25519
import LeanFormalization.TheoremUF_CMA_Ed25519

namespace LeanFormalization

open LeanFormalization

abbrev dlL : Nat := ed25519L

/-! ## The one assumption in this module

`dlL` is the Ed25519 subgroup order

    7237005577332262213973186563042994240857116359379907606001950938285454250989

(2^252 + 27742317777372353535851937790883648493), whose primality is a standard,
externally checkable number-theoretic fact (RFC 8032 / the Ed25519 reference
implementation). It is **not** re-derived here: proving primality of a 253-bit
integer in Lean is out of scope for this formalization — `decide` hits the
maximum recursion depth and `native_decide` does not finish, because the
number is far too large for either kernel reduction or compiled evaluation.

It is therefore an explicit hypothesis, `Fact (Nat.Prime dlL)`, on the four
declarations that need it — `scalarModInv`, `recoverSecret`,
`recovery_yields_secret`, `recovery_sanity_example` — rather than a global
`axiom`. This does not reduce the total trust (primality is still assumed), but
it removes the assumption from the global proof tree and makes it **local and
visible at each use site**: every consumer sees exactly what is being assumed
instead of inheriting it silently. `dlVerify`, `dlAdversarySucceeds`, and
`DiscreteLogHard` do not need it and remain unconditional. -/

structure DLInstance where
  point : AffinePoint
  deriving Repr

abbrev DLSolution := Nat

def dlVerify (inst : DLInstance) (sol : DLSolution) : Bool :=
  (affineScalarMulImpl sol affineBase == inst.point)

structure DLAdversary where
  run : AffinePoint → Option Nat

def dlAdversarySucceeds (adv : DLAdversary) (inst : DLInstance) : Bool :=
  match adv.run inst.point with
  | none => false
  | some a => dlVerify inst a

def DiscreteLogHard : Prop := ∀ (adv : DLAdversary) (inst : DLInstance), dlAdversarySucceeds adv inst = false

def scalarModInv (hp : Fact (Nat.Prime dlL)) (x : Nat) : Nat := by
  letI : Fact (Nat.Prime dlL) := hp
  exact ZMod.val (x : ZMod dlL)⁻¹

def recoverSecret (hp : Fact (Nat.Prime dlL)) (S1 S2 h1 h2 : Nat) : Nat :=
  let diffS := (S1 + dlL - S2 % dlL) % dlL
  let diffH := (h1 + dlL - h2 % dlL) % dlL
  (diffS * scalarModInv hp diffH) % dlL

theorem recovery_yields_secret (hp : Fact (Nat.Prime dlL)) (r a h1 h2 S1 S2 : Nat)
    (hS1 : S1 % dlL = (r + h1 * a) % dlL)
    (hS2 : S2 % dlL = (r + h2 * a) % dlL)
    (hdiff : (h1 % dlL) ≠ (h2 % dlL)) :
    (recoverSecret hp S1 S2 h1 h2) % dlL = a % dlL := by
  letI : Fact (Nat.Prime dlL) := hp
  set p := dlL
  have h1c : (S1 : ZMod p) = (r : ZMod p) + (h1 : ZMod p) * (a : ZMod p) := by
    have : (↑(S1 % p) : ZMod p) = (↑((r + h1 * a) % p) : ZMod p) := by rw [hS1]
    rw [ZMod.natCast_mod, ZMod.natCast_mod] at this
    rw [this]
    rw [Nat.cast_add]
    rw [Nat.cast_mul]
  have h2c : (S2 : ZMod p) = (r : ZMod p) + (h2 : ZMod p) * (a : ZMod p) := by
    have : (↑(S2 % p) : ZMod p) = (↑((r + h2 * a) % p) : ZMod p) := by rw [hS2]
    rw [ZMod.natCast_mod, ZMod.natCast_mod] at this
    rw [this]
    rw [Nat.cast_add]
    rw [Nat.cast_mul]
  have hdh_ne : (h1 : ZMod p) - (h2 : ZMod p) ≠ 0 := by
    intro heq
    have : (h1 : ZMod p) = (h2 : ZMod p) := sub_eq_zero.mp heq
    have hmod1 : (↑(h1 % p) : ZMod p) = (h1 : ZMod p) := ZMod.natCast_mod h1 p
    have hmod2 : (↑(h2 % p) : ZMod p) = (h2 : ZMod p) := ZMod.natCast_mod h2 p
    have : (↑(h1 % p) : ZMod p) = (↑(h2 % p) : ZMod p) := by rw [hmod1, hmod2, this]
    have : h1 % p = h2 % p := by
      have := congrArg ZMod.val this
      simp [ZMod.val_natCast] at this
      exact this
    exact hdiff this
  have hdiffS : (↑((S1 + p - S2 % p) % p) : ZMod p) = (S1 : ZMod p) - (S2 : ZMod p) := by
    rw [ZMod.natCast_mod]
    have hb : S2 % p ≤ S1 + p := by
      have : S2 % p < p := Nat.mod_lt S2 (by decide : 0 < p)
      omega
    rw [Nat.cast_sub hb]
    simp [Nat.cast_add, ZMod.natCast_mod]
  have hdiffH : (↑((h1 + p - h2 % p) % p) : ZMod p) = (h1 : ZMod p) - (h2 : ZMod p) := by
    rw [ZMod.natCast_mod]
    have hb : h2 % p ≤ h1 + p := by
      have : h2 % p < p := Nat.mod_lt h2 (by decide : 0 < p)
      omega
    rw [Nat.cast_sub hb]
    simp [Nat.cast_add, ZMod.natCast_mod]
  have hinv : (scalarModInv hp ((h1 + p - h2 % p) % p) : ZMod p) =
      ((h1 : ZMod p) - (h2 : ZMod p))⁻¹ := by
    simp [scalarModInv, ZMod.natCast_val, hdiffH]
  have hres : (recoverSecret hp S1 S2 h1 h2 : ZMod p) =
      ((S1 : ZMod p) - (S2 : ZMod p)) *
      (((h1 : ZMod p) - (h2 : ZMod p))⁻¹) := by
    unfold recoverSecret
    rw [ZMod.natCast_mod]
    rw [Nat.cast_mul]
    rw [hdiffS, hinv]
  rw [h1c, h2c] at hres
  have hsimp : (r : ZMod p) + (h1 : ZMod p) * (a : ZMod p) -
      ((r : ZMod p) + (h2 : ZMod p) * (a : ZMod p)) =
      ((h1 : ZMod p) - (h2 : ZMod p)) * (a : ZMod p) := by ring
  rw [hsimp] at hres
  let x := (h1 : ZMod p) - (h2 : ZMod p)
  have hcancel : (x * (a : ZMod p)) * x⁻¹ = (a : ZMod p) := by
    rw [mul_assoc x (a : ZMod p) x⁻¹]
    rw [mul_comm (a : ZMod p) x⁻¹]
    rw [← mul_assoc x x⁻¹ (a : ZMod p)]
    rw [mul_inv_cancel₀ hdh_ne]
    simp
  rw [hcancel] at hres
  -- hres : (recoverSecret ... : ZMod p) = (a : ZMod p)
  have hval : ZMod.val (recoverSecret hp S1 S2 h1 h2 : ZMod p) = ZMod.val (a : ZMod p) :=
    congrArg ZMod.val hres
  rw [ZMod.val_natCast, ZMod.val_natCast] at hval
  exact hval

theorem recovery_sanity_example (hp : Fact (Nat.Prime dlL)) :
    let r := 5; let a := 7; let h1 := 3; let h2 := 11
    let S1 := (r + h1 * a) % dlL
    let S2 := (r + h2 * a) % dlL
    (recoverSecret hp S1 S2 h1 h2) % dlL = a % dlL := by
  exact recovery_yields_secret hp 5 7 3 11 ((5 + 3 * 7) % dlL) ((5 + 11 * 7) % dlL) rfl rfl (by decide)

end LeanFormalization
