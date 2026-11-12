import Mathlib
import LeanFormalization.ProtocolSafety

/-!
# Multi-Krum Selection Safety under a Stated Clustering Model

`ProtocolSafety.lean` bounds the probability that the runtime's `n > 2f + 2`
precondition fails. It does not settle **selection safety**: whether the
Multi-Krum rule, once it runs, actually picks an honest candidate.

This module settles that question under an explicit clustering/separation
model, stated up front:

* **Honest cluster.** All honest candidates' gradients lie within squared
  distance `4r²` of each other (a ball of radius `2r`).
* **Byzantine separation.** Every Byzantine candidate is at squared distance at
  least `D²` from every honest candidate.
* **Guard.** `n > 2f + 2`, the runtime's own precondition, and `k = n - f - 2`
  neighbours, the runtime's own derived neighbour count.

Under those hypotheses, `krum_selection_safe` proves that **every honest
candidate's Krum score is strictly below every Byzantine candidate's**,
provided the separation is large enough relative to the cluster radius:

    (n - f - 2) · 4r²  <  (n - 2f - 1) · D²

so any minimizer of the Krum score is honest.

## Why the guard appears

The `n > 2f + 2` precondition is what makes the two bounds work:

* For an honest candidate `i`, there are `n - f - 1` other honest candidates.
  Since `k = n - f - 2 ≤ n - f - 1`, the `k` nearest neighbours can all be
  honest, so the honest score is at most `k · 4r²`.
* For a Byzantine candidate `j`, at most `f - 1` other candidates are Byzantine,
  so at least `k - (f - 1) = n - 2f - 1` of its `k` nearest neighbours are
  honest, each at distance at least `D`. This needs `n - 2f - 1 > 0`, i.e.
  `n > 2f + 1`, which the guard implies.

## What is not claimed

* The clustering/separation model is an **assumption**, not something the
  protocol enforces. Real gradients are not guaranteed to form a tight cluster
  with the adversary far away; a strong adversary can place gradients inside the
  honest cluster. This theorem says what the guard buys *under the model*, not
  that the model holds in deployment.
* The Krum score here is the abstract normed-space score
  (`Specification.neighborScore` over `FloatArray` is the runtime's concrete
  version). The correspondence is by definition — the same formula — not a
  machine-checked equality, since Lean cannot invoke Go source.
-/

namespace LeanFormalization

open scoped BigOperators

variable {α : Type*} [DecidableEq α] [Fintype α]
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E]

/-- Squared distance between candidates `i` and `j`. -/
noncomputable def distSq (g : α → E) (i j : α) : ℝ := ‖g i - g j‖ ^ 2

/-- The Krum score of candidate `i` with `k` neighbours: the minimum, over all
`k`-element subsets of the *other* candidates, of the sum of squared distances
to them. This is `Specification.neighborScore`'s quantity, written over a
normed space. -/
noncomputable def krumScore (g : α → E) (i : α) (k : ℕ) : ℝ :=
  if hk : k ≤ (Finset.univ.erase i).card then
    (((Finset.univ.erase i).powersetCard k).image
      (fun S => ∑ j ∈ S, distSq g i j)).min'
      (by
        obtain ⟨S, hS⟩ := Finset.powersetCard_nonempty.mpr hk
        exact ⟨∑ j ∈ S, distSq g i j, Finset.mem_image.mpr ⟨S, hS, rfl⟩⟩)
  else 0

