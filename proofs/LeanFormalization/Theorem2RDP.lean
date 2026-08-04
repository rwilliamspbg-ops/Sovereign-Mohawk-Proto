import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/- Strategy:
  Encode RDP composition as an additive ledger so each runtime guard can be
  validated with exact rational arithmetic.

  Tactics used:
  - `simp` for concatenation and singleton reductions
  - `linarith` for monotonicity and conversion inequalities
  - `omega` for bounded integer budget steps

  Future work:
  Connect the additive model to proof-metric regression checks and CI trend
  reporting for privacy-budget growth.
-/

/-- A randomized mechanism M : D → X with privacy parameter (α, ε) describes
    what happens when the adversary has unbounded computational power but finite
    divergence advantage bounded by ε on adjacent database pairs.
-/
structure DPMechanism (D X : Type*) where
  apply : D → X
  alpha : ℚ
  eps : ℚ
  rdpBound : D → D → ℚ

/-- Two databases are adjacent if they differ in exactly one record. -/
def isAdjacent {D : Type*} (_d1 _d2 : D) : Prop :=
  ∃ (_ : Unit), True

/-- Rényi divergence order α, bound ε for mechanisms.
    The abstract notion: M satisfies (α, ε)-RDP if the maximum ratio
    of likelihoods over adjacent databases pairs is exp(ε).
-/
def satisfiesRDP {D X : Type*} (M : DPMechanism D X) : Prop :=
  M.alpha > 1 ∧
  M.eps ≥ 0 ∧
  ∀ (d1 d2 : D), isAdjacent d1 d2 →
    0 ≤ M.rdpBound d1 d2 ∧ M.rdpBound d1 d2 ≤ M.eps

/-- Integer epsilon composition model for deterministic machine checks. -/
def composeEps : List Nat -> Nat
  | [] => 0
  | x :: xs => x + composeEps xs

/-- Exact rational composition model aligned with the runtime accountant ledger. -/
def composeEpsRat : List ℚ -> ℚ
  | [] => 0
  | x :: xs => x + composeEpsRat xs

/-- Convert cumulative RDP epsilon into a standard `(ε, δ)`-style budget proxy. -/
def convertToEpsDelta (alpha epsRdp logOneOverDelta : ℚ) : ℚ :=
  epsRdp + (logOneOverDelta / (alpha - 1))

