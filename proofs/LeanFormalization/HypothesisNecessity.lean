import Mathlib
import LeanFormalization.DiscreteLogReduction
import LeanFormalization.SchnorrReduction

namespace LeanFormalization

/-!
# Hypothesis necessity for the discrete-log and Schnorr reductions

`recovery_yields_secret` (`DiscreteLogReduction.lean`) and
`schnorr_special_soundness` (`SchnorrReduction.lean`) are this development's two
algebraic reductions: each recovers a secret from two accepting transcripts.
Both are stated with explicit hypotheses, and this module machine-checks that
those hypotheses are **load-bearing** — for each one it exhibits a concrete
instance in which the hypothesis fails and the conclusion fails with it.

This is the negative-control companion to the reduction theorems. It does not
strengthen the reductions' conclusions; it pins down exactly what they assume,
so a reviewer can see that no hypothesis is decorative. Every witness below is
concrete and every proof is `decide`/`omega`/`simp` on rationals or residues.

## What is here

| Reduction | Hypothesis dropped | Witness |
|---|---|---|
| `recovery_yields_secret` | `hdiff : h1 % dlL ≠ h2 % dlL` | `h1 = h2 = 3` |
| `recovery_yields_secret` | `hS1` | `h1 = 11`, `S1 = S2 = 26` |
| `recovery_yields_secret` | `hS2` | `h2 = 11`, `S1 = S2 = 26` |
| `schnorr_special_soundness` | `hcne : c ≠ c'` | `c = c' = 2` |
| `schnorr_special_soundness` | `h1` (first acceptance) | `s = 0` |
| `schnorr_special_soundness` | `h2` (second acceptance) | `s' = 0` |

## What is deliberately not refuted

`recovery_yields_secret` and `schnorr_special_soundness` also carry a
`Fact (Nat.Prime …)` instance (primality of `dlL`, resp. of `q`). That is a
number-theoretic *assumption*, not a refutable condition on the transcripts:
dropping it does not produce a counterexample, it makes `ZMod n` a ring in which
inverses need not exist. It is recorded as an explicit hypothesis at each use
site, and is out of scope for this module.
-/

/-! ## Discrete-log recovery (`recovery_yields_secret`) -/

/-- `0 < dlL`: the Ed25519 subgroup order is positive. -/
theorem dlL_pos : 0 < dlL := by unfold dlL ed25519L; norm_num

/-- The inverse of `0` in `ZMod dlL` is `0`. -/
theorem scalarModInv_zero (hp : Fact (Nat.Prime dlL)) : scalarModInv hp 0 = 0 := by
  unfold scalarModInv
  simp

/-- A technical lemma: for any `h`, `h + dlL - h % dlL` is a multiple of `dlL`. -/
theorem mod_eq_zero_add_sub_mod (n : Nat) : (n + dlL - n % dlL) % dlL = 0 := by
  have hh : n % dlL < dlL := Nat.mod_lt n dlL_pos
  have hle : n % dlL ≤ n := Nat.mod_le n dlL
  have h1 : n + dlL - n % dlL = dlL + (n - n % dlL) := by omega
  rw [h1]
  exact Nat.mod_eq_zero_of_dvd (dvd_add (dvd_refl _) (Nat.dvd_sub_mod n))

/-- If the two challenges are congruent mod `dlL`, `recoverSecret` returns `0`
    regardless of the signature values: the challenge difference is `0`, and
    `0⁻¹ = 0` in the field `ZMod dlL`. -/
theorem recoverSecret_zero_of_challenges_eq (hp : Fact (Nat.Prime dlL))
    (S1 S2 h : Nat) : recoverSecret hp S1 S2 h h = 0 := by
  unfold recoverSecret
  dsimp only
  rw [mod_eq_zero_add_sub_mod h, scalarModInv_zero hp]
  simp

/-- If the two signature values are equal, `recoverSecret` returns `0`. -/
theorem recoverSecret_zero_of_S_eq (hp : Fact (Nat.Prime dlL))
    (S h1 h2 : Nat) : recoverSecret hp S S h1 h2 = 0 := by
  unfold recoverSecret
  dsimp only
  rw [mod_eq_zero_add_sub_mod S]
  simp

