import Mathlib
import LeanFormalization.Ed25519CurveGroupLaw

/-!
# `affineScalarMulImpl`: base cases and produced-point invariants

`Ed25519CurveGroupLaw.lean` proves identity, commutativity and canonical
preservation for `affineAdd`, and records **associativity** as the open law that
blocks the four group laws consumed by `Ed25519VerificationEquation.lean`.
`docs/MAJOR_WIN_PLAN.md` calls the curve group law "the multi-week item".

This module does not attempt associativity (see the residual-gap section below).
It targets the other half of the brief's Ed25519 item — *"full group-law proofs
for the currently unaudited affine implementations"* — by auditing the
double-and-add loop directly.

## What is proved

* `affineAdd_consistent` — `affineAdd` maps consistent inputs to a consistent
  output. This discharges an explicit `IsConsistent` hypothesis at every future
  use site rather than assuming it.
* `smulStep` / `smulFold` — the loop body factored out, and
  `affineScalarMulImpl_eq_smulFold` identifying the implementation with the
  fold. Everything below is then proved about the fold.
* `affineScalarMulImpl_zero` — `0 · P = affineIdentity`. This is `zeroMul`,
  which `Ed25519VerificationEquation.lean` used to *assume* before #361 removed
  it for having no dependents; here it is **derived**.
* `affineScalarMulImpl_one` — `1 · P = P` for consistent `P`. Likewise a former
  assumption (`oneMul`), now proved.
* `affineScalarMulImpl_consistent` / `affineScalarMulImpl_canonical` — every
  point the loop produces satisfies both invariants, so downstream group-law
  theorems need no extra hypotheses about its outputs.

## Residual gap (stated openly)

**Associativity of `affineAdd` is NOT proved.** It needs the completeness of the
unified twisted-Edwards formula: the denominators `1 ± d·x1·x2·y1·y2` must be
non-zero for on-curve points, which is a statement about the curve equation
(and ultimately about `d` being a non-square mod `p`) rather than a case bash.
Neither the closure identity nor the associativity identity falls to `ring`,
`field_simp` or `linear_combination` on the current Mathlib, so this is recorded
as a gap, not worked around.
-/

namespace LeanFormalization

/-! ### `affineAdd` preserves consistency -/

/-- `affineAdd` never manufactures a false infinity: if both inputs are
    consistent, so is the result. The exceptional branch returns
    `affineIdentity`; the formula branch sets `inf := false`. -/
theorem affineAdd_consistent {P Q : AffinePoint} (hP : IsConsistent P) (hQ : IsConsistent Q) :
    IsConsistent (affineAdd P Q) := by
  unfold IsConsistent
  cases hPi : P.inf with
  | true => simp only [affineAdd, hPi, if_true]; exact hQ
  | false =>
      cases hQi : Q.inf with
      | true => simp only [affineAdd, hPi, if_false, hQi, if_true]; exact hP
      | false =>
          have hPi' : ¬ P.inf := by rw [hPi]; simp
          have hQi' : ¬ Q.inf := by rw [hQi]; simp
          cases hb : IsNegation P Q with
          | true =>
              have h : affineAdd P Q = affineIdentity := by
                simp only [affineAdd, hPi, hQi]
                simp only [IsNegation] at hb ⊢
                rw [hb]
                rfl
              rw [h]
              exact Or.inr rfl
          | false =>
              have h : affineAdd P Q = affineAddFormula P.x P.y Q.x Q.y :=
                affineAdd_eq_formula P Q hPi' hQi' hb
              rw [h]
              exact Or.inl rfl

/-! ### The scalar-multiplication loop, factored out -/

/-- One MSB-first double-and-add step: double the accumulator, conditionally add
    `P`. Exactly the body of the `foldl` in `affineScalarMulImpl`. -/
def smulStep (bit : Nat) (r P : AffinePoint) : AffinePoint :=
  let r2 := affineAdd r r
  if bit == 1 then affineAdd r2 P else r2

