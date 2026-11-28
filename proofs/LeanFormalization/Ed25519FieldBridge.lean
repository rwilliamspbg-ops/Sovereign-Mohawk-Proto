/-
# The Ed25519 field arithmetic bridge

`Ed25519.lean` defines the field operations the curve arithmetic uses:

    fadd a b := (a + b) % p
    fsub a b := (a + p - (b % p)) % p
    fmul a b := (a * b) % p
    fInv a   := fPow a (p - 2)

and `fPow` is a 256-step square-and-multiply. **None of these had a correctness
lemma.** Every downstream result — the four `Ed25519GroupLaws`, and the
`verificationEquation_iff_ModEq` bridge built on them — rests on the assumption
that they are the field operations of `ZMod p`, and nothing in the repository
checked that.

This module proves the bridge. It is the **field layer** of Win A: after it,
the honest scope statement is that the *group law on the curve* is assumed,
while the field arithmetic beneath it is derived. The curve group law itself
(twisted-Edwards completeness of `affineAdd`, and the double-and-add recursion
of `affineScalarMulImpl`) is **not** proved here and remains the open part.

## What is proved

* `fadd`, `fsub`, `fmul` agree with the `ZMod p` operations (`*_zmod`).
* The commutative-ring laws for `fadd`/`fmul` (`*_comm`, `*_assoc`,
  `fmul_add`, `*_mod`), derived in `ZMod p` and transported back by
  `nat_eq_of_zmod_eq`.
* `fPowState` — the explicit square-and-multiply state — satisfies the
  invariant `result * base ^ exp ≡ a ^ e (mod p)` for every fuel, with
  `exp = e / 2 ^ fuel`. At `fuel = 256` and `e < 2 ^ 256` the exponent is
  exhausted, so `fPow a e = (a ^ e) % p`.
* `fInv` is the field inverse. `card_units_zmod` proves
  `Fintype.card (ZMod p)ˣ = p - 1` for prime `p` (from `Fintype.card_units` and
  `ZMod.card`), `zmod_pow_sub_one` derives `a ^ (p-1) = 1` from Lagrange's
  theorem, and `fmul_fInv` concludes `fInv a * a = 1` for `a` not divisible by
  `p`; `Nat.Prime ed25519P` is now proved (`ed25519P_prime`), so the `Fact` is supplied from that theorem.

## Scope

All five field operations are now bridged. What remains is **not** a field
question: it is the **group law on the curve** — twisted-Edwards completeness of
`affineAdd`, and the double-and-add recursion of `affineScalarMulImpl`. That is
the multi-week item, and this module does not touch it.

## Negative control

`fPow` is correct only for exponents below `2 ^ 256`, because the loop is
unrolled a fixed number of times. `fPowState_exp_ge` shows that at
`e = 2 ^ 256` the exponent component of the state is still `1` — the loop has
**not** terminated — so the `e < 2 ^ 256` hypothesis is load-bearing rather
than decorative. `fmul_fInv_zero` shows the inverse's own hypothesis is
load-bearing too: at `a = 0` the product is `0`, not `1`.
-/
import Mathlib
import LeanFormalization.Ed25519
import LeanFormalization.Ed25519PrimeCert

namespace LeanFormalization

/-- Primality is proved in `Ed25519PrimeCert`; package it once for this module. -/
local instance ed25519P_prime_fact_field : Fact (Nat.Prime ed25519P) :=
  ⟨Ed25519PrimeCert.ed25519P_prime⟩

/-! ### Range helpers -/

/-- `p = 2^255 - 19` is positive. -/
theorem ed25519P_pos : 0 < ed25519P := by
  unfold ed25519P
  norm_num

theorem ed25519P_ne_zero : ed25519P ≠ 0 := ne_of_gt ed25519P_pos

/-- **Equality from congruence plus range.** Two naturals below `n` that are
    congruent mod `n` are equal. -/
theorem nat_eq_of_modEq {n a b : ℕ} (h : Nat.ModEq n a b) (ha : a < n) (hb : b < n) :
    a = b := by
  unfold Nat.ModEq at h
  rw [Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hb] at h
  exact h

/-- **Equality from `ZMod` equality plus range.** The canonical bridge used by
    every field law below: the operations land in `[0, p)`, so equality of
    their casts is literal equality. -/
theorem nat_eq_of_zmod_eq {a b : ℕ} (h : (a : ZMod ed25519P) = (b : ZMod ed25519P))
    (ha : a < ed25519P) (hb : b < ed25519P) : a = b :=
  nat_eq_of_modEq (ZMod.natCast_eq_natCast_iff a b ed25519P |>.mp h) ha hb

