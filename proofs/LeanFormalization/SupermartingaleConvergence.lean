import Mathlib
import LeanFormalization.Filtration
import LeanFormalization.RobbinsSiegmund
import LeanFormalization.RobbinsSiegmundDeterministic

namespace LeanFormalization

/-!
# Supermartingale Convergence Capstone (Gap 3)

Measure-theoretic L1 instantiation of Robbins-Siegmund: a nonnegative adapted
process `V` satisfying `E[V_{t+1} | F_t] <= (1-a_t) V_t + b_t` (a.e.) with
summable `b` and divergent `sum a` has `E[V_t] -> 0`. The deterministic
core is `robbins_siegmund_deterministic`; the a.s. strengthening
`supermartingale_convergence_ae` is proved via the supermartingale transform
`M_t = V_t + S_t - C_t` and `Submartingale.exists_ae_tendsto_of_bdd`.
-/

section SupermartingaleConvergence

open MeasureTheory Filter Topology

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : Measure Ω}
variable {ℱ : Filtration ℕ m}

theorem supermartingale_convergence_L1
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (a b : ℕ → ℝ)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hstep : ∀ t, ∀ᵐ ω ∂μ, μ[V (t + 1) | ℱ t] ω ≤ (1 - a t) * V t ω + b t)
    (ha : ∀ t, 0 ≤ a t ∧ a t ≤ 1)
    (hb_nonneg : ∀ t, 0 ≤ b t)
    (hsummable_b : Summable b)
    (hdivergent_a : ¬ Summable a) :
    Tendsto (fun t => ∫ ω, V t ω ∂μ) atTop (𝓝 0) := by
  let e : ℕ → ℝ := fun t => ∫ ω, V t ω ∂μ
  have he_nonneg : ∀ t, 0 ≤ e t := by
    intro t
    exact integral_nonneg (fun ω => hV_nonneg t ω)
  have hstep_e : ∀ t, e (t + 1) ≤ (1 - a t) * e t + b t := by
    intro t
    have hcond : ∫ ω, μ[V (t + 1) | ℱ t] ω ∂μ ≤
        ∫ ω, ((1 - a t) * V t ω + b t) ∂μ := by
      apply integral_mono_ae integrable_condExp (by
        have : Integrable (fun ω => (1 - a t) * V t ω + b t) μ := by
          apply Integrable.add
          · exact Integrable.smul (1 - a t) (hV_int t)
          · exact integrable_const (b t)
        exact this)
      exact hstep t
    have hl : ∫ ω, μ[V (t + 1) | ℱ t] ω ∂μ = e (t + 1) := by
      simpa [e] using integral_condExp (ℱ.le t)
    have hr : ∫ ω, ((1 - a t) * V t ω + b t) ∂μ =
        (1 - a t) * e t + b t := by
      have h1 : ∫ ω, (1 - a t) * V t ω ∂μ = (1 - a t) * e t := by
        simp [integral_const_mul, e]
      have h2 : ∫ ω, b t ∂μ = b t := by
        rw [integral_const]
        rw [measureReal_univ_eq_one (μ := μ)]
        simp [smul_eq_mul]
      rw [integral_add (Integrable.const_mul (hV_int t) (1 - a t)) (integrable_const (b t))]
      rw [h1, h2]
    linarith [hcond, hl, hr]
  exact robbins_siegmund_deterministic e a b he_nonneg hstep_e ha hb_nonneg hsummable_b hdivergent_a


/-- Almost-sure strengthening of `supermartingale_convergence_L1`.