/-- The first `n` steps of `affineScalarMulImpl`'s loop, i.e. processing bits
    `n-1 … 0`. `affineScalarMulImpl` is `smulFold k P 256`. -/
noncomputable def smulFold (k : Nat) (P : AffinePoint) (n : Nat) : AffinePoint :=
  (List.range n).reverse.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) affineIdentity

/-- The implementation *is* this fold; nothing has changed definitionally. -/
theorem affineScalarMulImpl_eq_smulFold (k : Nat) (P : AffinePoint) :
    affineScalarMulImpl k P = smulFold k P 256 := rfl

/-- A zero bit is a no-op when the accumulator is the identity: doubling
    `affineIdentity` gives `affineIdentity` back, and no addition happens. -/
theorem smulStep_zero_identity (P : AffinePoint) :
    smulStep 0 affineIdentity P = affineIdentity := by
  unfold smulStep
  have hb : ((0 : Nat) == 1) = false := by decide
  rw [hb]
  simp
  exact affineAdd_identity_left affineIdentity (Or.inr rfl)

/-- A `1` bit applied to the identity accumulator yields `P` exactly. This is
    unconditional: `affineAdd affineIdentity P = P` holds by the implementation's
    first branch, so no `IsConsistent` hypothesis is needed. It is the step-level
    counterpart of the already-derived `oneMul` law. -/
lemma smulStep_one_identity (P : AffinePoint) :
    smulStep 1 affineIdentity P = P := by
  unfold smulStep
  have hb : ((1 : Nat) == 1) = true := by decide
  rw [if_pos hb]
  change affineAdd (affineAdd affineIdentity affineIdentity) P = P
  rw [show affineAdd affineIdentity affineIdentity = affineIdentity by rfl]
  rfl

/-- Folding a run of zero-valued bits starting from the identity leaves the
    identity unchanged. -/
theorem foldl_zero_bits_eq_identity {l : List Nat} {f : Nat → Nat} {P : AffinePoint}
    (hl : ∀ b ∈ l, f b = 0) :
    l.foldl (fun r b => smulStep (f b) r P) affineIdentity = affineIdentity := by
  induction l with
  | nil => rfl
  | cons a l ih =>
      rw [List.foldl_cons]
      have ha : f a = 0 := hl a (by simp)
      rw [show smulStep (f a) affineIdentity P = affineIdentity by
        rw [ha]; exact smulStep_zero_identity P]
      exact ih (fun b hb => hl b (by simp [hb]))

/-- **`0 · P = affineIdentity`** — the `zeroMul` law, derived rather than
    assumed. -/
theorem affineScalarMulImpl_zero (P : AffinePoint) :
    affineScalarMulImpl 0 P = affineIdentity := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  exact foldl_zero_bits_eq_identity (fun b _ => by simp)

/-- Splitting off the most significant index of the loop range:
    `(range (n+1)).reverse = [n] ++ (range n).reverse`. -/
