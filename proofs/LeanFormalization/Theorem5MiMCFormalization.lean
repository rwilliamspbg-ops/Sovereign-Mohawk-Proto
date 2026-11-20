import Mathlib.Data.ZMod.Basic
import Mathlib.FieldTheory.Finite.Basic
import Mathlib.Algebra.GroupWithZero.Basic

namespace LeanFormalization

/-- BN254 scalar field prime (the prime used by MiMC in production). -/
def bn254Prime : Nat :=
  21888242871839275222246405745257275088548364400416034343698204186575808495617

/-- MiMC round exponent used over BN254 (5 is coprime to p-1). -/
def mimcExponent : Nat := 5

/-- MiMC round function over ZMod p: x ↦ (x + c)^e. -/
def mimcRound (p : Nat) (e : Nat) (c : ZMod p) (x : ZMod p) : ZMod p :=
  (x + c) ^ e

/-- Power map y ↦ y^e is injective on ZMod p when e is coprime to p-1. -/
theorem pow_injective (p e : Nat) (hp : Nat.Prime p) (he : Nat.Coprime e (p - 1))
    (hepos : 0 < e) :
    Function.Injective (fun y : ZMod p => y ^ e) := by
  haveI : Fact (Nat.Prime p) := ⟨hp⟩
  intro x y hxy
  -- Case: x = 0
  by_cases hx : x = 0
  · have hy : y = 0 := by
      have : y ^ e = 0 := by rw [show y ^ e = x ^ e from hxy.symm, hx]; simp [zero_pow (Nat.ne_of_gt hepos)]
      exact (pow_eq_zero_iff (Nat.ne_of_gt hepos)).mp this
    rw [hx, hy]
  · -- x ≠ 0; then y ≠ 0
    have hyne : y ≠ 0 := by
      intro hy
      have : x ^ e = 0 := by rw [show x ^ e = y ^ e from hxy, hy]; simp [zero_pow (Nat.ne_of_gt hepos)]
      have hxpow : x ^ e ≠ 0 := pow_ne_zero e hx
      exact hxpow this
    -- r = x * y^{-1}; r^e = 1
    have hrpow : (x * y⁻¹) ^ e = 1 := by
      have h1 : (x * y⁻¹) ^ e = x ^ e * (y⁻¹) ^ e := mul_pow x y⁻¹ e
      have h2 : x ^ e * (y⁻¹) ^ e = y ^ e * (y⁻¹) ^ e := by rw [show x ^ e = y ^ e from hxy]
      have h3 : y ^ e * (y⁻¹) ^ e = (y * y⁻¹) ^ e := (mul_pow y y⁻¹ e).symm
      have hcancel : y * y⁻¹ = 1 := mul_inv_cancel₀ hyne
      have h4 : (y * y⁻¹) ^ e = 1 ^ e := by rw [hcancel]
      rw [h1, h2, h3, h4]
      simp
    -- Fermat: r^(p-1) = 1
    have hrne : (x * y⁻¹) ≠ 0 := by
      intro h
      have hyinv : y⁻¹ ≠ 0 := by
        intro hi
        have : y = 0 := inv_eq_zero.mp hi
        exact hyne this
      have : x = 0 := (mul_eq_zero.mp h).resolve_right hyinv
      exact hx this
    have hrfermat : (x * y⁻¹) ^ (p - 1) = 1 := by
      have h := FiniteField.pow_card_sub_one_eq_one (x * y⁻¹) hrne
      rw [ZMod.card p] at h
      exact h
    -- coprime => r = 1
    have hrone : x * y⁻¹ = 1 := by
      have hcond : (x * y⁻¹) ^ e = 1 ∧ (x * y⁻¹) ^ (p - 1) = 1 := ⟨hrpow, hrfermat⟩
      exact (pow_eq_one_iff_of_coprime he).mp hcond
    -- r = 1 => x = y
    have hcancel2 : y * y⁻¹ = 1 := mul_inv_cancel₀ hyne
    have hinv2 : y⁻¹ * y = 1 := by rw [mul_comm, hcancel2]
    have hxyeq : x = y := by
      have h1 : x * y⁻¹ * y = 1 * y := by rw [hrone]
      rwa [mul_assoc, hinv2, mul_one, one_mul] at h1
    exact hxyeq

/-- MiMC round is injective when e is coprime to p-1 (so the power map
    is a permutation of the multiplicative group, plus the zero case). -/