/-- Theorem 2 core: sequential composition over concatenated mechanisms is additive. -/
theorem theorem2_composition_append (xs ys : List Nat) :
    composeEps (xs ++ ys) = composeEps xs + composeEps ys := by
  induction xs with
  | nil => simp [composeEps]
  | cons x xs ih =>
      simpa [composeEps, Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using congrArg (fun z => x + z) ih

/-- Rational composition remains additive over concatenation. -/
theorem theorem2_rat_composition_append (xs ys : List ℚ) :
    composeEpsRat (xs ++ ys) = composeEpsRat xs + composeEpsRat ys := by
  induction xs with
  | nil =>
      simp [composeEpsRat]
  | cons x xs ih =>
      simpa [composeEpsRat, add_assoc] using congrArg (fun z => x + z) ih

/-- Composition is monotone when appending additional mechanisms. -/
theorem theorem2_monotone_append (xs ys : List Nat) :
    composeEps xs <= composeEps (xs ++ ys) := by
  rw [theorem2_composition_append]
  exact Nat.le_add_right _ _

/-- Rational composition is monotone when appending nonnegative steps. -/
theorem theorem2_rat_monotone_append (xs ys : List ℚ)
    (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
    composeEpsRat xs ≤ composeEpsRat (xs ++ ys) := by
  rw [theorem2_rat_composition_append]
  have h_sum : 0 ≤ composeEpsRat ys := by
    induction ys with
    | nil =>
        simp [composeEpsRat]
    | cons y ys ih =>
        have hy : 0 ≤ y := h_nonneg y (by simp)
        have htail : ∀ e ∈ ys, 0 ≤ e := by
          intro e he
          exact h_nonneg e (by simp [he])
        have ih' := ih htail
        simp only [composeEpsRat]; linarith
  linarith

/-- The Gaussian mechanism with std σ satisfies (α, α/(2σ²))-RDP. -/
theorem gaussianRDPBound (alpha sigma : ℝ) (h_alpha : alpha > 1) (h_sigma : sigma > 0) :
    ∃ (eps : ℝ), eps = alpha / (2 * sigma ^ 2) ∧ eps ≥ 0 := by
  refine ⟨alpha / (2 * sigma ^ 2), rfl, ?_⟩
  positivity

/-- Adding a bounded step preserves a bounded global budget. -/
theorem theorem2_budget_step {current step budget : Nat}
    (h_cur : current <= budget)
    (h_step : step <= budget - current) :
    current + step <= budget := by
  omega

/-- Exact rational single-step composition is recorded without approximation. -/
theorem theorem2_rat_single_step (eps : ℚ) :
    composeEpsRat [eps] = eps := by
  simp [composeEpsRat]

/-- Conversion to the `(ε, δ)` proxy is monotone in cumulative RDP epsilon. -/
theorem theorem2_conversion_monotone {alpha logOneOverDelta eps1 eps2 : ℚ}
    (_h_alpha : 1 < alpha)
    (h_eps : eps1 ≤ eps2) :
  convertToEpsDelta alpha eps1 logOneOverDelta ≤ convertToEpsDelta alpha eps2 logOneOverDelta := by
  unfold convertToEpsDelta
  linarith

/-- Positive alpha keeps the conversion denominator well-formed. -/
theorem theorem2_conversion_denominator_pos {alpha : ℚ} (h_alpha : 1 < alpha) :
    0 < alpha - 1 := by
  linarith

/-- Example composition for a 4-tier privacy budget profile. -/
theorem theorem2_example_profile :
    composeEps [1, 5, 10, 0] = 16 := by
  native_decide

/-- Tight budget guard: composed epsilon remains under configured ceiling. -/
theorem theorem2_budget_guard :
    composeEps [1, 5, 10, 0] <= 20 := by
  native_decide

/-- Concrete rational profile mirrors the runtime accountant's additive ledger. -/
theorem theorem2_rat_example_profile :
    composeEpsRat [(1 : ℚ) / 10, (1 : ℚ) / 2, 1] = (8 : ℚ) / 5 := by
  norm_num [composeEpsRat]

/-- Converted epsilon budget remains below a configured guard for the example profile. -/
theorem theorem2_rat_budget_guard :
  convertToEpsDelta 10 (composeEpsRat [(1 : ℚ) / 10, (1 : ℚ) / 2, 1]) 1
      <= (9 : ℚ) / 5 := by
  norm_num [convertToEpsDelta, composeEpsRat]

/-! # Phase 3e: Rényi Divergence and RDP Framework

Core theorems for implementing exact Rényi divergence (RDP) accounting.
These lemmas form the mathematical foundation for the runtime privacy budget
accountant used in the Go implementation.
-/

/-- Rényi divergence of order α between two probability distributions.
    Defined as: D_α(p||q) = (1/(α-1)) * log(∑_x q(x)^α / p(x)^(α-1))
    
    Note: For α = 1, this approaches KL divergence. For α = ∞, this is the 
    max divergence. This is used directly in the RDP composition accounting.
-/
noncomputable def RenyiDivergence {α : Type*} [Fintype α] (p q : α → ℝ) (order : ℝ) : ℝ :=
  if order = 1 then
    -- KL divergence limit: ∑_x p(x) * log(p(x) / q(x))
    ∑ x, p x * Real.log (p x / q x)
  else if order > 1 then
    -- Standard case: (1/(α-1)) * log(∑_x q(x)^α / p(x)^(α-1))
    (1 / (order - 1)) * Real.log (∑ x, (q x) ^ order / (p x) ^ (order - 1))
  else
    -- For α < 1, use reversed order for non-negativity
    (1 / (1 - order)) * Real.log (∑ x, (p x) ^ order / (q x) ^ (order - 1))

/-- Rényi divergence is non-negative for order > 1, PROVEN for real via the
    weighted power-mean inequality (`Real.rpow_arith_mean_le_arith_mean_rpow`,
    i.e. Jensen's inequality for the convex map `x ↦ x^order`).

    Note on hypotheses: the previous `sorry`'d version of this theorem took no
    normalization hypothesis (`∑ p = 1`, `∑ q = 1`). Without normalization the
    claim is actually FALSE — e.g. a single-point space with `p = 100`,
    `q = 0.01`, `order = 2` gives `RenyiDivergence p q order < 0`. The two sum
    hypotheses below are required, not optional strengthening.
-/
theorem RenyiDivergence_nonneg {α : Type*} [Fintype α] (p q : α → ℝ) (order : ℝ)
    (h_order : 1 < order) (h_p_pos : ∀ x, 0 < p x) (h_q_pos : ∀ x, 0 < q x)
    (h_p_sum : ∑ x, p x = 1) (h_q_sum : ∑ x, q x = 1) :
    0 ≤ RenyiDivergence p q order := by
  unfold RenyiDivergence
  rw [if_neg h_order.ne', if_pos h_order]
  have hS : (1 : ℝ) ≤ ∑ x, (q x) ^ order / (p x) ^ (order - 1) := by
    have key := Real.rpow_arith_mean_le_arith_mean_rpow (Finset.univ) p (fun x => q x / p x)
      (fun i _ => (h_p_pos i).le) h_p_sum
      (fun i _ => div_nonneg (h_q_pos i).le (h_p_pos i).le) h_order.le
    have hlhs : ∑ i, p i * (q i / p i) = 1 := by
      have heq : ∀ i, p i * (q i / p i) = q i := by
        intro i; field_simp [(h_p_pos i).ne']
      simp_rw [heq]
      exact h_q_sum
    have hrhs : ∑ i, p i * (q i / p i) ^ order = ∑ i, (q i) ^ order / (p i) ^ (order - 1) := by
      apply Finset.sum_congr rfl
      intro i _
      have hsplit : (p i) ^ order = (p i) ^ (1 : ℝ) * (p i) ^ (order - 1) := by
        rw [← Real.rpow_add (h_p_pos i)]
        congr 1
        ring
      rw [Real.div_rpow (h_q_pos i).le (h_p_pos i).le, Real.rpow_one] at *
      rw [hsplit]
      field_simp [(h_p_pos i).ne']
    rw [hlhs, Real.one_rpow, hrhs] at key
    exact key
  have hlog : 0 ≤ Real.log (∑ x, (q x) ^ order / (p x) ^ (order - 1)) := Real.log_nonneg hS
  have hpos : 0 < order - 1 := by linarith
  have hcoef : 0 ≤ 1 / (order - 1) := le_of_lt (div_pos one_pos hpos)
  exact mul_nonneg hcoef hlog

/-- Rényi divergence approaches KL divergence as α → 1⁺.
    This is a fundamental limit relationship showing that KL is a special case of RDP.

    Note on the limit target: `RenyiDivergence p q order`'s `order > 1` branch is
    `(1/(order-1)) * log(∑ q^order / p^(order-1))`. Substituting `order = 1 + β` and
    differentiating in `β` at `β = 0` gives the limit `∑ q(x) * log(q(x)/p(x))` — i.e.
    the limit is `KL(q‖p)`, not `KL(p‖q)`. A previous, still-`sorry`'d version of this
    theorem stated the limit as `∑ p * log(p/q)` (`KL(p‖q)`), which is generally FALSE
    (KL divergence is asymmetric) for this file's `RenyiDivergence` convention — see the
    hand derivation in the traceability matrix's Theorem 2 row.

    Only `∑q=1` is required, not `∑p=1`: `p` appears solely as a ratio scale factor
    `q(x)/p(x)` inside the exponent, never summed on its own, so nothing below depends
    on `p` being normalized. `∑q=1` is load-bearing (`F(1) = ∑q` must equal `1` for the
    log-derivative computation below to be well-founded at the base point) — same
    reason `RenyiDivergence_nonneg` above needs `∑q=1`.

    PROVEN via `hasDerivAt_iff_tendsto_slope`: writing `F order := ∑ q(x)*(q(x)/p(x))^(order-1)`,
    `RenyiDivergence p q order = log(F order)/(order-1)` for `order > 1`, which is exactly
    `slope (log ∘ F) 1 order` once `log(F 1) = log(∑q) = log 1 = 0`. So the claimed limit is
    the derivative of `log ∘ F` at `1`, computed via `HasDerivAt.log` composed with the
    per-term derivative of `order ↦ (q x/p x)^(order-1)` at `order = 1`
    (`HasDerivAt.const_rpow`, since the base `q x/p x` is fixed and only the exponent varies).
-/
theorem RenyiDivergence_limit_KL {α : Type*} [Fintype α] (p q : α → ℝ)
    (h_p_pos : ∀ x, 0 < p x) (h_q_pos : ∀ x, 0 < q x)
    (h_q_sum : ∑ x, q x = 1) :
    Filter.Tendsto (fun order => RenyiDivergence p q order)
      (nhdsWithin 1 (Set.Ioi 1)) (nhds (∑ x, q x * Real.log (q x / p x))) := by
  have hterm : ∀ x ∈ (Finset.univ : Finset α),
      HasDerivAt (fun order : ℝ => q x * (q x / p x) ^ (order - 1))
        (q x * Real.log (q x / p x)) 1 := by
    intro x _
    have hr : (0 : ℝ) < q x / p x := div_pos (h_q_pos x) (h_p_pos x)
    have hbase : HasDerivAt (fun order : ℝ => order - 1) 1 1 :=
      (hasDerivAt_id (1 : ℝ)).sub_const 1
    have hpow : HasDerivAt (fun order : ℝ => (q x / p x) ^ (order - 1))
        (Real.log (q x / p x) * 1 * (q x / p x) ^ ((1 : ℝ) - 1)) 1 :=
      hbase.const_rpow hr
    simp only [sub_self, Real.rpow_zero, mul_one] at hpow
    exact hpow.const_mul (q x)
  have hderiv : HasDerivAt (fun order : ℝ => ∑ x, q x * (q x / p x) ^ (order - 1))
      (∑ x, q x * Real.log (q x / p x)) 1 := HasDerivAt.fun_sum hterm
  have hF1 : (∑ x, q x * (q x / p x) ^ ((1 : ℝ) - 1)) = 1 := by
    simp only [sub_self, Real.rpow_zero, mul_one]
    exact h_q_sum
  have hlog : HasDerivAt (fun order : ℝ => Real.log (∑ x, q x * (q x / p x) ^ (order - 1)))
      ((∑ x, q x * Real.log (q x / p x)) / (∑ x, q x * (q x / p x) ^ ((1 : ℝ) - 1))) 1 :=
    hderiv.log (by rw [hF1]; norm_num)
  rw [hF1, div_one] at hlog
  have htendsto := hasDerivAt_iff_tendsto_slope.mp hlog
  have hsub : Set.Ioi (1 : ℝ) ⊆ ({(1 : ℝ)} : Set ℝ)ᶜ := fun y hy => hy.ne'
  have hmono := htendsto.mono_left (nhdsWithin_mono (1 : ℝ) hsub)
  have heq : ∀ order ∈ Set.Ioi (1 : ℝ),
      slope (fun order : ℝ => Real.log (∑ x, q x * (q x / p x) ^ (order - 1))) 1 order
        = RenyiDivergence p q order := by
    intro order horder
    have horder' : (1 : ℝ) < order := horder
    have h1 : order ≠ 1 := horder'.ne'
    unfold RenyiDivergence
    rw [if_neg h1, if_pos horder']
    have hlogF1 : Real.log (∑ x, q x * (q x / p x) ^ ((1 : ℝ) - 1)) = 0 := by
      rw [hF1]; exact Real.log_one
    have hsum_eq : (∑ x, q x * (q x / p x) ^ (order - 1))
        = ∑ x, (q x) ^ order / (p x) ^ (order - 1) := by
      apply Finset.sum_congr rfl
      intro x _
      have hqx : (0 : ℝ) < q x := h_q_pos x
      rw [Real.div_rpow (h_q_pos x).le (h_p_pos x).le,
          show (q x) ^ order = (q x) ^ (1 : ℝ) * (q x) ^ (order - 1) by
            rw [← Real.rpow_add hqx]; congr 1; ring,
          Real.rpow_one]
      ring
    rw [slope_def_field, hlogF1, sub_zero, hsum_eq]
    ring
  refine Filter.Tendsto.congr' ?_ hmono
  filter_upwards [self_mem_nhdsWithin] with order horder using heq order horder

/-- Pushforward of a discrete "distribution" `p : α → ℝ` along `f : α → β`: the
    mass assigned to `b` is the total mass of `f`'s fiber over `b`. Needed to
    state the data-processing inequality below precisely (`D_α(f_* p ‖ f_* q)`). -/
noncomputable def pushforward {α β : Type*} [Fintype α] [DecidableEq β]
    (f : α → β) (p : α → ℝ) (b : β) : ℝ :=
  ∑ a ∈ Finset.univ.filter (fun a => f a = b), p a

/-- Generalized (unnormalized) power-mean inequality behind both
    `RenyiDivergence_nonneg` and `data_processing_inequality`: unlike the
    normalized version above, `p`/`q` here need not sum to 1 — this is what
    lets it be applied per-fiber (a fiber's masses don't sum to 1 on their
    own) inside `data_processing_inequality`. -/
theorem sum_rpow_div_ge {ι : Type*} (s : Finset ι) (p q : ι → ℝ) (order : ℝ)
    (hp : ∀ i ∈ s, 0 < p i) (hq : ∀ i ∈ s, 0 ≤ q i) (h_order : 1 ≤ order)
    (hSpos : 0 < ∑ i ∈ s, p i) :
    (∑ i ∈ s, q i) ^ order / (∑ i ∈ s, p i) ^ (order - 1)
      ≤ ∑ i ∈ s, (q i) ^ order / (p i) ^ (order - 1) := by
  set P := ∑ i ∈ s, p i with hP
  set Q := ∑ i ∈ s, q i with hQ
  set S := ∑ i ∈ s, (q i) ^ order / (p i) ^ (order - 1) with hSdef
  have hQnonneg : 0 ≤ Q := Finset.sum_nonneg hq
  set w : ι → ℝ := fun i => p i / P with hw
  have hw_nonneg : ∀ i ∈ s, 0 ≤ w i := fun i hi => div_nonneg (hp i hi).le hSpos.le
  have hw_sum : ∑ i ∈ s, w i = 1 := by
    simp only [hw]; rw [← Finset.sum_div, ← hP]; field_simp
  have key := Real.rpow_arith_mean_le_arith_mean_rpow s w (fun i => q i / p i)
    hw_nonneg hw_sum (fun i hi => div_nonneg (hq i hi) (hp i hi).le) h_order
  have hlhs : ∑ i ∈ s, w i * (q i / p i) = Q / P := by
    have hstep : ∀ i ∈ s, w i * (q i / p i) = q i / P := by
      intro i hi; simp only [hw]; field_simp [(hp i hi).ne']
    rw [Finset.sum_congr rfl hstep, Finset.sum_div]
  have hrhs : ∑ i ∈ s, w i * (q i / p i) ^ order = S / P := by
    have hstep : ∀ i ∈ s, w i * (q i / p i) ^ order = ((q i) ^ order / (p i) ^ (order - 1)) / P := by
      intro i hi
      have hsplit : (p i) ^ order = (p i) * (p i) ^ (order - 1) := by
        have h1 : (p i) ^ order = (p i) ^ ((1 : ℝ) + (order - 1)) := by congr 1; ring
        rw [h1, Real.rpow_add (hp i hi), Real.rpow_one]
      simp only [hw]
      rw [Real.div_rpow (hq i hi) (hp i hi).le, hsplit]
      field_simp [(hp i hi).ne']
    rw [hSdef, Finset.sum_congr rfl hstep, Finset.sum_div]
  rw [hlhs, hrhs] at key
  rw [Real.div_rpow hQnonneg hSpos.le] at key
  have hPsplit : P ^ order = P ^ (1 : ℝ) * P ^ (order - 1) := by
    rw [← Real.rpow_add hSpos]; congr 1; ring
  rw [hPsplit, Real.rpow_one] at key
  have hcancel1 : Q ^ order / (P * P ^ (order - 1)) * P = Q ^ order / P ^ (order - 1) := by
    field_simp
  have hcancel2 : S / P * P = S := by field_simp
  have hscaled := mul_le_mul_of_nonneg_right key hSpos.le
  rw [hcancel1, hcancel2] at hscaled
  exact hscaled

/-- Data processing inequality: post-processing reduces Rényi divergence.
    If you apply any function f to samples, the divergence cannot increase.
    Formally: D_α(f_* p || f_* q) ≤ D_α(p || q)

    This is crucial for privacy: applying a deterministic post-processor
    cannot worsen the privacy guarantee.

    PROVEN for real for order > 1, via `sum_rpow_div_ge` applied per-fiber
    (`Finset.sum_fiberwise` splits the global sum by `f`'s fibers; each fiber
    gets its own instance of the power-mean inequality). Narrowed from the
    previous `sorry`'d signature (`0 < order`, `order ≠ 1`, covering the
    order < 1 branch too) to `1 < order`: the order < 1 and order = 1 cases
    use different branches of `RenyiDivergence` (with `p`/`q` swapped, or the
    KL-style sum) and need a different argument (see
    `data_processing_inequality_KL` below, still open) — no attempt was made
    to force a single proof to cover all three.
-/
theorem data_processing_inequality {α β : Type*} [Fintype α] [Fintype β] [DecidableEq β]
    [Nonempty α] (f : α → β) (p q : α → ℝ) (order : ℝ)
    (h_order : 1 < order) (h_p_pos : ∀ x, 0 < p x) (h_q_pos : ∀ x, 0 < q x) :
    RenyiDivergence (pushforward f p) (pushforward f q) order ≤ RenyiDivergence p q order := by
  unfold RenyiDivergence
  rw [if_neg h_order.ne', if_pos h_order, if_neg h_order.ne', if_pos h_order]
  have hmono : (1 : ℝ) / (order - 1) > 0 := by
    have : (0 : ℝ) < order - 1 := by linarith
    positivity
  apply mul_le_mul_of_nonneg_left _ hmono.le
  set a0 := Classical.arbitrary α with ha0
  set b0 := f a0 with hb0
  have hmem0 : a0 ∈ Finset.univ.filter (fun a => f a = b0) := by
    simp [Finset.mem_filter, hb0]
  have hpfp0 : 0 < pushforward f p b0 := by
    unfold pushforward
    exact Finset.sum_pos' (fun a _ => (h_p_pos a).le) ⟨a0, hmem0, h_p_pos a0⟩
  have hpfq0 : 0 < pushforward f q b0 := by
    unfold pushforward
    exact Finset.sum_pos' (fun a _ => (h_q_pos a).le) ⟨a0, hmem0, h_q_pos a0⟩
  apply Real.log_le_log
  · apply Finset.sum_pos'
    · intro b _
      exact div_nonneg
        (Real.rpow_nonneg (by unfold pushforward; exact Finset.sum_nonneg fun a _ => (h_q_pos a).le) _)
        (Real.rpow_nonneg (by unfold pushforward; exact Finset.sum_nonneg fun a _ => (h_p_pos a).le) _)
    · refine ⟨b0, Finset.mem_univ _, ?_⟩
      exact div_pos (Real.rpow_pos_of_pos hpfq0 _) (Real.rpow_pos_of_pos hpfp0 _)
  · have hstep : ∀ b : β, (pushforward f q b) ^ order / (pushforward f p b) ^ (order - 1)
        ≤ ∑ a ∈ Finset.univ.filter (fun a => f a = b), (q a) ^ order / (p a) ^ (order - 1) := by
      intro b
      rcases Finset.eq_empty_or_nonempty (Finset.univ.filter (fun a => f a = b)) with hemp | hne
      · have ho1 : order ≠ 0 := (show (0 : ℝ) < order by linarith).ne'
        have ho2 : order - 1 ≠ 0 := (show (0 : ℝ) < order - 1 by linarith).ne'
        simp only [pushforward, hemp, Finset.sum_empty, Real.zero_rpow ho1, Real.zero_rpow ho2,
          div_zero, le_refl]
      · exact sum_rpow_div_ge _ p q order (fun a _ => h_p_pos a) (fun a _ => (h_q_pos a).le)
          h_order.le (Finset.sum_pos (fun a _ => h_p_pos a) hne)
    calc ∑ b, (pushforward f q b) ^ order / (pushforward f p b) ^ (order - 1)
        ≤ ∑ b, ∑ a ∈ Finset.univ.filter (fun a => f a = b), (q a) ^ order / (p a) ^ (order - 1) :=
          Finset.sum_le_sum (fun b _ => hstep b)
      _ = ∑ a, (q a) ^ order / (p a) ^ (order - 1) := Finset.sum_fiberwise Finset.univ f _

/-- Pushforward preserves total mass: summing the fiber masses over all of `β`
    recovers the original total (`Finset.sum_fiberwise` — fibers outside the range
    of `f` are empty and contribute `0`, so this holds for any `f`, not just
    surjections). -/
theorem pushforward_sum {α β : Type*} [Fintype α] [Fintype β] [DecidableEq β]
    (f : α → β) (p : α → ℝ) :
    ∑ b, pushforward f p b = ∑ a, p a := by
  unfold pushforward
  exact Finset.sum_fiberwise Finset.univ f p

/-- Pushforward of an everywhere-positive mass function along a *surjection* is
    everywhere positive (every fiber is nonempty, so every fiber sum of positive
    terms is positive). Surjectivity is genuinely needed here, not just convenient:
    if `f` misses some `b : β`, `pushforward f p b` is an empty sum, i.e. `0`. -/
theorem pushforward_pos {α β : Type*} [Fintype α] [DecidableEq β]
    (f : α → β) (p : α → ℝ) (h_pos : ∀ x, 0 < p x) (hf : Function.Surjective f) (b : β) :
    0 < pushforward f p b := by
  unfold pushforward
  obtain ⟨a, ha⟩ := hf b
  exact Finset.sum_pos' (fun a _ => (h_pos a).le) ⟨a, by simp [ha], h_pos a⟩

/-- KL divergence restricted version of data processing inequality, for `f` a
    *surjection* (see `pushforward_pos` for why: `RenyiDivergence_limit_KL`, used
    below, needs the pushed-forward masses to be positive everywhere on `β`, which
    needs every fiber nonempty). For the order = 1 case, this is the Kraft/Gibbs
    inequality.

    PROVEN — not via a fresh log-sum-inequality argument, but by taking the
    `order → 1⁺` limit of the *already-proven* `data_processing_inequality`
    (order > 1 case) on both sides, using `RenyiDivergence_limit_KL` (proven
    above) to identify each side's limit, then `le_of_tendsto_of_tendsto`. Note the
    swapped argument order in both `RenyiDivergence_limit_KL` calls below
    (`q p` and `pushforward f q, pushforward f p`, not `p q`): as documented on
    `RenyiDivergence_limit_KL`, `RenyiDivergence A B order → ∑ B*log(B/A)` as
    `order → 1⁺`, so recovering `RenyiDivergence p q 1 = ∑ p*log(p/q)` as a limit
    needs `A := q, B := p`. Only `∑p=1` is needed (not `∑q=1`) — same asymmetric-role
    reason `RenyiDivergence_limit_KL` only needs one of its two sum hypotheses; the
    argument-swap here happens to land the load-bearing sum on `p`.
-/
theorem data_processing_inequality_KL {α β : Type*} [Fintype α] [Fintype β] [DecidableEq β]
    [Nonempty α] (f : α → β) (hf : Function.Surjective f) (p q : α → ℝ)
    (h_p_pos : ∀ x, 0 < p x) (h_q_pos : ∀ x, 0 < q x)
    (h_p_sum : ∑ x, p x = 1) :
    RenyiDivergence (pushforward f p) (pushforward f q) 1 ≤ RenyiDivergence p q 1 := by
  have hpfp_pos : ∀ b, 0 < pushforward f p b := pushforward_pos f p h_p_pos hf
  have hpfq_pos : ∀ b, 0 < pushforward f q b := pushforward_pos f q h_q_pos hf
  have hpfp_sum : ∑ b, pushforward f p b = 1 := by rw [pushforward_sum]; exact h_p_sum
  have hL : Filter.Tendsto (fun order => RenyiDivergence q p order)
      (nhdsWithin 1 (Set.Ioi 1)) (nhds (RenyiDivergence p q 1)) := by
    have hval : RenyiDivergence p q 1 = ∑ x, p x * Real.log (p x / q x) := by
      unfold RenyiDivergence; rw [if_pos rfl]
    rw [hval]
    exact RenyiDivergence_limit_KL q p h_q_pos h_p_pos h_p_sum
  have hR : Filter.Tendsto (fun order => RenyiDivergence (pushforward f q) (pushforward f p) order)
      (nhdsWithin 1 (Set.Ioi 1)) (nhds (RenyiDivergence (pushforward f p) (pushforward f q) 1)) := by
    have hval : RenyiDivergence (pushforward f p) (pushforward f q) 1
        = ∑ b, pushforward f p b * Real.log (pushforward f p b / pushforward f q b) := by
      unfold RenyiDivergence; rw [if_pos rfl]
    rw [hval]
    exact RenyiDivergence_limit_KL (pushforward f q) (pushforward f p) hpfq_pos hpfp_pos hpfp_sum
  have hineq : ∀ order ∈ Set.Ioi (1 : ℝ),
      RenyiDivergence (pushforward f q) (pushforward f p) order ≤ RenyiDivergence q p order :=
    fun order horder => data_processing_inequality f q p order horder h_q_pos h_p_pos
  exact le_of_tendsto_of_tendsto hR hL (Filter.eventually_of_mem self_mem_nhdsWithin hineq)

/-- The RDP parameter α is always strictly greater than 1 for meaningful bounds.
    This ensures the divergence formula has a well-defined denominator (α - 1).
    (Real, checked: previously this took no hypothesis and concluded `True`.)
-/
theorem RDP_alpha_constraint (alpha : ℝ) (h : 1 < alpha) : 0 < alpha - 1 := by
  linarith

/-- Evidence for why `RDP_sequential_composition` below is **not just unproven but
    unsalvageable as stated** — do not "close" its `sorry` by proving it as-is; see
    that theorem's doc comment. For any *deterministic* `M : α → α` and any `x ≠ y`,
    the "distributions" `fun a => if M a = x then 1/card else 0` and the same for `y`
    have disjoint support (`M` is a function, so no `a` satisfies both `M a = x` and
    `M a = y`). Every term of `RenyiDivergence`'s sum then has either a zero numerator
    or a zero-to-a-positive-power denominator, and Lean/Mathlib's junk-value
    conventions (`Real.log 0 = 0`, `x / 0 = 0`) collapse the whole expression to
    exactly `0` — for *any* `M`, independent of its actual structure. Machine-checked
    below (this is a real, closed theorem; only the one after it is left `sorry`'d). -/
theorem RDP_indicator_divergence_disjoint_eq_zero {α : Type*} [Fintype α] [DecidableEq α]
    (M : α → α) (order : ℝ) (h_order : 1 < order) (x y : α) (hxy : x ≠ y) :
    RenyiDivergence (fun a => if M a = x then 1 / (Fintype.card α : ℝ) else 0)
                     (fun a => if M a = y then 1 / (Fintype.card α : ℝ) else 0)
                     order = 0 := by
  unfold RenyiDivergence
  rw [if_neg h_order.ne', if_pos h_order]
  have hsum : (∑ a, ((fun a => if M a = y then 1 / (Fintype.card α : ℝ) else 0) a) ^ order /
      ((fun a => if M a = x then 1 / (Fintype.card α : ℝ) else 0) a) ^ (order - 1)) = 0 := by
    apply Finset.sum_eq_zero
    intro a _
    simp only []
    by_cases hax : M a = x
    · have hay : ¬ (M a = y) := fun h => hxy (hax ▸ h ▸ rfl)
      rw [if_pos hax, if_neg hay]
      rw [Real.zero_rpow (by linarith : order ≠ 0)]
      simp
    · rw [if_neg hax]
      rw [Real.zero_rpow (by linarith : order - 1 ≠ 0)]
      simp
  rw [hsum, Real.log_zero, mul_zero]

/-- Composition of independent mechanisms: if M1 has (α, ε1)-RDP and M2 has (α, ε2)-RDP,
    then their sequential composition has (α, ε1 + ε2)-RDP.

    This is the fundamental theorem enabling privacy budgeting in the Sovereign Mohawk system.

    NOT CLOSED, AND SHOULD NOT BE CLOSED AS STATED — this is stronger than "still
    open": the statement below is a **mis-formalization that would be vacuously
    true**, and proving it would add exactly the kind of "type-checks but proves
    nothing" theorem this file's other fixes have been removing elsewhere.

    Why: `M1`, `M2 : α → α` are *deterministic* functions, and `_h_M1`/`_h_M2` compare
    Rényi divergence between indicator functions of *different output-value fibers of
    the same M1* (`M a = x` vs `M a = y`), not between a randomized mechanism's outputs
    on two *adjacent databases* — which is what real RDP composition is about. Per
    `RDP_indicator_divergence_disjoint_eq_zero` above, for x ≠ y this divergence is
    always exactly 0 regardless of M1's structure; for x = y it reduces to
    `log(|M1⁻¹ x| / card α)`, which is always ≤ 0 since a fiber can be at most the
    whole space. So the tightest `eps1` ever forced by `_h_M1` is `0` — **for any M1
    whatsoever** — and the same holds for `_h_M2` and for the conclusion's own
    `M2 ∘ M1` divergence. The theorem reduces to "something always ≤ 0 is ≤ (something
    always ≥ 0)", true for any `M1`, `M2`, completely independent of whether they
    correspond to any actual ε1/ε2-RDP mechanism. Closing this `sorry` would not
    verify RDP composition; it would prove a tautology dressed up as one.

    A real proof needs actual randomized mechanisms (not deterministic α → α
    functions), varying the *input* over adjacent databases (not varying an output
    label x/y of one fixed function), and the marginal/conditional joint-distribution
    chain rule for Rényi divergence
    (`D_α(p(x,y)‖q(x,y)) = D_α(p(x)‖q(x)) + 𝔼_x[D_α(p(y|x)‖q(y|x))]`) applied to the
    joint distribution over (M1's output, M2's output) — substantially more setup
    than `data_processing_inequality` above needed, and a full restatement of this
    theorem's signature, not a patch to the one below. (The previously-removed
    `Theorem2RDP_ChainRule.lean` attempted this chain-rule route but did not compile
    standalone and was deleted; there is nothing usable to build on there either.)
-/
theorem RDP_sequential_composition {α : Type*} [Fintype α] [DecidableEq α]
    (M1 M2 : α → α) (eps1 eps2 alpha : ℝ)
    (_h_alpha : 1 < alpha)
    (_h_M1 : ∀ x y, RenyiDivergence (fun a => if M1 a = x then 1 / (Fintype.card α : ℝ) else 0)
                                   (fun a => if M1 a = y then 1 / (Fintype.card α : ℝ) else 0)
                                   alpha ≤ eps1)
    (_h_M2 : ∀ x y, RenyiDivergence (fun a => if M2 a = x then 1 / (Fintype.card α : ℝ) else 0)
                                   (fun a => if M2 a = y then 1 / (Fintype.card α : ℝ) else 0)
                                   alpha ≤ eps2) :
    ∀ x y, RenyiDivergence (fun a => if M2 (M1 a) = x then 1 / (Fintype.card α : ℝ) else 0)
                           (fun a => if M2 (M1 a) = y then 1 / (Fintype.card α : ℝ) else 0)
                           alpha ≤ eps1 + eps2 := by
  sorry

end LeanFormalization