theorem smulFold_range_succ (k : Nat) (P : AffinePoint) (n : Nat) :
    smulFold k P (n + 1) =
      (List.range n).reverse.foldl
        (fun r i => smulStep ((k >>> i) &&& 1) r P)
        (smulStep ((k >>> n) &&& 1) affineIdentity P) := by
  unfold smulFold
  rw [List.range_succ, List.reverse_append, List.reverse_singleton,
    List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- Appending one more index does not change the fold when that index's bit is
    `0`, because the leading step then preserves the identity. -/
theorem smulFold_bitZero (k : Nat) (P : AffinePoint) {n : Nat} (hk : k < 2 ^ n) :
    smulFold k P (n + 1) = smulFold k P n := by
  rw [smulFold_range_succ]
  have hbit : (k >>> n) &&& 1 = 0 := by
    rw [Nat.shiftRight_eq_div_pow]
    have hd : k / 2 ^ n = 0 := Nat.div_eq_of_lt hk
    rw [hd]
    norm_num
  rw [show smulStep ((k >>> n) &&& 1) affineIdentity P = affineIdentity by
    rw [hbit]; exact smulStep_zero_identity P]
  rw [smulFold]

/-- If `k < 2^m`, then processing any number of higher zero bits is a no-op:
    the fold over `n` indices equals the fold over `m` indices. -/
theorem smulFold_stable_below (k : Nat) (P : AffinePoint) :
    ∀ {m n : Nat}, m ≤ n → k < 2 ^ m → smulFold k P n = smulFold k P m := by
  intro m n hmn hk
  induction n generalizing m with
  | zero =>
      have hm0 : m = 0 := Nat.le_zero.mp hmn
      subst hm0
      rfl
  | succ n ih =>
      rcases Nat.lt_or_eq_of_le hmn with hlt | heq
      · have hle : m ≤ n := Nat.le_of_lt_succ hlt
        have hk' : k < 2 ^ n :=
          lt_of_lt_of_le hk (Nat.pow_le_pow_right (by norm_num) hle)
        rw [smulFold_bitZero k P hk']
        exact ih hle hk
      · subst heq
        rfl

/-- **`1 · P = P`** for a consistent `P` — the `oneMul` law, derived rather than
    assumed. The high 255 bits of `1` are all zero, so the loop stays at the
    identity until the final bit. -/
theorem affineScalarMulImpl_one (P : AffinePoint) (hc : IsConsistent P) :
    affineScalarMulImpl 1 P = P := by
  rw [affineScalarMulImpl_eq_smulFold]
  have hstable : smulFold 1 P 256 = smulFold 1 P 1 :=
    smulFold_stable_below 1 P (by norm_num) (by norm_num : (1 : Nat) < 2 ^ 1)
  rw [hstable, smulFold, List.range_one, List.reverse_singleton,
    List.foldl_cons, List.foldl_nil]
  have hb : ((1 >>> (0 : Nat)) &&& 1) = 1 := by decide
  rw [hb]
  unfold smulStep
  have hb' : ((1 : Nat) == 1) = true := by decide
  rw [hb']
  simp
  rw [show affineAdd affineIdentity affineIdentity = affineIdentity from
    affineAdd_identity_left affineIdentity (Or.inr rfl)]
  exact affineAdd_identity_left P hc

/-! ### Invariants preserved by the loop -/

/-- One step preserves consistency. -/
theorem smulStep_consistent {b : Nat} {r P : AffinePoint}
    (hr : IsConsistent r) (hP : IsConsistent P) : IsConsistent (smulStep b r P) := by
  unfold smulStep
  by_cases hb : b == 1
  · rw [if_pos hb]
    exact affineAdd_consistent (affineAdd_consistent hr hr) hP
  · rw [if_neg hb]
    exact affineAdd_consistent hr hr

/-- Consistency is preserved along a fold of steps. -/
theorem foldl_smulStep_consistent (l : List Nat) (k : Nat) (P : AffinePoint)
    (hP : IsConsistent P) :
    ∀ r, IsConsistent r →
      IsConsistent (l.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) r) := by
  induction l with
  | nil => intro r hr; simpa using hr
  | cons a l ih =>
      intro r hr
      rw [List.foldl_cons]
      exact ih (smulStep ((k >>> a) &&& 1) r P) (smulStep_consistent hr hP)

/-- Every point produced by `affineScalarMulImpl` is consistent — the loop can
    never manufacture a false infinity. -/
theorem affineScalarMulImpl_consistent (k : Nat) (P : AffinePoint) (hP : IsConsistent P) :
    IsConsistent (affineScalarMulImpl k P) := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  exact foldl_smulStep_consistent (List.range 256).reverse k P hP affineIdentity (Or.inr rfl)

/-- One step preserves reduced coordinates. -/
theorem smulStep_canonical {b : Nat} {r P : AffinePoint}
    (hr : IsCanonical r) (hP : IsCanonical P) : IsCanonical (smulStep b r P) := by
  unfold smulStep
  by_cases hb : b == 1
  · rw [if_pos hb]
    exact affineAdd_canonical (affineAdd r r) P (affineAdd_canonical r r hr hr) hP
  · rw [if_neg hb]
    exact affineAdd_canonical r r hr hr

/-- Reduced coordinates are preserved along a fold of steps. -/
theorem foldl_smulStep_canonical (l : List Nat) (k : Nat) (P : AffinePoint)
    (hP : IsCanonical P) :
    ∀ r, IsCanonical r →
      IsCanonical (l.foldl (fun r i => smulStep ((k >>> i) &&& 1) r P) r) := by
  induction l with
  | nil => intro r hr; simpa using hr
  | cons a l ih =>
      intro r hr
      rw [List.foldl_cons]
      exact ih (smulStep ((k >>> a) &&& 1) r P) (smulStep_canonical hr hP)

/-- Every point produced by `affineScalarMulImpl` has reduced coordinates. -/
theorem affineScalarMulImpl_canonical (k : Nat) (P : AffinePoint) (hP : IsCanonical P) :
    IsCanonical (affineScalarMulImpl k P) := by
  rw [affineScalarMulImpl_eq_smulFold, smulFold]
  have hinit : IsCanonical (affineIdentity : AffinePoint) := by
    unfold IsCanonical affineIdentity
    exact ⟨ed25519P_pos, by unfold ed25519P; norm_num⟩
  exact foldl_smulStep_canonical (List.range 256).reverse k P hP affineIdentity hinit

set_option maxHeartbeats 400000

/-! ### Conditional scalar-multiplication laws, at the fold level

The loop is ordinary binary exponentiation: for an associative operation `op`
with identity `e`, the `n`-bit MSB-first fold equals `opPow op e P k` whenever
`k < 2 ^ n`. `OpCommMonoid.genFold_addMul` and `OpCommMonoid.genFold_mulMul`
derive the two consumed laws from that identity. No new axiom: the residual
assumptions are the monoid laws on the operation used by the fold, and the
exponent-width bounds that keep the fold from truncating.

For the concrete `affineAdd` these are real residuals. Associativity is proved
only by `affineAdd_associative_of_complete`, whose 20 conditions are packaged
verbatim in `AffineAssocConditions`; `affineAdd_comm`, `affineAdd_identity` and
`affineAdd_identity_left` are conditional on reduced coordinates / consistency.
The two concrete theorems below therefore take the four laws as explicit
hypotheses and state the width bounds explicitly.
-/

local instance ed25519P_prime_fact_local : Fact (Nat.Prime ed25519P) := ⟨ed25519P_prime⟩

universe u

structure OpCommMonoid (α : Type u) where
  op : α → α → α
  e : α
  assoc : ∀ x y z : α, op (op x y) z = op x (op y z)
  comm : ∀ x y : α, op x y = op y x
  one_left : ∀ x : α, op e x = x
  one_right : ∀ x : α, op x e = x

def opPow {α : Type u} (op : α → α → α) (e a : α) : Nat → α
  | 0 => e
  | n + 1 => op (opPow op e a n) a

def genSmulStep {α : Type u} (op : α → α → α) (bit : Nat) (r P : α) : α :=
  let r2 := op r r
  if bit == 1 then op r2 P else r2

def foldBits {α : Type u} (op : α → α → α) (bits : List Nat) (acc P : α) : α :=
  bits.foldl (fun r b => genSmulStep op b r P) acc

def genSmulFold {α : Type u} (op : α → α → α) (e : α) (k : Nat) (P : α) (n : Nat) : α :=
  ((List.range n).reverse.foldl (fun r i => genSmulStep op ((k >>> i) &&& 1) r P) e)

def binVal : List Nat → Nat
  | [] => 0
  | b :: bs => b * 2 ^ bs.length + binVal bs

namespace OpCommMonoid

variable {α : Type u} (m : OpCommMonoid α)

theorem opPow_e (n : Nat) : opPow m.op m.e m.e n = m.e := by
  induction n with
  | zero => rfl
  | succ n ih => rw [opPow, ih, m.one_left]

theorem opPow_add (a : α) (p q : Nat) :
    opPow m.op m.e a (p + q) = m.op (opPow m.op m.e a p) (opPow m.op m.e a q) := by
  induction q with
  | zero => simp [opPow, m.one_right]
  | succ q ih => rw [Nat.add_succ, opPow, ih, opPow, ← m.assoc]

theorem opPow_mul (a : α) (p q : Nat) :
    opPow m.op m.e (opPow m.op m.e a p) q = opPow m.op m.e a (p * q) := by
  induction q with
  | zero => simp [opPow]
  | succ q ih => rw [Nat.mul_succ, opPow, ih, ← m.opPow_add]

theorem op_op_comm (a b c d : α) :
    m.op (m.op a b) (m.op c d) = m.op (m.op a c) (m.op b d) := by
  calc
    m.op (m.op a b) (m.op c d) = m.op a (m.op b (m.op c d)) := m.assoc a b (m.op c d)
    _ = m.op a (m.op (m.op b c) d) := by rw [← m.assoc b c d]
    _ = m.op a (m.op (m.op c b) d) := by rw [m.comm b c]
    _ = m.op a (m.op c (m.op b d)) := by rw [m.assoc c b d]
    _ = m.op (m.op a c) (m.op b d) := by rw [← m.assoc a c (m.op b d)]

theorem opPow_op (a b : α) (n : Nat) :
    opPow m.op m.e (m.op a b) n = m.op (opPow m.op m.e a n) (opPow m.op m.e b n) := by
  induction n with
  | zero => simp [opPow, m.one_left]
  | succ n ih => rw [opPow, ih, opPow, opPow, m.op_op_comm]

theorem step_eq (b : Nat) (hb : b = 0 ∨ b = 1) (r P : α) :
    genSmulStep m.op b r P = m.op (m.op r r) (opPow m.op m.e P b) := by
  rcases hb with rfl | rfl
  · simp [genSmulStep, opPow, m.one_right]
  · simp [genSmulStep, opPow, m.one_left]

theorem foldBits_eq (bits : List Nat) (hb : ∀ b ∈ bits, b = 0 ∨ b = 1) (acc P : α) :
    foldBits m.op bits acc P =
      m.op (opPow m.op m.e acc (2 ^ bits.length)) (opPow m.op m.e P (binVal bits)) := by
  induction bits generalizing acc with
  | nil => simp [foldBits, binVal, opPow, m.one_left, m.one_right]
  | cons b bs ih =>
      have hb0 : b = 0 ∨ b = 1 := hb b (by simp)
      have hbs : ∀ x ∈ bs, x = 0 ∨ x = 1 := fun x hx => hb x (by simp [hx])
      change foldBits m.op bs (genSmulStep m.op b acc P) P =
        m.op (opPow m.op m.e acc (2 ^ (b :: bs).length)) (opPow m.op m.e P (binVal (b :: bs)))
      rw [m.step_eq b hb0 acc P]
      rcases hb0 with rfl | rfl
      · simp only [opPow, m.one_right]
        rw [ih hbs]
        rw [m.opPow_op]
        simp only [binVal, List.length_cons, zero_mul, zero_add]
        rw [show 2 ^ (bs.length + 1) = 2 ^ bs.length + 2 ^ bs.length by rw [pow_succ]; ring]
        rw [← m.opPow_add]
      · simp only [opPow, m.one_left]
        rw [ih hbs]
        rw [m.opPow_op, m.opPow_op]
        simp only [binVal, List.length_cons, one_mul]
        rw [show 2 ^ (bs.length + 1) = 2 ^ bs.length + 2 ^ bs.length by rw [pow_succ]; ring]
        rw [← m.opPow_add]
        rw [m.assoc]
        rw [← m.opPow_add]

end OpCommMonoid

lemma bit_land_one_mod (n : Nat) : n &&& 1 = n % 2 := by
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_land]
  rw [show (1 : Nat) = 2 ^ 0 by norm_num, Nat.testBit_two_pow]
  rw [show (2 : Nat) = 2 ^ 1 by norm_num, Nat.testBit_mod_two_pow]
  by_cases hi : i = 0
  · subst hi
    simp
  · have hi0 : ¬ i < 1 := by omega
    have h0i : ¬ 0 = i := by omega
    by_cases hb : n.testBit i <;> simp [hb, hi0, h0i]

lemma bit_mod_pow_succ (k n : Nat) :
    k % 2 ^ (n + 1) = ((k / 2 ^ n) % 2) * 2 ^ n + k % 2 ^ n := by
  have hd : 0 < 2 ^ n := pow_pos (by norm_num) _
  have hdecomp : k = 2 ^ n * (k / 2 ^ n) + k % 2 ^ n := (Nat.div_add_mod k (2 ^ n)).symm
  have hq : k / 2 ^ n = 2 * (k / 2 ^ n / 2) + (k / 2 ^ n) % 2 :=
    (Nat.div_add_mod (k / 2 ^ n) 2).symm
  have hlt : ((k / 2 ^ n) % 2) * 2 ^ n + k % 2 ^ n < 2 * 2 ^ n := by
    have hle : (k / 2 ^ n) % 2 ≤ 1 := by omega
    have hr : k % 2 ^ n < 2 ^ n := Nat.mod_lt _ hd
    nlinarith
  conv_lhs =>
    rw [show 2 ^ (n + 1) = 2 * 2 ^ n by rw [pow_succ]; ring]
    rw [hdecomp, hq]
    rw [show 2 ^ n * (2 * (k / 2 ^ n / 2) + (k / 2 ^ n) % 2) + k % 2 ^ n =
      (k / 2 ^ n % 2 * 2 ^ n + k % 2 ^ n) + (2 * 2 ^ n) * (k / 2 ^ n / 2) by ring]
    rw [Nat.add_mul_mod_self_left]
  exact Nat.mod_eq_of_lt hlt

lemma binVal_range_bits (k n : Nat) :
    binVal ((List.range n).reverse.map (fun i => (k >>> i) &&& 1)) = k % 2 ^ n := by
  induction n with
  | zero => simp [binVal, Nat.mod_one]
  | succ n ih =>
      rw [List.range_succ, List.reverse_append, List.reverse_singleton]
      simp only [List.singleton_append, List.map_cons, binVal]
      rw [show List.length ((List.range n).reverse.map (fun i => (k >>> i) &&& 1)) = n by simp]
      rw [ih]
      rw [Nat.shiftRight_eq_div_pow, bit_land_one_mod]
      exact (bit_mod_pow_succ k n).symm

namespace OpCommMonoid

variable {α : Type u} (m : OpCommMonoid α)

theorem genFold_eq_opPow_of_lt (k n : Nat) (P : α) (hk : k < 2 ^ n) :
    genSmulFold m.op m.e k P n = opPow m.op m.e P k := by
  have hb : ∀ b ∈ ((List.range n).reverse.map (fun i => (k >>> i) &&& 1)), b = 0 ∨ b = 1 := by
    intro b hb
    simp only [List.mem_map] at hb
    rcases hb with ⟨i, hi, rfl⟩
    rw [bit_land_one_mod]
    exact Nat.mod_two_eq_zero_or_one _
  have h := m.foldBits_eq ((List.range n).reverse.map (fun i => (k >>> i) &&& 1)) hb m.e P
  have hfold : genSmulFold m.op m.e k P n =
      foldBits m.op ((List.range n).reverse.map (fun i => (k >>> i) &&& 1)) m.e P := by
    unfold genSmulFold foldBits
    rw [List.foldl_map]
  rw [hfold]
  rw [h, m.opPow_e, m.one_left, binVal_range_bits]
  rw [Nat.mod_eq_of_lt hk]

theorem genFold_addMul (k1 k2 n : Nat) (P : α)
    (h1 : k1 < 2 ^ n) (h2 : k2 < 2 ^ n) (hs : k1 + k2 < 2 ^ n) :
    genSmulFold m.op m.e (k1 + k2) P n =
      m.op (genSmulFold m.op m.e k1 P n) (genSmulFold m.op m.e k2 P n) := by
  rw [m.genFold_eq_opPow_of_lt (k1 + k2) n P hs,
      m.genFold_eq_opPow_of_lt k1 n P h1,
      m.genFold_eq_opPow_of_lt k2 n P h2,
      m.opPow_add]

theorem genFold_mulMul (k1 k2 n : Nat) (P : α)
    (h1 : k1 < 2 ^ n) (h2 : k2 < 2 ^ n) (hp : k1 * k2 < 2 ^ n) :
    genSmulFold m.op m.e k1 (genSmulFold m.op m.e k2 P n) n =
      genSmulFold m.op m.e (k1 * k2) P n := by
  rw [m.genFold_eq_opPow_of_lt k1 n (genSmulFold m.op m.e k2 P n) h1,
      m.genFold_eq_opPow_of_lt k2 n P h2,
      m.genFold_eq_opPow_of_lt (k1 * k2) n P hp,
      m.opPow_mul]
  rw [Nat.mul_comm]

end OpCommMonoid

/-! ### Concrete specialization -/

theorem genSmulFold_eq_smulFold (k : Nat) (P : AffinePoint) (n : Nat) :
    genSmulFold affineAdd affineIdentity k P n = smulFold k P n := by
  rfl

theorem affineScalarMulImpl_addMul_of_laws
    (hAssoc : ∀ X Y Z : AffinePoint, affineAdd (affineAdd X Y) Z = affineAdd X (affineAdd Y Z))
    (hComm : ∀ X Y : AffinePoint, affineAdd X Y = affineAdd Y X)
    (hLeft : ∀ X : AffinePoint, affineAdd affineIdentity X = X)
    (hRight : ∀ X : AffinePoint, affineAdd X affineIdentity = X)
    (k1 k2 : Nat) (P : AffinePoint)
    (h1 : k1 < 2 ^ 256) (h2 : k2 < 2 ^ 256) (hs : k1 + k2 < 2 ^ 256) :
    affineScalarMulImpl (k1 + k2) P =
      affineAdd (affineScalarMulImpl k1 P) (affineScalarMulImpl k2 P) := by
  let m : OpCommMonoid AffinePoint := ⟨affineAdd, affineIdentity, hAssoc, hComm, hLeft, hRight⟩
  simp only [affineScalarMulImpl_eq_smulFold]
  rw [← genSmulFold_eq_smulFold (k1 + k2) P 256,
      ← genSmulFold_eq_smulFold k1 P 256,
      ← genSmulFold_eq_smulFold k2 P 256]
  exact m.genFold_addMul k1 k2 256 P h1 h2 hs

theorem affineScalarMulImpl_mulMul_of_laws
    (hAssoc : ∀ X Y Z : AffinePoint, affineAdd (affineAdd X Y) Z = affineAdd X (affineAdd Y Z))
    (hComm : ∀ X Y : AffinePoint, affineAdd X Y = affineAdd Y X)
    (hLeft : ∀ X : AffinePoint, affineAdd affineIdentity X = X)
    (hRight : ∀ X : AffinePoint, affineAdd X affineIdentity = X)
    (k1 k2 : Nat) (P : AffinePoint)
    (h1 : k1 < 2 ^ 256) (h2 : k2 < 2 ^ 256) (hp : k1 * k2 < 2 ^ 256) :
    affineScalarMulImpl k1 (affineScalarMulImpl k2 P) = affineScalarMulImpl (k1 * k2) P := by
  let m : OpCommMonoid AffinePoint := ⟨affineAdd, affineIdentity, hAssoc, hComm, hLeft, hRight⟩
  simp only [affineScalarMulImpl_eq_smulFold]
  rw [← genSmulFold_eq_smulFold k1 (smulFold k2 P 256) 256,
      ← genSmulFold_eq_smulFold k2 P 256,
      ← genSmulFold_eq_smulFold (k1 * k2) P 256]
  exact m.genFold_mulMul k1 k2 256 P h1 h2 hp

/-- The 20 explicit residual conditions required by
`affineAdd_associative_of_complete` for a triple `(P, Q, R)`, stated verbatim. -/
structure AffineAssocConditions (P Q R : AffinePoint) : Prop where
  hcP : IsCanonical P
  hcQ : IsCanonical Q
  hcR : IsCanonical R
  hP : ¬ P.inf
  hQ : ¬ Q.inf
  hR : ¬ R.inf
  hEP : edwardsEq (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
  hEQ : edwardsEq (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)
  hER : edwardsEq (ed25519D : ZMod ed25519P) (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)
  hxP : (P.x : ZMod ed25519P) ≠ 0
  hxQ : (Q.x : ZMod ed25519P) ≠ 0
  hxR : (R.x : ZMod ed25519P) ≠ 0
  hu12 : ((edwardsToMont (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)).1) ≠
    (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).1
  hu23 : (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).1 ≠
    (edwardsToMont (ed25519D : ZMod ed25519P) (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).1
  hu12_3 : (montAdd (ed25519D : ZMod ed25519P)
    (edwardsToMont (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)).1
    (edwardsToMont (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)).2
    (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).1
    (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).2).1 ≠
    (edwardsToMont (ed25519D : ZMod ed25519P) (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).1
  hu1_23 : (edwardsToMont (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)).1 ≠
    (montAdd (ed25519D : ZMod ed25519P)
    (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).1
    (edwardsToMont (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).2
    (edwardsToMont (ed25519D : ZMod ed25519P) (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).1
    (edwardsToMont (ed25519D : ZMod ed25519P) (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).2).1
  hy12 : 1 - (edAddField (ed25519D : ZMod ed25519P)
    (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).2 ≠ 0
  hy23 : 1 - (edAddField (ed25519D : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)
    (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).2 ≠ 0
  hy12L : 1 - (edAddField (ed25519D : ZMod ed25519P)
    (edAddField (ed25519D : ZMod ed25519P)
    (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).1
    (edAddField (ed25519D : ZMod ed25519P)
    (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)).2
    (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).2 ≠ 0
  hy1R : 1 - (edAddField (ed25519D : ZMod ed25519P)
    (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
    (edAddField (ed25519D : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)
    (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).1
    (edAddField (ed25519D : ZMod ed25519P)
    (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)
    (R.x : ZMod ed25519P) (R.y : ZMod ed25519P)).2).2 ≠ 0

/-- Associativity of `affineAdd` from exactly those conditions. -/
theorem affineAdd_assoc_ofConditions (P Q R : AffinePoint)
    (h : AffineAssocConditions P Q R) :
    affineAdd (affineAdd P Q) R = affineAdd P (affineAdd Q R) :=
  affineAdd_associative_of_complete P Q R h.hcP h.hcQ h.hcR h.hP h.hQ h.hR h.hEP h.hEQ h.hER h.hxP h.hxQ h.hxR h.hu12 h.hu23 h.hu12_3 h.hu1_23 h.hy12 h.hy23 h.hy12L h.hy1R
end LeanFormalization
