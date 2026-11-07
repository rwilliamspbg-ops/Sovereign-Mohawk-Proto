import Mathlib

namespace LeanFormalization

open Filter Topology

/-- If `a, V` are nonnegative, `∑ a` diverges, and `∑ a*V` converges,
    then any limit of `V` is 0. -/
theorem robbins_siegmund_limit_zero
    (a V : ℕ → ℝ)
    (ha : ∀ k, 0 ≤ a k) (hV : ∀ k, 0 ≤ V k)
    (hdiv : ¬ Summable a)
    (hsum : Summable (fun k => a k * V k))
    (L : ℝ) (hL : Tendsto V atTop (𝓝 L)) :
    L = 0 := by
  have hLnn : 0 ≤ L := by
    apply le_of_tendsto tendsto_const_nhds hL
    filter_upwards with k
    exact hV k
  by_contra hne
  have hLpos : 0 < L := lt_of_le_of_ne hLnn (Ne.symm hne)
  have hev : ∀ᶠ k in atTop, V k ≥ L / 2 := by
    have := Metric.tendsto_atTop.1 hL (L / 2) (by positivity)
    filter_upwards [this] with k hk
    have := (abs_lt.1 hk).1
    linarith
  rcases Filter.eventually_atTop.1 hev with ⟨N, hN⟩
  let g := fun k => if k < N then (0 : ℝ) else (L / 2) * a k
  have hg_nonneg : ∀ k, 0 ≤ g k := by
    intro k
    by_cases hkn : k < N
    · simp [g, hkn]
    · simp [g, hkn]
      nlinarith [ha k, hLpos]
  have hg_le : ∀ k, g k ≤ a k * V k := by
    intro k
    by_cases hkn : k < N
    · simp [g, hkn]
      nlinarith [ha k, hV k]
    · simp [g, hkn]
      have hv : V k ≥ L / 2 := hN k (Nat.le_of_not_lt hkn)
      have ha0 : 0 ≤ a k := ha k
      nlinarith [hv, ha0]
  have hg_summable : Summable g := Summable.of_nonneg_of_le hg_nonneg hg_le hsum
  have hprefix : Summable (fun k => if k < N then a k else 0) := by
    apply summable_of_hasFiniteSupport
    refine (Set.finite_Iio N).subset ?_
    intro k hk
    simp [Function.support] at hk ⊢
    by_contra hkn
    have hkn' : ¬ (k < N) := hkn
    simp [hkn'] at hk
  have htail : Summable (fun k => if k ≥ N then a k else 0) := by
    have hne : L / 2 ≠ 0 := by positivity
    have hsmul : Summable (fun k => (2 / L) * g k) := hg_summable.smul (2 / L)
    have heq : (fun k => (2 / L) * g k) = (fun k => if k < N then 0 else a k) := by
      funext k
      by_cases hkn : k < N
      · simp [g, hkn]
      · simp [g, hkn]
        field_simp [hne]
    rw [heq] at hsmul
    have heq2 : (fun k => if k < N then 0 else a k) = (fun k => if k ≥ N then a k else 0) := by
      funext k
      by_cases hkn : k < N
      · have : ¬ (k ≥ N) := by omega
        simp [hkn, this]
      · have : k ≥ N := Nat.le_of_not_lt hkn
        simp [hkn, this]
    rw [heq2] at hsmul
    exact hsmul
  have ha_summable : Summable a := by
    have hdecomp : ∀ k, a k = (if k < N then a k else 0) + (if k ≥ N then a k else 0) := by
      intro k
      by_cases hkn : k < N
      · simp [hkn]
      · have hkn' : k ≥ N := Nat.le_of_not_lt hkn
        simp [hkn, hkn']
    have hadd : Summable (fun k => (if k < N then a k else 0) + (if k ≥ N then a k else 0)) :=
      Summable.add hprefix htail
    exact (Summable.congr hadd hdecomp.symm)
  exact hdiv ha_summable

/-- Deterministic Robbins-Siegmund convergence (rational surrogate capstone). -/
theorem robbins_siegmund_deterministic
    (V a b : ℕ → ℝ)
    (hV_nonneg : ∀ t, 0 ≤ V t)
    (hstep : ∀ t, V (t + 1) ≤ (1 - a t) * V t + b t)
    (ha : ∀ t, 0 ≤ a t ∧ a t ≤ 1)
    (hb_nonneg : ∀ t, 0 ≤ b t)
    (hsummable_b : Summable b)
    (hdivergent_a : ¬ Summable a) :
    Tendsto V atTop (𝓝 0) := by
  let Bt : ℕ → ℝ := fun t => (Finset.range t).sum b
  let At : ℕ → ℝ := fun t => (Finset.range t).sum (fun k => a k * V k)
  let Mt : ℕ → ℝ := fun t => V t + At t - Bt t
  have hB : Tendsto Bt atTop (𝓝 (∑' k, b k)) := hsummable_b.hasSum.tendsto_sum_nat
  have hBmono : Monotone Bt := by
    intro i j hij
    exact Finset.sum_le_sum_of_subset (Finset.range_subset.mpr hij)
      (fun k _ => hb_nonneg k)
  have hM_antitone : Antitone Mt := by
    intro t
    show Mt (t + 1) ≤ Mt t
    simp [Mt, At, Bt, Finset.sum_range_succ]
    have hstep_t := hstep t
    linarith [hstep_t]
  have hM_bddBelow : BddBelow (Set.range Mt) := by
    refine ⟨-(∑' k, b k), ?_⟩
    intro x hx
    rcases hx with ⟨t, rfl⟩
    have hVt : 0 ≤ V t := hV_nonneg t
    have hAt : 0 ≤ At t := by
      apply Finset.sum_nonneg
      intro k _
      nlinarith [(ha k).1, hV_nonneg k]
    have hBt : Bt t ≤ ∑' k, b k := Monotone.ge_of_tendsto hBmono hB t
    linarith [hVt, hAt, hBt]
  have hM : Tendsto Mt atTop (𝓝 (⨅ t, Mt t)) :=
    tendsto_atTop_ciInf hM_antitone hM_bddBelow
  have hVA : Tendsto (fun t => V t + At t) atTop (𝓝 (⨅ t, Mt t + ∑' k, b k)) := by
    have hsum : (fun t => V t + At t) = (fun t => Mt t + Bt t) := by
      funext t; simp [Mt]
    rw [hsum]
    exact Tendsto.add hM hB
  have hAt_bddAbove : BddAbove (Set.range At) := by
    let L := ⨅ t, Mt t + ∑' k, b k
    have hev := Metric.tendsto_atTop.1 hVA 1 (by norm_num : (0 : ℝ) < 1)
    rcases hev with ⟨N, hN⟩
    let C1 := (Finset.range (N + 1)).sup' (by simp) At
    refine ⟨max C1 (L + 1), ?_⟩
    intro x hx
    rcases hx with ⟨t, rfl⟩
    by_cases htt : t ≤ N
    · have ht : t ∈ Finset.range (N + 1) := Finset.mem_range.mpr (by omega)
      have hle : At t ≤ C1 := Finset.le_sup' At ht
      exact le_trans hle (le_max_left _ _)
    · have habs : |(V t + At t) - L| < 1 := hN t (by omega)
      have hleVA : V t + At t ≤ L + 1 := by
        have := (abs_lt.1 habs).1
        linarith
      have hVt : 0 ≤ V t := hV_nonneg t
      have hAtle : At t ≤ V t + At t := by linarith [hVt]
      exact le_trans hAtle (le_trans hleVA (le_max_right _ _))
  have hAt_monotone : Monotone At := by
    intro i j hij
    exact Finset.sum_le_sum_of_subset (Finset.range_subset.mpr hij)
      (fun k _ => by nlinarith [(ha k).1, hV_nonneg k])
  have hAt : Tendsto At atTop (𝓝 (⨆ t, At t)) :=
    tendsto_atTop_ciSup hAt_monotone hAt_bddAbove
  have hV_conv : Tendsto V atTop (𝓝 ((⨅ t, Mt t + ∑' k, b k) - (⨆ t, At t))) := by
    have hsum : (fun t => V t) = (fun t => (V t + At t) - At t) := by
      funext t; ring
    rw [hsum]
    exact Tendsto.sub hVA hAt
  have hsum_aV : Summable (fun k => a k * V k) := by
    refine ⟨⨆ t, At t, ?_⟩
    have : Tendsto (fun t => (Finset.range t).sum (fun k => a k * V k)) atTop (𝓝 (⨆ t, At t)) := by
      simpa [At] using hAt
    exact this
  exact robbins_siegmund_limit_zero a V (fun k => (ha k).1) hV_nonneg hdivergent_a hsum_aV
    ((⨅ t, Mt t + ∑' k, b k) - (⨆ t, At t)) hV_conv

end LeanFormalization
