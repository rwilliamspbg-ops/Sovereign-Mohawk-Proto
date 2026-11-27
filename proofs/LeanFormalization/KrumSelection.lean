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
theorem krum_selection_safe (g : α → E) (H Far : Finset α) (n f : ℕ) (r D : ℝ)
    (hn : Finset.card (Finset.univ : Finset α) = n)
    (hHcard : H.card = n - f)
    (hFar_sub : Far ⊆ Finset.univ \ H)
    (hne : n > 2 * f + 2)
    (hcluster : ∀ i ∈ H, ∀ j ∈ H, distSq g i j ≤ 4 * r ^ 2)
    (hsep : ∀ i ∈ Far, ∀ j ∈ H, D ^ 2 ≤ distSq g i j)
    (hsep_strong : (↑(n - f - 2) : ℝ) * (4 * r ^ 2)
        < (↑(n - 2 * f - 1) : ℝ) * D ^ 2) :
    ∀ i ∈ H, ∀ j ∈ Far, krumScore g j (n - f - 2) > krumScore g i (n - f - 2) := by
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
  have hjH' : j ∈ (Finset.univ : Finset α) \ H := hFar_sub hjH
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


/-! ## Pure Real model of the implementation's neighbor score

`Specification.neighborScore` builds the list of squared distances from
candidate `idx` to every other `FloatArray` gradient, sorts it ascending with
`Specification.sortAsc` (an insertion sort), keeps the `k` smallest entries and
folds a Float sum. Float order and Float arithmetic are opaque in this
Mathlib, so that concrete score cannot be identified with the abstract
`krumScore` by a machine-checked equality here. We isolate that gap behind one
named ℝ-valued definition.

`neighborScoreReal` is the same algorithm over ℝ: collect the squared
distances to the other candidates, insertion-sort the candidates by that key,
take `k`, sum. `neighborScoreReal_eq_krumScore` proves with no new axiom that
this Real model agrees with `krumScore` whenever `k` is feasible. The only
residual is the Float ↔ Real correspondence itself, deliberately left unproved.
-/

/-- Real mirror of `Specification.insertSorted`: insert `x` into an
ascending-sorted list of candidates, using `d` as comparison key. -/
noncomputable def neighborScoreRealInsert (d : α → ℝ) (x : α) : List α → List α
  | [] => [x]
  | y :: ys => if d x ≤ d y then x :: y :: ys else y :: neighborScoreRealInsert d x ys

/-- Real mirror of `Specification.sortAsc`: insertion sort by key `d`. -/
noncomputable def neighborScoreRealSort (d : α → ℝ) : List α → List α
  | [] => []
  | x :: xs => neighborScoreRealInsert d x (neighborScoreRealSort d xs)

/-- The pure ℝ model of `Specification.neighborScore`: squared distances from
`i` to every other candidate, ascending insertion sort, take `k`, sum. -/
noncomputable def neighborScoreReal (g : α → E) (i : α) (k : ℕ) : ℝ :=
  let s : Finset α := Finset.univ.erase i
  let d : α → ℝ := fun j => distSq g i j
  let l : List α := neighborScoreRealSort d s.toList
  ((List.map d l).take k).sum

omit [Fintype α] in
theorem neighborScoreRealInsert_mem (d : α → ℝ) (x : α) (l : List α) (z : α) :
    z ∈ neighborScoreRealInsert d x l ↔ z = x ∨ z ∈ l := by
  induction l with
  | nil => simp [neighborScoreRealInsert]
  | cons y ys ih =>
      by_cases h : d x ≤ d y
      · simp only [neighborScoreRealInsert, h, if_true, List.mem_cons]
      · simp only [neighborScoreRealInsert, h, if_false, List.mem_cons, ih]
        tauto

omit [Fintype α] in
theorem neighborScoreRealSort_mem (d : α → ℝ) : ∀ (l : List α) (z : α),
    z ∈ neighborScoreRealSort d l ↔ z ∈ l
  | [], z => by simp [neighborScoreRealSort]
  | x :: xs, z => by
      change z ∈ neighborScoreRealInsert d x (neighborScoreRealSort d xs) ↔ z ∈ x :: xs
      simp only [neighborScoreRealInsert_mem, neighborScoreRealSort_mem, List.mem_cons]