Proof sketch: set `S_t = sum_{k<t} a_k V_k`, `C_t = sum_{k<t} b_k` and
`M_t = V_t + S_t - C_t`. Then `M` is a nonnegative supermartingale with
`E[M_t] <= E[V_0] + 2 * sum_k b_k`, so `Submartingale.exists_ae_tendsto_of_bdd`
applied to `-M` gives a.e. convergence of `M`, and monotonicity of `S` gives
a.e. convergence of `S` as well. If the a.e. limit of `V` were strictly
positive, the divergence of `sum a` would force `S` to diverge a.e., a
contradiction. Hence `V_t -> 0` a.e. -/
theorem supermartingale_convergence_ae
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (a b : ℕ → ℝ)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hstep : ∀ t, ∀ᵐ ω ∂μ, μ[V (t + 1) | ℱ t] ω ≤ (1 - a t) * V t ω + b t)
    (ha : ∀ t, 0 ≤ a t ∧ a t ≤ 1)
    (hb_nonneg : ∀ t, 0 ≤ b t)
    (hsummable_b : Summable b)
    (hdivergent_a : ¬ Summable a) :
    ∀ᵐ ω ∂μ, Tendsto (fun t => V t ω) atTop (𝓝 0) := by
  classical
  let S : ℕ → Ω → ℝ := fun n ω => ∑ k ∈ Finset.range n, a k * V k ω
  let C : ℕ → ℝ := fun n => ∑ k ∈ Finset.range n, b k
  let M : ℕ → Ω → ℝ := fun n ω => V n ω + S n ω - C n
  let D : ℕ → Ω → ℝ := fun n ω => V (n + 1) ω - V n ω + a n * V n ω - b n

  -- (A) adaptedness and integrability
  have hS_sm : ∀ n, StronglyMeasurable[ℱ n] (S n) := by
    intro n
    have hfs : StronglyMeasurable[ℱ n] (∑ k ∈ Finset.range n, fun ω => a k * V k ω) := by
      refine Finset.stronglyMeasurable_sum (s := Finset.range n)
        (f := fun k (ω : Ω) => a k * V k ω) ?_
      intro k hk
      have hk' : k < n := Finset.mem_range.mp hk
      exact ((hV_sa k).mono (ℱ.mono (Nat.le_of_lt hk'))).const_smul (a k)
    have hfun : (∑ k ∈ Finset.range n, fun ω => a k * V k ω)
        = fun ω => ∑ k ∈ Finset.range n, a k * V k ω := by
      funext ω; simp only [Finset.sum_apply]
    rwa [hfun] at hfs

  have hC_sm : ∀ n, StronglyMeasurable[ℱ n] (fun _ => C n) := fun _ => stronglyMeasurable_const

  have hM_sa : StronglyAdapted ℱ M := by
    intro n
    exact ((hV_sa n).add (hS_sm n)).sub (hC_sm n)

  have hS_int : ∀ n, Integrable (S n) μ := by
    intro n
    exact integrable_finset_sum _ (fun k _ => (hV_int k).const_mul (a k))

  have hM_int : ∀ n, Integrable (M n) μ := by
    intro n
    exact ((hV_int n).add (hS_int n)).sub (integrable_const (C n))

  have hD_int : ∀ n, Integrable (D n) μ := by
    intro n
    have h : D n = V (n + 1) - V n + (a n) • V n - fun _ => b n := rfl
    rw [h]
    exact (((hV_int (n + 1)).sub (hV_int n)).add ((hV_int n).const_mul (a n))).sub
      (integrable_const (b n))

  -- (B) M (n+1) = M n + D n
  have hM_succ : ∀ n, M (n + 1) = M n + D n := by
    intro n
    funext ω
    simp only [M, S, C, D, Pi.add_apply, Finset.sum_range_succ]
    ring_nf

  -- (C) E[D n | F n] = E[V (n+1) | F n] - V n + a n • V n - b n
  have hE_D : ∀ n, μ[D n | ℱ n] =ᵐ[μ]
      μ[V (n + 1) | ℱ n] - V n + (a n) • V n - fun _ => b n := by
    intro n
    have hVn_int : Integrable (V n) μ := hV_int n
    have hVn_sm : StronglyMeasurable[ℱ n] (V n) := hV_sa n
    have hVn_eq : μ[V n | ℱ n] = V n :=
      condExp_of_stronglyMeasurable (ℱ.le n) hVn_sm hVn_int
    have hA : μ[V (n + 1) - V n | ℱ n] =ᵐ[μ] μ[V (n + 1) | ℱ n] - V n := by
      have h := condExp_sub (hV_int (n + 1)) hVn_int (ℱ n)
      rwa [hVn_eq] at h
    have hB : μ[(a n) • V n | ℱ n] =ᵐ[μ] (a n) • V n := by
      have h := condExp_smul (𝕜 := ℝ) (μ := μ) (a n) (V n) (ℱ n)
      rwa [hVn_eq] at h
    have hC : μ[(V (n + 1) - V n) + (a n) • V n | ℱ n]
        =ᵐ[μ] (μ[V (n + 1) | ℱ n] - V n) + (a n) • V n := by
      have h := condExp_add ((hV_int (n + 1)).sub hVn_int) ((hVn_int).const_mul (a n)) (ℱ n)
      exact h.trans (hA.add hB)
    have hconst : μ[fun _ => b n | ℱ n] = fun _ => b n := condExp_const (ℱ.le n) (b n)
    have hD_eq : D n = ((V (n + 1) - V n) + (a n) • V n) - fun _ => b n := rfl
    have hA_int : Integrable ((V (n + 1) - V n) + (a n) • V n) μ :=
      ((hV_int (n + 1)).sub hVn_int).add ((hVn_int).const_mul (a n))
    have h1 : μ[D n | ℱ n] =ᵐ[μ] μ[(V (n + 1) - V n) + (a n) • V n | ℱ n]
        - μ[fun _ => b n | ℱ n] := by
      rw [hD_eq]
      exact condExp_sub hA_int (integrable_const (b n)) (ℱ n)
    have h3 : μ[fun _ => b n | ℱ n] =ᵐ[μ] fun _ => b n := Filter.EventuallyEq.of_eq hconst
    exact h1.trans (hC.sub h3)

  -- (D) one-step supermartingale inequality
  have hM_step : ∀ n, μ[M (n + 1) | ℱ n] ≤ᵐ[μ] M n := by
    intro n
    have hD_le : μ[D n | ℱ n] ≤ᵐ[μ] 0 := by
      have h1 : (μ[V (n + 1) | ℱ n] - V n + (a n) • V n - (fun _ : Ω => b n)) ≤ᵐ[μ] 0 := by
        have hle : μ[V (n + 1) | ℱ n] ≤ᵐ[μ] fun ω => (1 - a n) * V n ω + b n := hstep n
        have hz : ∀ ω, ((1 - a n) * V n ω + b n) - V n ω + a n * V n ω - b n = 0 := by
          intro ω; ring
        filter_upwards [hle] with ω hω
        simp only [Pi.sub_apply, Pi.add_apply, Pi.smul_apply, smul_eq_mul, Pi.zero_apply] at *
        linarith
      exact (hE_D n).le.trans h1
    have hM_n_eq : μ[M n | ℱ n] = M n :=
      condExp_of_stronglyMeasurable (ℱ.le n) (hM_sa n) (hM_int n)
    have hsplit : μ[M (n + 1) | ℱ n] =ᵐ[μ] M n + μ[D n | ℱ n] := by
      have h := condExp_add (hM_int n) (hD_int n) (ℱ n)
      rw [← hM_succ n] at h
      rwa [hM_n_eq] at h
    filter_upwards [hsplit, hD_le] with ω h1 h2
    rw [h1]
    have h2' : μ[D n | ℱ n] ω ≤ 0 := by simpa using h2
    simp only [Pi.add_apply]
    linarith

  have hM_sm : Supermartingale M ℱ μ := supermartingale_nat hM_sa hM_int hM_step

  -- (E) L1 bound: M n >= -B and E[M n] <= E[V 0], so E[|M n|] <= E[V 0] + 2B
  have hB_nonneg : 0 ≤ ∑' k, b k := tsum_nonneg hb_nonneg
  have hC_le : ∀ n, C n ≤ ∑' k, b k := by
    intro n
    exact hsummable_b.sum_le_tsum _ (fun k _ => hb_nonneg k)
  have hM_lower : ∀ n ω, -∑' k, b k ≤ M n ω := by
    intro n ω
    have hS_nonneg : 0 ≤ S n ω := by
      apply Finset.sum_nonneg
      intro k _
      exact mul_nonneg (ha k).1 (hV_nonneg k ω)
    have hC_le_n := hC_le n
    simp only [M]
    linarith [hV_nonneg n ω, hS_nonneg, hC_le_n]
  have hM0 : M 0 = V 0 := by
    funext ω; simp [M, S, C]
  have hM_eLp : ∀ n, eLpNorm (M n) 1 μ
      ≤ ENNReal.ofReal (∫ ω, V 0 ω ∂μ + 2 * ∑' k, b k) := by
    intro n
    have habs : ∀ ω, ‖M n ω‖ₑ ≤ ENNReal.ofReal (M n ω + 2 * ∑' k, b k) := by
      intro ω
      rw [Real.enorm_eq_ofReal_abs]
      apply ENNReal.ofReal_le_ofReal
      rw [abs_le]
      constructor <;> linarith [hM_lower n ω, hB_nonneg]
    have h1 : ∫⁻ ω, ‖M n ω‖ₑ ∂μ
        ≤ ∫⁻ ω, ENNReal.ofReal (M n ω + 2 * ∑' k, b k) ∂μ :=
      lintegral_mono_ae (ae_of_all _ habs)
    have hf_int : Integrable (fun ω => M n ω + 2 * ∑' k, b k) μ :=
      (hM_int n).add (integrable_const _)
    have hf_nn : 0 ≤ᵐ[μ] (fun ω => M n ω + 2 * ∑' k, b k) := by
      filter_upwards with ω
      have h1 := hM_lower n ω
      have h2 := hB_nonneg
      simp only [Pi.zero_apply]
      linarith
    have h2 : ∫⁻ ω, ENNReal.ofReal (M n ω + 2 * ∑' k, b k) ∂μ
        = ENNReal.ofReal (∫ ω, M n ω + 2 * ∑' k, b k ∂μ) :=
      (ofReal_integral_eq_lintegral_ofReal hf_int hf_nn).symm
    have h3 : ∫ ω, M n ω + 2 * ∑' k, b k ∂μ ≤ ∫ ω, V 0 ω ∂μ + 2 * ∑' k, b k := by
      have h3a : ∫ ω, M n ω + 2 * ∑' k, b k ∂μ = ∫ ω, M n ω ∂μ + 2 * ∑' k, b k := by
        rw [integral_add (hM_int n) (integrable_const _)]
        rw [integral_const]
        rw [probReal_univ]
        simp
      have h3b : ∫ ω, M n ω ∂μ ≤ ∫ ω, V 0 ω ∂μ := by
        have h := hM_sm.setIntegral_le (f := M) (i := 0) (j := n) (Nat.zero_le n)
          MeasurableSet.univ
        simp only [setIntegral_univ] at h
        rw [hM0] at h
        exact h
      linarith
    calc eLpNorm (M n) 1 μ = ∫⁻ ω, ‖M n ω‖ₑ ∂μ := eLpNorm_one_eq_lintegral_enorm
      _ ≤ ∫⁻ ω, ENNReal.ofReal (M n ω + 2 * ∑' k, b k) ∂μ := h1
      _ = ENNReal.ofReal (∫ ω, M n ω + 2 * ∑' k, b k ∂μ) := h2
      _ ≤ ENNReal.ofReal (∫ ω, V 0 ω ∂μ + 2 * ∑' k, b k) := ENNReal.ofReal_le_ofReal h3

  -- (F) M converges a.s.
  have hM_conv : ∀ᵐ ω ∂μ, ∃ c, Tendsto (fun n => M n ω) atTop (𝓝 c) := by
    have hsub : Submartingale (-M) ℱ μ := hM_sm.neg
    let R : NNReal := (∫ ω, V 0 ω ∂μ + 2 * ∑' k, b k).toNNReal
    have hbdd : ∀ n, eLpNorm ((-M) n) 1 μ ≤ (R : ENNReal) := by
      intro n
      have h : eLpNorm ((-M) n) 1 μ = eLpNorm (M n) 1 μ := by
        rw [show ((-M) n) = fun ω => -(M n ω) from rfl]
        exact eLpNorm_neg (M n) 1 μ
      rw [h]
      exact hM_eLp n
    have h := hsub.exists_ae_tendsto_of_bdd (f := -M) (R := R) hbdd
    filter_upwards [h] with ω hω
    rcases hω with ⟨c, hc⟩
    refine ⟨-c, ?_⟩
    simpa [Pi.neg_apply] using hc.neg

  -- (G) S n converges a.s. to a finite limit
  have hS_mono : ∀ ω, Monotone (fun n => ((S n ω).toNNReal : ENNReal)) := by
    intro ω n m hnm
    apply ENNReal.coe_le_coe.mpr
    exact Real.toNNReal_mono (by
      apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.range_subset_range.mpr hnm)
      intro k _ _
      exact mul_nonneg (ha k).1 (hV_nonneg k ω))
  have hT_meas : ∀ n, Measurable (fun ω => ((S n ω).toNNReal : ENNReal)) := by
    intro n
    exact ENNReal.continuous_ofReal.measurable.comp ((hS_sm n).mono (ℱ.le n)).measurable
  have hS_integral_le : ∀ n, ∫ ω, S n ω ∂μ ≤ ∫ ω, V 0 ω ∂μ + ∑' k, b k := by
    intro n
    have h1 : ∫ ω, S n ω ∂μ = ∫ ω, M n ω ∂μ - ∫ ω, V n ω ∂μ + C n := by
      have h : S n = M n - V n + fun _ => C n := by
        funext ω; simp only [M, S, C, Pi.sub_apply, Pi.add_apply]; ring
      calc ∫ ω, S n ω ∂μ = ∫ ω, (M n ω - V n ω) + C n ∂μ := by
              rw [h]; simp only [Pi.add_apply, Pi.sub_apply]
        _ = ∫ ω, (M n ω - V n ω) ∂μ + ∫ ω, C n ∂μ := by
              rw [integral_add (f := fun ω => M n ω - V n ω) (g := fun _ => C n)
                ((hM_int n).sub (hV_int n)) (integrable_const _)]
        _ = (∫ ω, M n ω ∂μ - ∫ ω, V n ω ∂μ) + C n := by
              rw [integral_sub (hM_int n) (hV_int n), integral_const, probReal_univ]; simp
    have h2 : ∫ ω, M n ω ∂μ ≤ ∫ ω, V 0 ω ∂μ := by
      have h := hM_sm.setIntegral_le (f := M) (i := 0) (j := n) (Nat.zero_le n) MeasurableSet.univ
      simp only [setIntegral_univ] at h
      rwa [hM0] at h
    have h3 : C n ≤ ∑' k, b k := hC_le n
    have h4 : 0 ≤ ∫ ω, V n ω ∂μ := integral_nonneg (fun ω => hV_nonneg n ω)
    linarith
  have hSInf_lint : ∫⁻ ω, ⨆ n, ((S n ω).toNNReal : ENNReal) ∂μ
      ≤ ENNReal.ofReal (∫ ω, V 0 ω ∂μ + ∑' k, b k) := by
    have h1 : ∫⁻ ω, ⨆ n, ((S n ω).toNNReal : ENNReal) ∂μ
        = ⨆ n, ∫⁻ ω, ((S n ω).toNNReal : ENNReal) ∂μ :=
      lintegral_iSup hT_meas (fun n m hnm ω => hS_mono ω hnm)
    rw [h1]
    have h2 : ∀ n, ∫⁻ ω, ((S n ω).toNNReal : ENNReal) ∂μ
        ≤ ENNReal.ofReal (∫ ω, V 0 ω ∂μ + ∑' k, b k) := by
      intro n
      have hfun : (fun ω => ((S n ω).toNNReal : ENNReal)) = (fun ω => ENNReal.ofReal (S n ω)) := by
        funext ω; exact (ENNReal.ofNNReal_toNNReal (S n ω)).symm
      rw [hfun]
      rw [← ofReal_integral_eq_lintegral_ofReal (hS_int n)
        (ae_of_all _ (fun ω => Finset.sum_nonneg (fun k _ =>
          mul_nonneg (ha k).1 (hV_nonneg k ω))))]
      exact ENNReal.ofReal_le_ofReal (hS_integral_le n)
    exact iSup_le h2
  have hSInf_lt : ∀ᵐ ω ∂μ, (⨆ n, ((S n ω).toNNReal : ENNReal)) < ⊤ := by
    apply MeasureTheory.ae_lt_top (f := fun ω => ⨆ n, ((S n ω).toNNReal : ENNReal))
    · exact Measurable.iSup hT_meas
    · have h3 : ∫⁻ ω, ⨆ n, ((S n ω).toNNReal : ENNReal) ∂μ < ⊤ :=
          lt_of_le_of_lt hSInf_lint ENNReal.ofReal_lt_top
      exact ne_of_lt h3
  have hS_conv : ∀ᵐ ω ∂μ, ∃ SInf : ℝ, Tendsto (fun n => S n ω) atTop (𝓝 SInf) := by
    filter_upwards [hSInf_lt] with ω hω
    have hmono : Monotone (fun n => S n ω) := by
      intro n m hnm
      have h1 : (0:ℝ) ≤ S n ω := by
        apply Finset.sum_nonneg; intro k _; exact mul_nonneg (ha k).1 (hV_nonneg k ω)
      have h2 : (0:ℝ) ≤ S m ω := by
        apply Finset.sum_nonneg; intro k _; exact mul_nonneg (ha k).1 (hV_nonneg k ω)
      change S n ω ≤ S m ω
      rw [← Real.coe_toNNReal (S n ω) h1, ← Real.coe_toNNReal (S m ω) h2]
      exact_mod_cast ENNReal.coe_le_coe.mp (hS_mono ω hnm)
    refine ⟨⨆ n, S n ω, tendsto_atTop_ciSup hmono ?_⟩
    refine ⟨(⨆ n, ((S n ω).toNNReal : ENNReal)).toReal, ?_⟩
    intro x hx
    rcases hx with ⟨n, rfl⟩
    have hle : ((S n ω).toNNReal : ENNReal) ≤ ⨆ m, ((S m ω).toNNReal : ENNReal) :=
      le_iSup (fun m => ((S m ω).toNNReal : ENNReal)) n
    have htop : (⨆ m, ((S m ω).toNNReal : ENNReal)) < ⊤ := hω
    have hfin : ((S n ω).toNNReal : ENNReal) < ⊤ := lt_of_le_of_lt hle htop
    have hval : ((S n ω).toNNReal : ENNReal).toReal = S n ω := by
      have hnonneg : (0:ℝ) ≤ S n ω := by
        apply Finset.sum_nonneg; intro k _; exact mul_nonneg (ha k).1 (hV_nonneg k ω)
      rw [ENNReal.ofNNReal_toNNReal]
      exact ENNReal.toReal_ofReal hnonneg
    have hle2 : S n ω ≤ (⨆ m, ((S m ω).toNNReal : ENNReal)).toReal := by
      rw [← hval]
      exact ENNReal.toReal_mono (ne_of_lt htop) hle
    exact hle2

  -- (H) conclusion
  have hC_tendsto : Tendsto (fun n => C n) atTop (𝓝 (∑' k, b k)) := by
    have h := hsummable_b.hasSum.tendsto_sum_nat
    simpa [C] using h
  have hSa : Tendsto (fun n => ∑ k ∈ Finset.range n, a k) atTop atTop :=
    (not_summable_iff_tendsto_nat_atTop_of_nonneg (fun k => (ha k).1)).mp hdivergent_a
  have hV_zero : ∀ᵐ ω ∂μ, Tendsto (fun n => V n ω) atTop (𝓝 0) := by
    filter_upwards [hM_conv, hS_conv] with ω hM hS
    rcases hM with ⟨c, hc⟩
    rcases hS with ⟨SInf, hS⟩
    let hL : ℝ := c - SInf + ∑' k, b k
    have hV_tendsto : Tendsto (fun n => V n ω) atTop (𝓝 hL) := by
      have hV_eq : (fun n => V n ω) = (fun n => M n ω - S n ω + C n) := by
        funext n; simp only [M, S, C]; ring
      rw [hV_eq]
      exact (hc.sub hS).add hC_tendsto
    have hL_nonneg : 0 ≤ hL :=
      ge_of_tendsto hV_tendsto (by filter_upwards with n; exact hV_nonneg n ω)
    have hL_zero : hL = 0 := by
      by_contra hne
      have hL_pos : 0 < hL := lt_of_le_of_ne hL_nonneg (Ne.symm hne)
      rcases Metric.tendsto_atTop.1 hV_tendsto (hL / 2) (by positivity) with ⟨K, hK⟩
      have hVK : ∀ n ≥ K, hL / 2 ≤ V n ω := by
        intro n hn
        have := hK n hn
        rw [Real.dist_eq] at this
        have := (abs_lt.1 this).1
        linarith
      have hS_div : Tendsto (fun n => S n ω) atTop atTop := by
        rw [Filter.tendsto_atTop_atTop]
        intro b
        rcases Filter.tendsto_atTop_atTop.1 hSa
          (b * 2 / hL + ∑ k ∈ Finset.range K, a k) with ⟨N, hN⟩
        refine ⟨max N K, ?_⟩
        intro n hn
        have hnN : N ≤ n := le_trans (le_max_left _ _) hn
        have hnK : K ≤ n := le_trans (le_max_right _ _) hn
        have h1 : b * 2 / hL + ∑ k ∈ Finset.range K, a k
            ≤ ∑ k ∈ Finset.range n, a k := hN n hnN
        have h2 : ∑ k ∈ Finset.range K, a k ≤ ∑ k ∈ Finset.range n, a k := by
          apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.range_subset_range.mpr hnK)
          intro k _ _; exact (ha k).1
        have h3 : ∑ k ∈ Finset.range n with K ≤ k, a k
            = ∑ k ∈ Finset.range n, a k - ∑ k ∈ Finset.range K, a k :=
            (Finset.sum_range_sub_sum_range hnK).symm
        have h4 : b * 2 / hL ≤ ∑ k ∈ Finset.range n with K ≤ k, a k := by
          rw [h3]; linarith
        have h5 : b ≤ hL / 2 * ∑ k ∈ Finset.range n with K ≤ k, a k := by
          have h4' : b * 2 ≤ hL * ∑ k ∈ Finset.range n with K ≤ k, a k := by
            calc b * 2 = (b * 2 / hL) * hL := by field_simp
              _ ≤ (∑ k ∈ Finset.range n with K ≤ k, a k) * hL :=
                  mul_le_mul_of_nonneg_right h4 (le_of_lt hL_pos)
              _ = hL * ∑ k ∈ Finset.range n with K ≤ k, a k := by ring
          nlinarith [h4']
        have h6 : hL / 2 * ∑ k ∈ Finset.range n with K ≤ k, a k ≤ S n ω := by
          have h7 : ∑ k ∈ Finset.filter (fun k => K ≤ k) (Finset.range n), a k * V k ω
              ≤ S n ω := by
            exact Finset.sum_le_sum_of_subset_of_nonneg (Finset.filter_subset _ _)
              (fun k _ _ => mul_nonneg (ha k).1 (hV_nonneg k ω))
          have h8 : hL / 2 * ∑ k ∈ Finset.filter (fun k => K ≤ k) (Finset.range n), a k
              ≤ ∑ k ∈ Finset.filter (fun k => K ≤ k) (Finset.range n), a k * V k ω := by
            rw [Finset.mul_sum]
            apply Finset.sum_le_sum
            intro k hk
            have hkK : K ≤ k := (Finset.mem_filter.mp hk).2
            rw [mul_comm (hL / 2) (a k)]
            exact mul_le_mul_of_nonneg_left (hVK k hkK) (ha k).1
          linarith [h7, h8]
        exact h5.trans h6
      have hS_bdd : ∀ᶠ n in atTop, S n ω ≤ SInf + 1 := by
        rw [Filter.eventually_atTop]
        rcases Metric.tendsto_atTop.1 hS 1 (by norm_num) with ⟨N, hN⟩
        exact ⟨N, fun n hn => by
          have := hN n hn
          rw [Real.dist_eq] at this
          have := (abs_lt.1 this).2
          linarith⟩
      have hS_lb : ∀ᶠ n in atTop, SInf + 2 ≤ S n ω := by
        rw [Filter.eventually_atTop]
        rw [Filter.tendsto_atTop_atTop] at hS_div
        rcases hS_div (SInf + 2) with ⟨N, hN⟩
        exact ⟨N, fun n hn => hN n hn⟩
      have hfalse : ∀ᶠ n : ℕ in atTop, False := by
        filter_upwards [hS_bdd, hS_lb] with n h1 h2
        linarith
      have hbot : (atTop : Filter ℕ) = ⊥ := Filter.eventually_false_iff_eq_bot.mp hfalse
      exact atTop_neBot.ne' hbot
    rw [hL_zero] at hV_tendsto
    exact hV_tendsto
  exact hV_zero


end SupermartingaleConvergence

end LeanFormalization
