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

end LeanFormalization
