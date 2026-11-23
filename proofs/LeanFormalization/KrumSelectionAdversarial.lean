import Mathlib
import LeanFormalization.KrumSelection

/-!
# Multi-Krum selection under adversarial clustering

`KrumSelection.lean` proves `krum_selection_safe`: under a clustering/separation
model, every honest candidate's Krum score is strictly below every Byzantine
candidate's. The separation hypothesis is an **assumption about the
adversary's placement**, and this module makes the consequences of that
assumption precise in both directions.

## Graceful degradation (the positive result)

`krum_selection_safe` is generalised in `KrumSelection.lean` from "all Byzantine candidates are
separated" to "the candidates in `Far ⊆ Byzantine` are separated". That is
exactly what an adversary who infiltrates the honest cluster forces: split the
Byzantine set into `Far` (separated by at least `D`) and `Near` (placed inside
the honest cluster). `krum_selection_infiltration` then says every `Far`
candidate is still beaten by some honest candidate, and
`krum_minimizer_in_honest_or_near` says a minimizer of the Krum score is honest
or a `Near` infiltrator. **The number of Byzantine winners is bounded by the
number of infiltrators** — the rule degrades gracefully rather than collapsing.

## The assumption is load-bearing (the negative result)

`krum_selection_separation_necessary` is a machine-checked witness that the
separation hypothesis cannot be dropped: place the single Byzantine candidate
exactly on the honest cluster (all gradients equal). Then every Krum score is
`0`, so the Byzantine candidate is not beaten, and the strict conclusion of
`krum_selection_safe` is false — while the honest-cluster hypothesis and the
margin condition both hold.

## Not claimed

* Nothing here says the honest cluster exists in deployment, or bounds how many
  candidates an adversary can place inside it. `Near` is arbitrary; the result
  is a bound on the *damage*, not a guarantee that `Near` is small.
* The score is the abstract normed-space `krumScore` (`Specification.neighborScore`
  is the runtime's concrete version). The correspondence is by definition — the
  same formula — not a machine-checked equality against Go.
-/

namespace LeanFormalization

open scoped BigOperators

variable {α : Type*} [DecidableEq α] [Fintype α]
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E]

omit [InnerProductSpace ℝ E] in
/-- **Graceful degradation under cluster infiltration.** Split the Byzantine
    candidates into `Far` (separated from every honest candidate) and `Near`
    (infiltrators). Every `Far` candidate's Krum score is strictly above some
    honest candidate's. -/
theorem krum_selection_infiltration (g : α → E) (H Far Near : Finset α) (n f : ℕ) (r D : ℝ)
    (hn : Finset.card (Finset.univ : Finset α) = n)
    (hHcard : H.card = n - f)
    (hByz : Far ∪ Near = Finset.univ \ H)
    (hne : n > 2 * f + 2)
    (hcluster : ∀ i ∈ H, ∀ j ∈ H, distSq g i j ≤ 4 * r ^ 2)
    (hsep : ∀ i ∈ Far, ∀ j ∈ H, D ^ 2 ≤ distSq g i j)
    (hsep_strong : (↑(n - f - 2) : ℝ) * (4 * r ^ 2)
        < (↑(n - 2 * f - 1) : ℝ) * D ^ 2) :
    ∀ j ∈ Far, ∃ i ∈ H, krumScore g i (n - f - 2) < krumScore g j (n - f - 2) := by
  have hFar_sub : Far ⊆ Finset.univ \ H := fun x hx => hByz ▸ Finset.subset_union_left hx
  have hHpos : 0 < H.card := by rw [hHcard]; omega
  obtain ⟨i₀, hi₀⟩ := Finset.card_pos.mp hHpos
  intro j hjFar
  exact ⟨i₀, hi₀,
    (krum_selection_safe g H Far n f r D hn hHcard hFar_sub hne hcluster hsep hsep_strong)
      i₀ hi₀ j hjFar⟩

omit [InnerProductSpace ℝ E] in
/-- Consequently a minimizer of the Krum score over **all** candidates is honest
    or a `Near` infiltrator — never a separated Byzantine candidate. -/
theorem krum_minimizer_in_honest_or_near (g : α → E) (H Far Near : Finset α) (n f : ℕ) (r D : ℝ)
    (hn : Finset.card (Finset.univ : Finset α) = n)
    (hHcard : H.card = n - f)
    (hByz : Far ∪ Near = Finset.univ \ H)
    (hne : n > 2 * f + 2)
    (hcluster : ∀ i ∈ H, ∀ j ∈ H, distSq g i j ≤ 4 * r ^ 2)
    (hsep : ∀ i ∈ Far, ∀ j ∈ H, D ^ 2 ≤ distSq g i j)
    (hsep_strong : (↑(n - f - 2) : ℝ) * (4 * r ^ 2)
        < (↑(n - 2 * f - 1) : ℝ) * D ^ 2) :
    ∀ j : α, (∀ i : α, krumScore g j (n - f - 2) ≤ krumScore g i (n - f - 2)) →
      j ∈ H ∨ j ∈ Near := by
  intro j hmin
  by_contra h
  have hjnotH : j ∉ H := fun hjH => h (Or.inl hjH)
  have hjnotNear : j ∉ Near := fun hjN => h (Or.inr hjN)
  have hjUniv : j ∈ Finset.univ := Finset.mem_univ j
  have hjByz : j ∈ Finset.univ \ H := Finset.mem_sdiff.mpr ⟨hjUniv, hjnotH⟩
  have hjFar : j ∈ Far := by
    have := hByz ▸ hjByz
    rcases Finset.mem_union.mp this with h | h
    · exact h
    · exact absurd h hjnotNear
  obtain ⟨i, hiH, hlt⟩ := krum_selection_infiltration g H Far Near n f r D hn hHcard hByz hne
    hcluster hsep hsep_strong j hjFar
  have := hmin i
  linarith