/-! ### The bridge to `ZMod p` -/

theorem fadd_zmod (a b : ℕ) :
    ((fadd a b : ℕ) : ZMod ed25519P) = (a : ZMod ed25519P) + (b : ZMod ed25519P) := by
  unfold fadd
  rw [ZMod.natCast_mod]
  push_cast
  rfl

theorem fmul_zmod (a b : ℕ) :
    ((fmul a b : ℕ) : ZMod ed25519P) = (a : ZMod ed25519P) * (b : ZMod ed25519P) := by
  unfold fmul
  rw [ZMod.natCast_mod]
  push_cast
  rfl

theorem fsub_zmod (a b : ℕ) :
    ((fsub a b : ℕ) : ZMod ed25519P) = (a : ZMod ed25519P) - (b : ZMod ed25519P) := by
  unfold fsub
  rw [ZMod.natCast_mod]
  have hb : ((b % ed25519P : ℕ) : ZMod ed25519P) = (b : ZMod ed25519P) := ZMod.natCast_mod b ed25519P
  have hp : (ed25519P : ZMod ed25519P) = 0 := ZMod.natCast_self ed25519P
  have hbp : b % ed25519P ≤ ed25519P := Nat.le_of_lt (Nat.mod_lt _ ed25519P_pos)
  have hsplit : a + ed25519P - b % ed25519P = a + (ed25519P - b % ed25519P) := by omega
  rw [hsplit, Nat.cast_add]
  have hneg : ((ed25519P - b % ed25519P : ℕ) : ZMod ed25519P) =
      -((b : ℕ) : ZMod ed25519P) := by
    rw [Nat.cast_sub (Nat.le_of_lt (Nat.mod_lt _ ed25519P_pos)), hp, hb, zero_sub]
  rw [hneg]
  ring

theorem fadd_lt (a b : ℕ) : fadd a b < ed25519P := Nat.mod_lt _ ed25519P_pos
theorem fsub_lt (a b : ℕ) : fsub a b < ed25519P := Nat.mod_lt _ ed25519P_pos
theorem fmul_lt (a b : ℕ) : fmul a b < ed25519P := Nat.mod_lt _ ed25519P_pos

/-! ### The ring laws, transported from `ZMod p` -/

theorem fadd_comm (a b : ℕ) : fadd a b = fadd b a := by
  refine nat_eq_of_zmod_eq ?_ (fadd_lt _ _) (fadd_lt _ _)
  rw [fadd_zmod, fadd_zmod]
  ring

theorem fadd_assoc (a b c : ℕ) : fadd (fadd a b) c = fadd a (fadd b c) := by
  refine nat_eq_of_zmod_eq ?_ (fadd_lt _ _) (fadd_lt _ _)
  rw [fadd_zmod, fadd_zmod, fadd_zmod, fadd_zmod]
  ring

theorem fadd_mod (a b : ℕ) : fadd a b = fadd (a % ed25519P) (b % ed25519P) := by
  unfold fadd
  rw [Nat.add_mod]

/-- The additive identity, in canonical form: `a + 0` reduces to `a % p`. -/
theorem fadd_zero (a : ℕ) : fadd a 0 = a % ed25519P := by
  rfl

theorem fmul_comm (a b : ℕ) : fmul a b = fmul b a := by
  refine nat_eq_of_zmod_eq ?_ (fmul_lt _ _) (fmul_lt _ _)
  rw [fmul_zmod, fmul_zmod]
  ring

theorem fmul_assoc (a b c : ℕ) : fmul (fmul a b) c = fmul a (fmul b c) := by
  refine nat_eq_of_zmod_eq ?_ (fmul_lt _ _) (fmul_lt _ _)
  rw [fmul_zmod, fmul_zmod, fmul_zmod, fmul_zmod]
  ring

/-- **Distributivity** — the law the curve-equation algebra actually consumes. -/
theorem fmul_add (a b c : ℕ) : fmul a (fadd b c) = fadd (fmul a b) (fmul a c) := by
  refine nat_eq_of_zmod_eq ?_ (fmul_lt _ _) (fadd_lt _ _)
  rw [fmul_zmod, fadd_zmod, fadd_zmod, fmul_zmod, fmul_zmod]
  ring

theorem add_mul (a b c : ℕ) : fmul (fadd a b) c = fadd (fmul a c) (fmul b c) := by
  rw [fmul_comm (fadd a b) c, fmul_add, fmul_comm c a, fmul_comm c b]

theorem fmul_mod (a b : ℕ) : fmul a b = fmul (a % ed25519P) (b % ed25519P) := by
  unfold fmul
  rw [Nat.mul_mod]