theorem mimcRound_injective (p e : Nat) (hp : Nat.Prime p) (he : Nat.Coprime e (p - 1))
    (hepos : 0 < e) (c : ZMod p) :
    Function.Injective (mimcRound p e c) := by
  haveI : Fact (Nat.Prime p) := ⟨hp⟩
  intro a b hab
  unfold mimcRound at hab
  -- shift by c: let x = a+c, y = b+c
  have hpow : (a + c) ^ e = (b + c) ^ e := hab
  have hxy : (a + c) = (b + c) := pow_injective p e hp he hepos hpow
  exact add_right_cancel hxy

/-- Concrete guard: over the small prime 7 with exponent 5, MiMC round is
    injective (sanity check of the general theorem). -/
theorem mimcRound_small_prime_guard :
    Function.Injective (mimcRound 7 5 (0 : ZMod 7)) := by
  apply mimcRound_injective
  · decide
  · decide
  · decide


/-- The BN254 scalar order is `2 (mod 5)`, so `bn254Prime - 1` is `1 (mod 5)` and
    5 does not divide it. Discharged concretely by kernel reduction (`decide`,
    not `native_decide`, so no extra axiom is introduced). -/
theorem bn254Prime_mod_5 : bn254Prime % 5 = 2 := by
  decide

/-- The MiMC exponent is coprime to `bn254Prime - 1`. Discharged concretely via
    a mod-5 reduction (a direct kernel `decide` on the 254-bit `Nat.Coprime` also
    works but is far slower). -/
theorem bn254Exponent_coprime : Nat.Coprime mimcExponent (bn254Prime - 1) := by
  unfold Nat.Coprime mimcExponent
  rw [Nat.gcd_rec]
  have h : (bn254Prime - 1) % 5 = 1 := by
    have := bn254Prime_mod_5
    omega
  rw [h]
  norm_num

/-- MiMC round injectivity at the **BN254 scalar field** -- the field the Go
    circuit in `internal/zkweight_circuit.go` actually hashes over.

    `Nat.Prime bn254Prime` is an explicit hypothesis rather than a discharged
    fact: the primality of the alt_bn128 scalar order is a published constant,
    and Mathlib's `Nat.Prime` decidability is trial division, so `native_decide`
    does not terminate in reasonable time (measured: >7 minutes without
    completing). The exponent coprimality -- the other hypothesis the general
    theorem needs -- IS discharged concretely above.

    What this buys over `mimcRound_small_prime_guard`: the injectivity lemma is
    now *stated* at the real modulus, so the paper's §7.2 caveat ("the BN254
    scalar field is named in the prose but not instantiated") is discharged for
    everything except the primality constant itself. -/
theorem mimcRound_bn254_injective (hp : Nat.Prime bn254Prime) :
    Function.Injective (mimcRound bn254Prime mimcExponent (0 : ZMod bn254Prime)) := by
  exact mimcRound_injective bn254Prime mimcExponent hp bn254Exponent_coprime (by decide) (0 : ZMod bn254Prime)


/-! ## The full MiMC construction: block cipher, compressor, Merkle–Damgård

gnark-crypto's BN254 MiMC (`ecc/bn254/fr/mimc`) is a Merkle–Damgård hasher over
field elements whose compression function is Miyaguchi–Preneel over a 110-round
block cipher:

* block cipher `E_key(m)`: 110 rounds of `m ↦ (m + key + c_i)^5`, then `+ key`;
* compressor `C(left, right) = E_left(right) + left + right`;
* hash chain: `h_0 = 0`, `h_{i+1} = C(h_i, m_i)`.

`mimcRound` above is the zero-key round. This section lifts it to the whole
construction. The round constants `cs` are a **parameter**: gnark-crypto derives
110 of them from the seed `"seed"` by a sha3-based procedure that this Mathlib
cannot reproduce, so every theorem below is generic in `cs`. Where a concrete
value is needed, `mimcModelConstants` supplies a deterministic stand-in and the
docstring says so. -/

/-- gnark-crypto's BN254 MiMC round count (`mimcNbRounds`). -/
def mimcBN254Rounds : Nat := 110

/-- One keyed MiMC block-cipher round: `m ↦ (m + key + c)^e`. -/
def mimcBlockRound (p e : Nat) (key c x : ZMod p) : ZMod p :=
  (x + key + c) ^ e