/-- **The separation hypothesis is load-bearing.** With `n = 5`, `f = 1`, the
    honest set `{0,1,2,3}`, `Far = {4}`, radius `r = 0` and separation `D = 1`,
    place the Byzantine candidate exactly on the honest cluster (all gradients
    equal). Then `hcluster` and the margin condition hold, every Krum score is
    `0`, and the strict conclusion of `krum_selection_safe` is **false**. -/
theorem krum_selection_separation_necessary :
    ∃ (g : Fin 5 → ℝ) (H Far : Finset (Fin 5)),
      Finset.card (Finset.univ : Finset (Fin 5)) = 5 ∧
      H.card = 4 ∧
      Far ⊆ Finset.univ \ H ∧
      Far.Nonempty ∧
      5 > 2 * 1 + 2 ∧
      (∀ i ∈ H, ∀ j ∈ H, distSq g i j ≤ 4 * (0 : ℝ) ^ 2) ∧
      (((5 - 1 - 2 : ℕ) : ℝ) * (4 * (0 : ℝ) ^ 2)
        < ((5 - 2 * 1 - 1 : ℕ) : ℝ) * (1 : ℝ) ^ 2) ∧
      ¬ (∀ i ∈ H, ∀ j ∈ Far,
        krumScore g j (5 - 1 - 2) > krumScore g i (5 - 1 - 2)) := by
  let g : Fin 5 → ℝ := fun _ => 0
  let H : Finset (Fin 5) := Finset.univ.filter (· < 4)
  let Far : Finset (Fin 5) := {4}
  refine ⟨g, H, Far, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · show (Finset.univ : Finset (Fin 5)).card = 5
    simp
  · show H.card = 4
    decide
  · intro x hx
    simp [Far] at hx
    subst hx
    simp [H]
  · show Far.Nonempty
    simp [Far]
  · norm_num
  · intro i _ j _
    simp [g, distSq]
  · norm_num
  · have hscore : ∀ i : Fin 5, krumScore g i 2 = 0 := by
      intro i
      have hk : (2 : ℕ) ≤ (Finset.univ.erase i).card := by
        rw [Finset.card_erase_of_mem (Finset.mem_univ i)]
        norm_num
      have hle : krumScore g i 2 ≤ 0 := by
        obtain ⟨S, hSsub, hScard⟩ := exists_subset_card_eq_of_le hk
        refine krumScore_le_of_exists_subset g i 2 hk hSsub hScard ?_
        have hzero : ∑ l ∈ S, distSq g i l = 0 := by
          apply Finset.sum_eq_zero
          intro l _
          simp [g, distSq]
        rw [hzero]
      have hge : (0 : ℝ) ≤ krumScore g i 2 := by
        refine le_krumScore_of_forall_subset g i 2 hk ?_
        intro S _ _
        exact Finset.sum_nonneg (fun l _ => by simp [g, distSq])
      linarith
    intro h
    have h0H : (0 : Fin 5) ∈ H := by simp [H]
    have h4F : (4 : Fin 5) ∈ Far := by simp [Far]
    have hgt : krumScore g 4 2 > krumScore g 0 2 := h 0 h0H 4 h4F
    rw [hscore 4, hscore 0] at hgt
    norm_num at hgt

/-- The explicit separation threshold implied by `krum_selection_safe`'s
    sufficient condition: `D ^ 2` must exceed
    `(n - f - 2) * 4 r ^ 2 / (n - 2 f - 1)`, whose denominator is positive
    under the runtime guard `n > 2 f + 2`. -/
theorem krum_separation_margin (n f : ℕ) (r D : ℝ) (hne : n > 2 * f + 2)
    (h : (↑(n - f - 2) : ℝ) * (4 * r ^ 2) < (↑(n - 2 * f - 1) : ℝ) * D ^ 2) :
    (↑(n - f - 2) : ℝ) * (4 * r ^ 2) / (↑(n - 2 * f - 1) : ℝ) < D ^ 2 := by
  have hpos : (0 : ℝ) < (↑(n - 2 * f - 1) : ℝ) := by
    have : 1 ≤ n - 2 * f - 1 := by omega
    exact_mod_cast this
  have h' : (↑(n - f - 2) : ℝ) * (4 * r ^ 2) < D ^ 2 * (↑(n - 2 * f - 1) : ℝ) := by
    calc (↑(n - f - 2) : ℝ) * (4 * r ^ 2) < (↑(n - 2 * f - 1) : ℝ) * D ^ 2 := h
      _ = D ^ 2 * (↑(n - 2 * f - 1) : ℝ) := by ring
  exact (div_lt_iff₀ hpos).mpr h'

end LeanFormalization