/-- The multiplicative identity, in canonical form. -/
theorem fmul_one (a : ℕ) : fmul a 1 = a % ed25519P := by
  unfold fmul
  rw [Nat.mul_one]

theorem fmul_zero (a : ℕ) : fmul a 0 = 0 := by
  unfold fmul
  rw [Nat.mul_zero, Nat.zero_mod]

/-! ### `fPow` -/

/-- The explicit square-and-multiply state after `fuel` steps. `fPow a e` is
    the `result` component of this state at `fuel = 256`. -/
def fPowState (fuel a e : ℕ) : Nat × Nat × Nat :=
  (List.range fuel).foldl
    (fun (st : Nat × Nat × Nat) _ =>
      let (base, result, exp) := st
      if exp == 0 then st
      else
        let result' := if (exp &&& 1) == 1 then (result * base) % ed25519P else result
        let base' := (base * base) % ed25519P
        let exp' := exp / 2
        (base', result', exp'))
    (a % ed25519P, 1, e)

theorem fPow_eq_fPowState (a e : ℕ) : fPow a e = (fPowState 256 a e).2.1 := by
  simp only [fPow, fPowState]

/-- One square-and-multiply step, factored out so the state invariant can
    be stated without repeating the loop body. -/
def fPowStep (st : Nat × Nat × Nat) : Nat × Nat × Nat :=
  let (base, result, exp) := st
  if exp == 0 then st
  else
    let result' := if (exp &&& 1) == 1 then (result * base) % ed25519P else result
    let base' := (base * base) % ed25519P
    let exp' := exp / 2
    (base', result', exp')

theorem fPowState_succ (k a e : ℕ) :
    fPowState (k + 1) a e = fPowStep (fPowState k a e) := by
  unfold fPowState fPowStep
  rw [List.range_succ, List.foldl_append]
  simp

/-- **A generic fold invariant.** If `P` holds initially and is preserved by
    every step, it holds after folding any list. This is what makes the
    square-and-multiply loop provable without unrolling 256 steps. -/
theorem list_foldl_invariant {ι α : Type*} (F : α → ι → α) (init : α) (l : List ι)
    (P : α → Prop) (h0 : P init) (hstep : ∀ st x, P st → P (F st x)) :
    P (l.foldl F init) := by
  induction l generalizing init with
  | nil => simpa using h0
  | cons y ys ih => exact ih (F init y) (hstep init y h0)

/-- **The square-and-multiply invariant, stated in `ZMod p`.** After any
    number of steps the state `(base, result, exp)` satisfies
    `result * base ^ exp = a ^ e` in the field. -/
theorem fPowState_zmod (fuel a e : ℕ) :
    (((fPowState fuel a e).2.1 : ℕ) : ZMod ed25519P) *
        (((fPowState fuel a e).1 : ℕ) : ZMod ed25519P) ^ (fPowState fuel a e).2.2
      = ((a : ZMod ed25519P) ^ e) := by
  unfold fPowState
  refine list_foldl_invariant (F := fun st (_ : ℕ) => fPowStep st)
    (init := (a % ed25519P, 1, e)) (l := List.range fuel)
    (P := fun st => (((st.2.1 : ℕ) : ZMod ed25519P) *
      (((st.1 : ℕ) : ZMod ed25519P)) ^ st.2.2) = ((a : ZMod ed25519P) ^ e)) ?_ ?_
  · simp [ZMod.natCast_mod]
  · rintro ⟨b, r, x⟩ _ hP
    have hbit : x &&& 1 = x % 2 := by rw [Nat.land_comm, Nat.one_and_eq_mod_two]
    by_cases hx : x = 0
    · subst hx
      simpa [fPowStep] using hP
    · have hx0 : (x == 0) = false := by simp [hx]
      by_cases hxo : x % 2 = 1
      · have hb1 : ((x &&& 1) == 1) = true := by simp [hbit, hxo]
        have hx_odd : 1 + 2 * (x / 2) = x := by
          have hdm := Nat.div_add_mod x 2
          omega
        have h1 : (((b : ZMod ed25519P) * (b : ZMod ed25519P)) ^ (x / 2))
            = ((b : ZMod ed25519P) ^ (2 * (x / 2))) := by
          rw [mul_pow, ← pow_add]
          congr 1
          ring
        beta_reduce
        simp [fPowStep, hx0]
        rw [if_pos hxo, h1]
        have hcalc : (((r : ZMod ed25519P) * (b : ZMod ed25519P)) *
              (b : ZMod ed25519P) ^ (2 * (x / 2)))
            = ((r : ZMod ed25519P) * (b : ZMod ed25519P) ^ x) := by
          calc ((r : ZMod ed25519P) * (b : ZMod ed25519P)) *
                (b : ZMod ed25519P) ^ (2 * (x / 2))
              = (r : ZMod ed25519P) * ((b : ZMod ed25519P) *
                  (b : ZMod ed25519P) ^ (2 * (x / 2))) := by ring
            _ = (r : ZMod ed25519P) * (b : ZMod ed25519P) ^ (1 + 2 * (x / 2)) := by
                rw [pow_add]; ring
            _ = (r : ZMod ed25519P) * (b : ZMod ed25519P) ^ x := by rw [hx_odd]
        rw [hcalc]
        exact hP
      · have hxe : x % 2 = 0 := by
          have := Nat.mod_lt x (by norm_num : (0 : ℕ) < 2)
          omega
        have hb1 : ((x &&& 1) == 1) = false := by simp [hbit, hxe]
        have hx_even : 2 * (x / 2) = x := by
          have hdm := Nat.div_add_mod x 2
          omega
        have h1 : (((b : ZMod ed25519P) * (b : ZMod ed25519P)) ^ (x / 2))
            = ((b : ZMod ed25519P) ^ (2 * (x / 2))) := by
          rw [mul_pow, ← pow_add]
          congr 1
          ring
        beta_reduce
        simp [fPowStep, hx0]
        rw [if_neg hxo, h1, hx_even]
        exact hP

/-- The exponent component of one step is a halving. -/
theorem fPowStep_exp (st : Nat × Nat × Nat) : (fPowStep st).2.2 = st.2.2 / 2 := by
  obtain ⟨b, r, x⟩ := st
  simp only [fPowStep]
  by_cases hx : x = 0
  · subst hx
    simp
  · simp [hx]

/-- The exponent component tracks `e / 2 ^ fuel`. -/
theorem fPowState_exp (fuel a e : ℕ) : (fPowState fuel a e).2.2 = e / 2 ^ fuel := by
  induction fuel generalizing a e with
  | zero => simp [fPowState]
  | succ k ih =>
      rw [fPowState_succ, fPowStep_exp, ih, pow_succ, ← Nat.div_div_eq_div_mul]

/-- The state components stay in `[0, p)`. -/
theorem fPowState_lt (fuel a e : ℕ) :
    (fPowState fuel a e).1 < ed25519P ∧ (fPowState fuel a e).2.1 < ed25519P := by
  unfold fPowState
  refine list_foldl_invariant (F := fun st (_ : ℕ) => fPowStep st)
    (init := (a % ed25519P, 1, e)) (l := List.range fuel)
    (P := fun st => st.1 < ed25519P ∧ st.2.1 < ed25519P) ?_ ?_
  · refine ⟨Nat.mod_lt _ ed25519P_pos, ?_⟩
    unfold ed25519P
    norm_num
  · rintro ⟨b, r, x⟩ _ hP
    obtain ⟨hb, hr⟩ := hP
    simp only [fPowStep]
    have hbb : (b * b) % ed25519P < ed25519P := Nat.mod_lt _ ed25519P_pos
    have hrr : (r * b) % ed25519P < ed25519P := Nat.mod_lt _ ed25519P_pos
    by_cases hx : (x == 0) = true
    · rw [if_pos hx]
      exact ⟨hb, hr⟩
    · rw [if_neg hx]
      by_cases hb1 : ((x &&& 1) == 1) = true
      · rw [if_pos hb1]
        exact ⟨hbb, hrr⟩
      · rw [if_neg hb1]
        exact ⟨hbb, hr⟩

/-- **The state's result component is the modular exponentiation.** -/
theorem fPowState_result_eq (fuel a e : ℕ) (he : e < 2 ^ fuel) :
    (fPowState fuel a e).2.1 = (a ^ e) % ed25519P := by
  have hexp : (fPowState fuel a e).2.2 = 0 := by
    rw [fPowState_exp, Nat.div_eq_of_lt he]
  have hz := fPowState_zmod fuel a e
  rw [hexp, pow_zero, mul_one] at hz
  have hz' : ((fPowState fuel a e).2.1 : ZMod ed25519P) =
      (((a ^ e) % ed25519P : ℕ) : ZMod ed25519P) := by
    rw [ZMod.natCast_mod, Nat.cast_pow]
    exact hz
  refine nat_eq_of_modEq (ZMod.natCast_eq_natCast_iff
    (fPowState fuel a e).2.1 ((a ^ e) % ed25519P) ed25519P |>.mp hz') ?_ ?_
  · exact (fPowState_lt fuel a e).2
  · exact Nat.mod_lt (a ^ e) ed25519P_pos

/-- **`fPow` computes `a ^ e mod p`.** The loop is unrolled 256 times, so the
    exponent must fit in 256 bits; `e < 2 ^ 256` is exactly that bound. -/
theorem fPow_eq_pow_mod (a e : ℕ) (he : e < 2 ^ 256) :
    fPow a e = (a ^ e) % ed25519P := by
  rw [fPow_eq_fPowState]
  exact fPowState_result_eq 256 a e he

/-- **Negative control: the 256-step loop has not terminated at `2^256`.** -/
theorem fPowState_exp_ge (a : ℕ) : (fPowState 256 a (2 ^ 256)).2.2 = 1 := by
  rw [fPowState_exp]
  norm_num

/-! ### `fInv`

`fInv a = fPow a (p - 2)` is Fermat inversion. Proving `fInv a * a = 1` for
`a not equiv 0 (mod p)` needs `a ^ (p-1) = 1`, which is Lagrange's theorem on
the unit group; the cardinality of that group is the one ingredient the pinned
Mathlib does not state for `ZMod`, so it is proved here from
`Fintype.card_units` and `ZMod.card`. -/

/-- **The unit group of `ZMod p` has `p - 1` elements, for prime `p`.** -/
theorem card_units_zmod (p : ℕ) [Fact (Nat.Prime p)] :
    Fintype.card (ZMod p)ˣ = p - 1 := by
  rw [Fintype.card_units (α := ZMod p), ZMod.card]

/-- `↑(u ^ n) = ↑u ^ n` for a unit. Mathlib has `Units.val_mul` but not the
    power version, and it is needed to move the unit-group Lagrange statement
    back to the ring. -/
theorem units_val_pow {α : Type*} [Monoid α] (u : αˣ) (n : ℕ) :
    (↑(u ^ n) : α) = (u : α) ^ n := by
  induction n with
  | zero => simp
  | succ k ih => rw [pow_succ, pow_succ, Units.val_mul, ih]

/-- **`a ^ (p-1) = 1` in `ZMod p` for `a ≠ 0`, prime `p`.** Lagrange's theorem
    (`pow_card_eq_one`) applied to the unit group. -/
theorem zmod_pow_sub_one (p : ℕ) [Fact (Nat.Prime p)] {a : ZMod p} (ha : a ≠ 0) :
    a ^ (p - 1) = 1 := by
  have h := pow_card_eq_one (G := (ZMod p)ˣ) (x := Units.mk0 a ha)
  rw [card_units_zmod] at h
  simpa [units_val_pow, Units.val_mk0 ha] using
    congrArg (Units.val : (ZMod p)ˣ → ZMod p) h

/-- **`fInv` is the field inverse**: `fInv a * a = 1`, for `a` not divisible by
    `p`. Primality is supplied from the proved `ed25519P_prime` (unlike
    `Fact (Nat.Prime dlL)`, which remains an explicit hypothesis). -/
theorem fmul_fInv {a : ℕ} (ha : a % ed25519P ≠ 0) :
    fmul (fInv a) a = 1 := by
  have hne : (a : ZMod ed25519P) ≠ 0 := by
    intro h
    apply ha
    simpa using (ZMod.natCast_eq_natCast_iff a 0 ed25519P |>.mp h)
  have hbound : ed25519P - 2 < 2 ^ 256 := by
    unfold ed25519P
    norm_num
  have hinv : fInv a = (a ^ (ed25519P - 2)) % ed25519P := by
    unfold fInv
    exact fPow_eq_pow_mod a (ed25519P - 2) hbound
  refine nat_eq_of_zmod_eq ?_ (fmul_lt _ _) ?_
  · rw [fmul_zmod, hinv, ZMod.natCast_mod, Nat.cast_pow]
    have hpow : (a : ZMod ed25519P) ^ (ed25519P - 2) * (a : ZMod ed25519P)
        = (a : ZMod ed25519P) ^ (ed25519P - 1) := by
      have hp2 : (2 : ℕ) ≤ ed25519P := by unfold ed25519P; norm_num
      rw [show ed25519P - 1 = (ed25519P - 2) + 1 by omega, pow_add, pow_one]
    rw [hpow]
    exact zmod_pow_sub_one (p := ed25519P) hne
  · unfold ed25519P
    norm_num

/-- **Negative control: `a not equiv 0 (mod p)` is load-bearing.** At `a = 0`
    the inverse is `0` and the product is `0`, not `1`. -/
theorem fmul_fInv_zero : fmul (fInv 0) 0 = 0 := by
  unfold fmul
  simp

end LeanFormalization