omit [InnerProductSpace ℝ E] in
/-- Upper bound: if some `k`-element subset of the other candidates has total
squared distance at most `B`, then the Krum score — the minimum over all such
subsets — is at most `B`. -/
theorem krumScore_le_of_exists_subset (g : α → E) (i : α) (k : ℕ)
    (hk : k ≤ (Finset.univ.erase i).card) {S : Finset α}
    (hS : S ⊆ Finset.univ.erase i) (hcard : S.card = k) {B : ℝ}
    (hB : ∑ j ∈ S, distSq g i j ≤ B) : krumScore g i k ≤ B := by
  rw [krumScore, dif_pos hk]
  have hmem : (∑ j ∈ S, distSq g i j) ∈
      ((Finset.univ.erase i).powersetCard k).image
        (fun S => ∑ j ∈ S, distSq g i j) := by
    rw [Finset.mem_image]
    exact ⟨S, by rw [Finset.mem_powersetCard]; exact ⟨hS, hcard⟩, rfl⟩
  exact (Finset.min'_le _ _ hmem).trans hB

omit [InnerProductSpace ℝ E] in
/-- Lower bound: if every `k`-element subset of the other candidates has total
squared distance at least `c`, then the Krum score is at least `c`. -/
theorem le_krumScore_of_forall_subset (g : α → E) (i : α) (k : ℕ)
    (hk : k ≤ (Finset.univ.erase i).card) {c : ℝ}
    (hc : ∀ S : Finset α, S ⊆ Finset.univ.erase i → S.card = k →
      c ≤ ∑ j ∈ S, distSq g i j) : c ≤ krumScore g i k := by
  rw [krumScore, dif_pos hk]
  refine Finset.le_min' _ _ _ ?_
  intro x hx
  rw [Finset.mem_image] at hx
  obtain ⟨S, hS, rfl⟩ := hx
  rw [Finset.mem_powersetCard] at hS
  exact hc S hS.1 hS.2

omit [DecidableEq α] [Fintype α] in
/-- A `k`-element subset of a set with at least `k` elements exists. -/
theorem exists_subset_card_eq_of_le {S : Finset α} {k : ℕ} (hk : k ≤ S.card) :
    ∃ T : Finset α, T ⊆ S ∧ T.card = k := by
  obtain ⟨T, hT, hTcard⟩ := Finset.exists_subset_card_eq hk
  exact ⟨T, hT, hTcard⟩

omit [InnerProductSpace ℝ E] in
/-- **Selection safety.** Under the clustering/separation model and the runtime
guard `n > 2f + 2`, every honest candidate's Krum score is strictly below every
Byzantine candidate's, provided the separation is large enough:

    (n - f - 2) · 4r²  <  (n - 2f - 1) · D²

Consequently any minimizer of the Krum score is honest. -/
theorem krum_selection_safe (g : α → E) (H : Finset α) (n f : ℕ) (r D : ℝ)
    (hn : Finset.card (Finset.univ : Finset α) = n)
    (hHcard : H.card = n - f)
    (hne : n > 2 * f + 2)
    (hcluster : ∀ i ∈ H, ∀ j ∈ H, distSq g i j ≤ 4 * r ^ 2)
    (hsep : ∀ i ∉ H, ∀ j ∈ H, D ^ 2 ≤ distSq g i j)
    (hsep_strong : (↑(n - f - 2) : ℝ) * (4 * r ^ 2)
        < (↑(n - 2 * f - 1) : ℝ) * D ^ 2) :
    ∀ i ∈ H, ∀ j ∉ H, krumScore g j (n - f - 2) > krumScore g i (n - f - 2) := by
  intro i hiH j hjH
  have hUniv : Finset.card (Finset.univ : Finset α) = n := hn
  -- The number of Byzantine candidates is exactly `f`.
  have hdiff : ((Finset.univ : Finset α) \ H).card = f := by
    have h2 : ((Finset.univ : Finset α) \ H).card =
        (Finset.univ : Finset α).card - H.card := by
      rw [Finset.card_sdiff]
      simp
    rw [hUniv, hHcard] at h2
    omega
  have hjH' : j ∈ (Finset.univ : Finset α) \ H := by
    simp
    exact hjH
  have hf1 : 1 ≤ f := by
    have hpos : 0 < ((Finset.univ : Finset α) \ H).card := Finset.card_pos.mpr ⟨j, hjH'⟩
    omega
  have hjcard : (((Finset.univ : Finset α) \ H).erase j).card = f - 1 := by
    rw [Finset.card_erase_of_mem hjH']
    omega
  -- ---------------------------------------------------------------- honest upper
  have hkle : n - f - 2 ≤ (H.erase i).card := by
    have hHcard' : (H.erase i).card = H.card - 1 := Finset.card_erase_of_mem hiH
    rw [hHcard] at hHcard'
    omega
  obtain ⟨S, hSsub, hScard⟩ := exists_subset_card_eq_of_le hkle
  have hSH : S ⊆ H := fun x hx => (Finset.mem_erase.mp (hSsub hx)).2
  have hSsub_univ : S ⊆ Finset.univ.erase i := fun x hx => by
    have h := Finset.mem_erase.mp (hSsub hx)
    exact Finset.mem_erase.mpr ⟨h.1, Finset.mem_univ x⟩
  have hHsub : H.erase i ⊆ Finset.univ.erase i := fun x hx => by
    have h := Finset.mem_erase.mp hx
    exact Finset.mem_erase.mpr ⟨h.1, Finset.mem_univ x⟩
  have hkle_univ : n - f - 2 ≤ (Finset.univ.erase i).card :=
    hkle.trans (Finset.card_le_card hHsub)
  have hupper : krumScore g i (n - f - 2) ≤ (↑(n - f - 2) : ℝ) * (4 * r ^ 2) := by
    refine krumScore_le_of_exists_subset g i (n - f - 2) hkle_univ hSsub_univ hScard ?_
    calc ∑ l ∈ S, distSq g i l ≤ ∑ l ∈ S, 4 * r ^ 2 := by
          apply Finset.sum_le_sum
          intro l hl
          exact hcluster i hiH l (hSH hl)
      _ = (↑(n - f - 2) : ℝ) * (4 * r ^ 2) := by
          rw [Finset.sum_const, nsmul_eq_mul, ← hScard]
  -- -------------------------------------------------------------- byzantine lower
  have hklower : n - f - 2 ≤ (Finset.univ.erase j).card := by
    have hmem : j ∈ Finset.univ := Finset.mem_univ j
    have hcard := Finset.card_erase_of_mem hmem
    rw [hUniv] at hcard
    omega
  have hlower : (↑(n - 2 * f - 1) : ℝ) * D ^ 2 ≤ krumScore g j (n - f - 2) := by
    refine le_krumScore_of_forall_subset g j (n - f - 2) hklower ?_
    intro S hSsub' hScard'
    have hSbyz : S \ H ⊆ ((Finset.univ : Finset α) \ H).erase j := by
      intro y hy
      simp only [Finset.mem_sdiff] at hy
      have hyUniv : y ∈ Finset.univ.erase j := hSsub' hy.1
      simp only [Finset.mem_erase] at hyUniv
      simp
      exact ⟨hyUniv.1, hy.2⟩
    have hbound : n - 2 * f - 1 ≤ (S ∩ H).card := by
      have h1 : (S \ H).card ≤ f - 1 := by
        have hle := Finset.card_le_card hSbyz
        rw [hjcard] at hle
        exact hle
      have h2 : (S \ H).card + (S ∩ H).card = S.card :=
        Finset.card_sdiff_add_card_inter S H
      rw [hScard'] at h2
      calc n - 2 * f - 1
          = (n - f - 2) - (f - 1) := by omega
        _ ≤ (n - f - 2) - (S \ H).card := by omega
        _ = (S ∩ H).card := by omega
    calc (↑(n - 2 * f - 1) : ℝ) * D ^ 2
        ≤ (↑(S ∩ H).card : ℝ) * D ^ 2 := by
          apply mul_le_mul_of_nonneg_right _ (sq_nonneg D)
          exact_mod_cast hbound
      _ ≤ ∑ l ∈ S ∩ H, distSq g j l := by
          have hconst : (∑ l ∈ S ∩ H, (D ^ 2)) = (↑(S ∩ H).card : ℝ) * D ^ 2 := by
            rw [Finset.sum_const, nsmul_eq_mul]
          rw [← hconst]
          apply Finset.sum_le_sum
          intro l hl
          exact hsep j hjH l (Finset.mem_of_mem_inter_right hl)
      _ ≤ ∑ l ∈ S, distSq g j l := by
          apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.inter_subset_left)
          intro l _ _
          exact sq_nonneg _
  exact lt_of_le_of_lt hupper (lt_of_lt_of_le hsep_strong hlower)

end LeanFormalization