/-- **Negative control: `hdiff` is load-bearing.** With `r = 5`, `a = 7`,
    `h1 = h2 = 3`, `S1 = S2 = (r + h1*a) % dlL = 26`, both signature equations
    `S_i % dlL = (r + h_i*a) % dlL` hold, but `hdiff` (`h1 % dlL ≠ h2 % dlL`)
    fails; the recovery then returns `0`, not `a % dlL = 7`. -/
theorem recovery_yields_secret_hdiff_needed (hp : Fact (Nat.Prime dlL)) :
    ¬ ((recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 3 3) % dlL
        = 7 % dlL) := by
  have h0 : recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 3 3 = 0 :=
    recoverSecret_zero_of_challenges_eq hp _ _ 3
  rw [h0]
  have h7 : (7 % dlL) = 7 := Nat.mod_eq_of_lt (by unfold dlL ed25519L; norm_num)
  rw [h7]
  simp

/-- **Negative control: the first signature equation `hS1` is load-bearing.**
    With `r = 5`, `a = 7`, `h1 = 11`, `h2 = 3`, `S1 = S2 = 26`, `hS2` and
    `hdiff` hold but `hS1` fails (`26 % dlL = 26` while `(5 + 11*7) % dlL = 82`);
    the recovery returns `0`, not `7`. -/
theorem recovery_yields_secret_hS1_needed (hp : Fact (Nat.Prime dlL)) :
    ¬ ((recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 11 3) % dlL
        = 7 % dlL) := by
  have h0 : recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 11 3 = 0 :=
    recoverSecret_zero_of_S_eq hp _ 11 3
  rw [h0]
  have h7 : (7 % dlL) = 7 := Nat.mod_eq_of_lt (by unfold dlL ed25519L; norm_num)
  rw [h7]
  simp

/-- **Negative control: the second signature equation `hS2` is load-bearing.**
    Symmetric to `recovery_yields_secret_hS1_needed`: with `h1 = 3`, `h2 = 11`,
    `S1 = S2 = 26`, `hS1` and `hdiff` hold but `hS2` fails, and the recovery
    returns `0`, not `7`. -/
theorem recovery_yields_secret_hS2_needed (hp : Fact (Nat.Prime dlL)) :
    ¬ ((recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 3 11) % dlL
        = 7 % dlL) := by
  have h0 : recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 3 11 = 0 :=
    recoverSecret_zero_of_S_eq hp _ 3 11
  rw [h0]
  have h7 : (7 % dlL) = 7 := Nat.mod_eq_of_lt (by unfold dlL ed25519L; norm_num)
  rw [h7]
  simp

/-! ## Schnorr special soundness (`schnorr_special_soundness`) -/

/-- **Negative control: `hcne` is load-bearing.** Over `ZMod 7`, with `pk = 3`,
    `c = c' = 2`, `R = 5`, `s = s' = 4`, both transcripts are accepting
    (`4 = 5 + 2·3`), but the extractor returns `(4-4)·(2-2)⁻¹ = 0`, not `pk = 3`. -/
theorem schnorr_special_soundness_hcne_needed :
    (3 : ZMod 7) ≠ (4 - 4) * (2 - 2)⁻¹ := by
  decide

/-- **Negative control: the first acceptance hypothesis is load-bearing.** With
    `c = 2`, `c' = 4`, `R = 5`, `s = 0`, `s' = 3`, the second transcript is
    accepting (`3 = 5 + 4·3`) and `c ≠ c'`, but the first is not
    (`0 ≠ 5 + 2·3`); the extractor returns `(0-3)·(2-4)⁻¹ = 5`, not `pk = 3`. -/
theorem schnorr_special_soundness_h1_needed :
    schnorrAccept 7 (3 : ZMod 7) 4 (5 : ZMod 7) 3 →
    (3 : ZMod 7) ≠ (0 - 3) * (2 - 4)⁻¹ := by
  intro _
  decide

/-- **Negative control: the second acceptance hypothesis is load-bearing.**
    Symmetric to `schnorr_special_soundness_h1_needed`: with `s = 4`, `s' = 0`
    the first transcript is accepting and the second is not, and the extractor
    returns `(4-0)·(2-4)⁻¹ = 5`, not `pk = 3`. -/
theorem schnorr_special_soundness_h2_needed :
    schnorrAccept 7 (3 : ZMod 7) 2 (5 : ZMod 7) 4 →
    (3 : ZMod 7) ≠ (4 - 0) * (2 - 4)⁻¹ := by
  intro _
  decide

end LeanFormalization