/-- The MiMC block cipher `E_key(m)` (gnark-crypto's `encrypt`): the keyed rounds
    followed by a final `+ key`. -/
def mimcEncrypt (p e : Nat) (key : ZMod p) (cs : List (ZMod p)) (m : ZMod p) : ZMod p :=
  (cs.foldl (fun acc c => mimcBlockRound p e key c acc) m) + key

/-- Miyaguchi–Preneel compressor `C(left, right) = E_left(right) + left + right`. -/
def mimcCompress (p e : Nat) (left : ZMod p) (cs : List (ZMod p)) (right : ZMod p) : ZMod p :=
  mimcEncrypt p e left cs right + left + right

/-- Merkle–Damgård hash chain from an initial state over a list of blocks. -/
def mimcHashChain (p e : Nat) (cs : List (ZMod p)) (init : ZMod p)
    (inputs : List (ZMod p)) : ZMod p :=
  inputs.foldl (fun h m => mimcCompress p e h cs m) init

/-- The one-block hash used by `DataCommitmentCircuit`
    (`Commitment = MiMC(Preimage)`): the chain from the zero initial state over
    the single preimage block. -/
def mimcHashOneBlock (p e : Nat) (cs : List (ZMod p)) (x : ZMod p) : ZMod p :=
  mimcCompress p e 0 cs x

/-- A concrete deterministic constant sequence, used where the model needs a
    value rather than a parameter. It stands in for gnark-crypto's seed-derived
    constants; the theorems are generic in the constants, and this list is NOT
    claimed to be gnark's. -/
def mimcModelConstants (p : Nat) : List (ZMod p) :=
  (List.range mimcBN254Rounds).map (fun i => (i ^ 2 + 1 : ZMod p))

/-- Each keyed round is injective: a translation followed by the injective power
    map (`mimcRound_injective`). -/
theorem mimcBlockRound_injective (p e : Nat) (hp : Nat.Prime p)
    (he : Nat.Coprime e (p - 1)) (hepos : 0 < e) (key c : ZMod p) :
    Function.Injective (mimcBlockRound p e key c) := by
  have hround : mimcBlockRound p e key c = mimcRound p e (key + c) := by
    funext z
    simp [mimcBlockRound, mimcRound, add_assoc]
  rw [hround]
  exact mimcRound_injective p e hp he hepos (key + c)

/-- The keyed-round fold is injective, by induction on the constant list. -/
theorem mimcEncryptBody_injective (p e : Nat) (hp : Nat.Prime p)
    (he : Nat.Coprime e (p - 1)) (hepos : 0 < e) (key : ZMod p) (cs : List (ZMod p)) :
    Function.Injective
      (fun m : ZMod p => cs.foldl (fun acc c => mimcBlockRound p e key c acc) m) := by
  induction cs with
  | nil => intro a b h; simpa using h
  | cons c cs ih =>
      intro a b h
      simp only [List.foldl_cons] at h
      exact mimcBlockRound_injective p e hp he hepos key c (ih h)

/-- The MiMC block cipher is injective in the message for every key. -/
theorem mimcEncrypt_injective (p e : Nat) (hp : Nat.Prime p)
    (he : Nat.Coprime e (p - 1)) (hepos : 0 < e) (key : ZMod p) (cs : List (ZMod p)) :
    Function.Injective (mimcEncrypt p e key cs) := by
  intro a b h
  unfold mimcEncrypt at h
  exact mimcEncryptBody_injective p e hp he hepos key cs (add_right_cancel h)

/-- The MiMC block cipher is a **permutation** of the field for every key: each
    keyed round is a translation followed by an injective power map, and the
    final `+ key` is a translation. -/
theorem mimcEncrypt_bijective (p e : Nat) (hp : Nat.Prime p)
    (he : Nat.Coprime e (p - 1)) (hepos : 0 < e) (key : ZMod p) (cs : List (ZMod p)) :
    Function.Bijective (mimcEncrypt p e key cs) := by
  haveI : Fact (Nat.Prime p) := ⟨hp⟩
  exact (mimcEncrypt_injective p e hp he hepos key cs).bijective_of_finite

/-- A bijective block cipher has exactly one preimage per digest. -/
theorem mimcEncrypt_preimage_unique (p e : Nat) (hp : Nat.Prime p)
    (he : Nat.Coprime e (p - 1)) (hepos : 0 < e) (key : ZMod p) (cs : List (ZMod p))
    (digest : ZMod p) : ∃! m, mimcEncrypt p e key cs m = digest := by
  haveI : Fact (Nat.Prime p) := ⟨hp⟩
  exact (mimcEncrypt_bijective p e hp he hepos key cs).existsUnique digest

/-- The one-block hash is **not** the identity: a concrete field element hashes
    to a different one (small-prime guard instance). This is the non-triviality
    witness the identity stand-in in `Refinement.ZKCircuit` previously lacked. -/
theorem mimcHashOneBlock_not_id :
    mimcHashOneBlock 7 5 [1, 2, 3] (1 : ZMod 7) ≠ (1 : ZMod 7) := by
  decide

end LeanFormalization