omit [Fintype α] in
theorem neighborScoreRealInsert_nodup (d : α → ℝ) (x : α) (l : List α)
    (hl : l.Nodup) (hx : x ∉ l) : (neighborScoreRealInsert d x l).Nodup := by
  induction l with
  | nil => simp [neighborScoreRealInsert]
  | cons y ys ih =>
      have hys : ys.Nodup := (List.pairwise_cons.mp hl).2
      have hxys : x ∉ ys := by intro h; exact hx (by simp [h])
      have hyx : y ≠ x := by intro h; subst h; exact hx (by simp)
      by_cases h : d x ≤ d y
      · simp [neighborScoreRealInsert, h, hx, hl]
      · have hins : (neighborScoreRealInsert d x ys).Nodup := ih hys hxys
        have hynot : y ∉ neighborScoreRealInsert d x ys := by
          intro hy
          rcases (neighborScoreRealInsert_mem d x ys y).mp hy with rfl | hy'
          · exact hyx rfl
          · exact ((List.pairwise_cons.mp hl).1 y hy') rfl
        simp [neighborScoreRealInsert, h, hins, hynot]

omit [Fintype α] in
theorem neighborScoreRealSort_nodup (d : α → ℝ) : ∀ (l : List α), l.Nodup →
    (neighborScoreRealSort d l).Nodup
  | [], hl => by simp [neighborScoreRealSort]
  | x :: xs, hl => by
      have hxs : xs.Nodup := (List.pairwise_cons.mp hl).2
      have hxnot : x ∉ neighborScoreRealSort d xs := by
        intro hx
        exact ((List.pairwise_cons.mp hl).1 x ((neighborScoreRealSort_mem d xs x).mp hx)) rfl
      change (neighborScoreRealInsert d x (neighborScoreRealSort d xs)).Nodup
      exact neighborScoreRealInsert_nodup d x (neighborScoreRealSort d xs)
        (neighborScoreRealSort_nodup d xs hxs) hxnot

omit [Fintype α] in
theorem neighborScoreRealInsert_pairwise (d : α → ℝ) (x : α) (l : List α)
    (hl : l.Pairwise (fun a b => d a ≤ d b)) :
    (neighborScoreRealInsert d x l).Pairwise (fun a b => d a ≤ d b) := by
  induction l with
  | nil => simp [neighborScoreRealInsert]
  | cons y ys ih =>
      have hhead : ∀ z ∈ ys, d y ≤ d z := (List.pairwise_cons.mp hl).1
      have htail : ys.Pairwise (fun a b => d a ≤ d b) := (List.pairwise_cons.mp hl).2
      by_cases hxy : d x ≤ d y
      · rw [neighborScoreRealInsert]
        simp only [hxy, if_true]
        exact List.pairwise_cons.mpr ⟨by
          intro z hz
          simp only [List.mem_cons] at hz
          rcases hz with rfl | hz
          · exact hxy
          · exact hxy.trans (hhead z hz), hl⟩
      · have hyx : d y ≤ d x := le_of_not_ge hxy
        rw [neighborScoreRealInsert]
        simp only [hxy, if_false]
        exact List.pairwise_cons.mpr ⟨by
          intro z hz
          rcases (neighborScoreRealInsert_mem d x ys z).mp hz with rfl | hz
          · exact hyx
          · exact hhead z hz, ih htail⟩

omit [Fintype α] in
theorem neighborScoreRealSort_pairwise (d : α → ℝ) : ∀ (l : List α),
    (neighborScoreRealSort d l).Pairwise (fun a b => d a ≤ d b)
  | [] => by simp [neighborScoreRealSort]
  | x :: xs => by
      change (neighborScoreRealInsert d x (neighborScoreRealSort d xs)).Pairwise
        (fun a b => d a ≤ d b)
      exact neighborScoreRealInsert_pairwise d x (neighborScoreRealSort d xs)
        (neighborScoreRealSort_pairwise d xs)

omit [Fintype α] in
/-- If `l` is sorted ascending by `d` and has no duplicates, then for any
finset `T ⊆ l.toFinset` of card `k`, the sum of the `k` smallest `d`-values in
`l` is at most the sum of `d` over `T`. -/
private theorem neighborScoreReal_sum_take_le_sum_subset (d : α → ℝ) (l : List α)
    (hpw : l.Pairwise (fun a b => d a ≤ d b)) (hnd : l.Nodup)
    (T : Finset α) (hTsub : T ⊆ l.toFinset) (k : ℕ) (hk : T.card = k) :
    ((List.map d l).take k).sum ≤ ∑ j ∈ T, d j := by
  induction l generalizing k T with
  | nil =>
      simp only [List.map_nil, List.take_nil, List.sum_nil]
      have hTempty : T = ∅ := by
        apply Finset.not_nonempty_iff_eq_empty.mp
        intro h
        rcases h with ⟨x, hx⟩
        exact absurd (hTsub hx) (by simp)
      simp [hTempty]
  | cons a l ih =>
      rcases List.pairwise_cons.mp hpw with ⟨hpw_head, hpw_tail⟩
      rcases List.pairwise_cons.mp hnd with ⟨ha_notin, hnd_tail⟩
      by_cases haT : a ∈ T
      · have hkpos : 0 < k := by
          have : 0 < T.card := Finset.card_pos.mpr ⟨a, haT⟩
          omega
        let T' : Finset α := T.erase a
        have hT'card : T'.card = k - 1 := by
          dsimp [T']
          rw [Finset.card_erase_of_mem haT, hk]
        have hT'sub : T' ⊆ l.toFinset := by
          intro x hx
          have hxT : x ∈ T := (Finset.mem_erase.mp hx).2
          have hxne : x ≠ a := (Finset.mem_erase.mp hx).1
          have hxins : x ∈ insert a l.toFinset := by
            rw [← List.toFinset_cons]
            exact hTsub hxT
          rcases Finset.mem_insert.mp hxins with hxa | hxl
          · exact (hxne hxa).elim
          · exact hxl
        have hih := ih hpw_tail hnd_tail T' hT'sub (k - 1) hT'card
        have htake : ((List.map d (a :: l)).take k).sum =
            d a + ((List.map d l).take (k - 1)).sum := by
          have hk1 : k - 1 + 1 = k := by omega
          calc
            ((List.map d (a :: l)).take k).sum =
                ((List.map d (a :: l)).take (k - 1 + 1)).sum := by rw [hk1]
            _ = (d a :: (List.map d l).take (k - 1)).sum := by
                  rw [List.map_cons, List.take_succ_cons]
            _ = d a + ((List.map d l).take (k - 1)).sum := by simp
        have hsumT : (∑ j ∈ T, d j) = d a + ∑ j ∈ T', d j := by
          dsimp [T']
          rw [← Finset.sum_erase_add _ _ haT]
          abel
        rw [htake, hsumT]
        linarith
      · have hT'sub : T ⊆ l.toFinset := by
          intro x hx
          have hxins : x ∈ insert a l.toFinset := by
            rw [← List.toFinset_cons]
            exact hTsub hx
          rcases Finset.mem_insert.mp hxins with hxa | hxl
          · exfalso
            rw [hxa] at hx
            exact haT hx
          · exact hxl
        have hih := ih hpw_tail hnd_tail T hT'sub k hk
        have hle_take : ((List.map d (a :: l)).take k).sum ≤
            ((List.map d l).take k).sum := by
          by_cases hk0 : k = 0
          · rw [hk0]
            simp
          · have hkle : k ≤ l.length := by
              have hcardle : T.card ≤ l.toFinset.card := Finset.card_le_card hT'sub
              rw [List.toFinset_card_of_nodup hnd_tail, hk] at hcardle
              exact hcardle
            have hkm1lt : k - 1 < l.length := by omega
            have hp : k - 1 < (List.map d l).length := by simpa using hkm1lt
            have hsumk : ((List.map d l).take k).sum =
                ((List.map d l).take (k - 1)).sum + (List.map d l)[k - 1] := by
              have h := List.sum_take_succ (List.map d l) (k - 1) hp
              have hk1 : k - 1 + 1 = k := by omega
              simpa [hk1] using h
            have hlast : (List.map d l)[k - 1] = d (l[k - 1]) := by
              exact List.getElem_map d (i := k - 1) (h := hp)
            have hsumc : ((List.map d (a :: l)).take k).sum =
                d a + ((List.map d l).take (k - 1)).sum := by
              have hk1 : k - 1 + 1 = k := by omega
              calc
                ((List.map d (a :: l)).take k).sum =
                    ((List.map d (a :: l)).take (k - 1 + 1)).sum := by rw [hk1]
                _ = (d a :: (List.map d l).take (k - 1)).sum := by
                      rw [List.map_cons, List.take_succ_cons]
                _ = d a + ((List.map d l).take (k - 1)).sum := by simp
            rw [hsumc, hsumk, hlast]
            have hgetmem : l[k - 1] ∈ l := by
              exact List.get_mem l ⟨k - 1, hkm1lt⟩
            have hadle : d a ≤ d (l[k - 1]) := hpw_head _ hgetmem
            linarith
        exact hle_take.trans hih

omit [InnerProductSpace ℝ E] in
/-- The Real neighbor-score model equals the abstract Krum score: the
Float-free half of the implementation ↔ theory correspondence. -/
theorem neighborScoreReal_eq_krumScore (g : α → E) (i : α) (k : ℕ)
    (hk : k ≤ (Finset.univ.erase i).card) :
    neighborScoreReal g i k = krumScore g i k := by
  classical
  let s : Finset α := Finset.univ.erase i
  let d : α → ℝ := fun j => distSq g i j
  let l : List α := neighborScoreRealSort d s.toList
  change ((List.map d l).take k).sum = krumScore g i k
  have hpw : l.Pairwise (fun a b => d a ≤ d b) := by
    dsimp [l]
    exact neighborScoreRealSort_pairwise d s.toList
  have hnodup : l.Nodup := by
    dsimp [l]
    exact neighborScoreRealSort_nodup d s.toList s.nodup_toList
  have hlfin : l.toFinset = s := by
    ext z
    simp only [List.mem_toFinset]
    exact (neighborScoreRealSort_mem d s.toList z).trans (by simp)
  apply le_antisymm
  · unfold krumScore
    rw [dif_pos hk]
    refine Finset.le_min' _ _ _ ?_
    intro x hx
    rw [Finset.mem_image] at hx
    rcases hx with ⟨S, hS, rfl⟩
    rw [Finset.mem_powersetCard] at hS
    exact neighborScoreReal_sum_take_le_sum_subset d l hpw hnodup S
      (by intro y hy; rw [hlfin]; exact hS.1 hy) k hS.2
  · let T : Finset α := (l.take k).toFinset
    have hTnodup : (l.take k).Nodup := List.Pairwise.take hnodup
    have hllen : l.length = s.card := by
      rw [← List.toFinset_card_of_nodup hnodup, hlfin]
    have hkl : k ≤ l.length := by
      rw [hllen]
      simpa [s] using hk
    have hTcard : T.card = k := by
      dsimp [T]
      rw [List.toFinset_card_of_nodup hTnodup, List.length_take]
      exact Nat.min_eq_left hkl
    have hTsub : T ⊆ Finset.univ.erase i := by
      intro x hx
      have hx' : x ∈ l := List.take_subset k l (by
        dsimp [T] at hx
        exact List.mem_toFinset.mp hx)
      have hxfin : x ∈ l.toFinset := List.mem_toFinset.mpr hx'
      rw [hlfin] at hxfin
      exact hxfin
    have hTsum : (∑ j ∈ T, d j) = ((List.map d l).take k).sum := by
      dsimp [T]
      rw [List.sum_toFinset d hTnodup, List.map_take]
    exact krumScore_le_of_exists_subset g i k hk hTsub hTcard
      (show (∑ j ∈ T, distSq g i j) ≤ ((List.map d l).take k).sum by
        dsimp [d] at hTsum
        exact le_of_eq hTsum)

#print axioms LeanFormalization.neighborScoreReal_eq_krumScore

end LeanFormalization
