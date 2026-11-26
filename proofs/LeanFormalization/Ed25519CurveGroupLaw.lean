import Mathlib
import LeanFormalization.Ed25519FieldBridge
import LeanFormalization.MontgomeryEdwardsAdditionCompat
set_option maxRecDepth 100000

/-!
# The Ed25519 affine addition law: what is proved and what stays open

`Ed25519.lean` defines `affineAdd` and `affineScalarMulImpl` over `Nat` with
`% ed25519P`. `Ed25519VerificationEquation.lean` consumes **four** group-law
hypotheses about them (`addMul`, `mulMul`, `congMul`, `injective`), because the
curve arithmetic was unaudited.

This module proves the group laws that are reachable without the algebraic
geometry of the curve, and pins the rest:

* `affineAdd_identity` / `affineAdd_identity_left` — `affineIdentity` is a
  two-sided identity for points whose `inf` flag is honest;
* `affineAdd_comm` — `affineAdd` is commutative on reduced representatives;
* `affineAdd_canonical` — the reduced-representative invariant is preserved.
* `affineAddFormula_zmod_eq_edAddField` and its `affineAdd` wrapper — the
  concrete Nat formula IS the abstract field law after casting to
  `ZMod ed25519P`, once the two denominators are nonzero. The on-curve variant
  discharges them from `edwards_denoms_ne_zero`, so the remaining hypotheses are
  exactly listed in its statement.

## What is still open, deliberately

**Associativity of `affineAdd` is NOT proved.** The field-level bridge is now
complete (`edAddField_associative_of_complete`), but transporting it to the Nat
implementation additionally needs: `Fact (Nat.Prime ed25519P)`,
`IsSquare (-1 : ZMod ed25519P)`, `¬ IsSquare (ed25519D : ZMod ed25519P)`, the
on-curve equations for all three inputs, and the distinctness/admissibility
conditions of the field theorem. None of these is supplied by the concrete
model, so the associativity claim stays a gap rather than being asserted. Note
also that the completeness hypothesis `IsSquare (-1)` is load-bearing: for
`a = -1`, nonsquareness of `d` alone does not imply completeness.

## Two hypotheses, both load-bearing

**`IsConsistent`** — `affineAdd` treats `inf = true` as "is the identity", but
the coordinates are unconstrained, so a point `{x := 5, y := 7, inf := true}` is
a *false infinity*: `affineAdd P affineIdentity` returns `affineIdentity`, not
`P`. The identity laws therefore assume `IsConsistent P`
(`P.inf = false ∨ P = affineIdentity`). Every point the implementation produces
is consistent (`affineIdentity`, `affineBase`, and the formula branch with
`inf := false`).

**Reduced coordinates** — `affineAdd`'s exceptional-case test is
`Q.x == (p - P.x) % p && Q.y == P.y`. For coordinates `≥ p` that test is **not**
symmetric, so commutativity fails; `isNegation_noncanonical_counterexample` is
the machine-checked witness. The invariant does hold for every point the
implementation produces (`fmul`, `fadd`, `fsub` all return `% ed25519P`), but
`AffinePoint` does not carry it, so the theorems state it explicitly.
-/

namespace LeanFormalization

/-! ### Point invariants -/

/-- `P` has reduced affine coordinates. Every point the implementation produces
    satisfies this (`fmul`, `fadd`, `fsub` return `% ed25519P`), but the
    structure does not carry the invariant. -/
def IsCanonical (P : AffinePoint) : Prop :=
  P.x < ed25519P ∧ P.y < ed25519P

/-- `P`'s `inf` flag agrees with its coordinates: either it is a genuine affine
    point, or it is exactly `affineIdentity`. -/
def IsConsistent (P : AffinePoint) : Prop :=
  P.inf = false ∨ P = affineIdentity

/-- The exceptional-case test in `affineAdd`, factored out as a `Bool` so its
    symmetry can be stated exactly as it appears. -/
def IsNegation (P Q : AffinePoint) : Bool :=
  (Q.x == (ed25519P - P.x) % ed25519P) && (Q.y == P.y)

/-! ### The exceptional-case test, made symmetric -/

/-- For a reduced `a`, `(p - a) % p` is `0` when `a = 0` and `p - a`
    otherwise. -/
theorem mod_sub_self_eq (a : Nat) (ha : a < ed25519P) :
    (ed25519P - a) % ed25519P = if a = 0 then 0 else ed25519P - a := by
  have hp := ed25519P_pos
  by_cases h : a = 0
  · subst h
    simp
  · have ha' : 0 < a := Nat.pos_of_ne_zero h
    have hlt : ed25519P - a < ed25519P := Nat.sub_lt hp ha'
    rw [if_neg h, Nat.mod_eq_of_lt hlt]

/-- On reduced coordinates the negation test is symmetric in its two
    arguments. -/
theorem beq_mod_sub_symm (a b : Nat) (ha : a < ed25519P) (hb : b < ed25519P) :
    (b == (ed25519P - a) % ed25519P) = (a == (ed25519P - b) % ed25519P) := by
  have hiff : (b = (ed25519P - a) % ed25519P) ↔ (a = (ed25519P - b) % ed25519P) := by
    rw [mod_sub_self_eq a ha, mod_sub_self_eq b hb]
    by_cases ha0 : a = 0
    · subst ha0
      simp
      omega
    · by_cases hb0 : b = 0
      · subst hb0
        simp
        omega
      · simp [ha0, hb0]
        omega
  by_cases hL : b = (ed25519P - a) % ed25519P
  · have hb1 : (b == (ed25519P - a) % ed25519P) = true := by simp [hL]
    have hR : a = (ed25519P - b) % ed25519P := hiff.mp hL
    have ha1 : (a == (ed25519P - b) % ed25519P) = true := by simp [hR]
    rw [hb1, ha1]
  · have hb1 : (b == (ed25519P - a) % ed25519P) = false := by simp [hL]
    have hR : a ≠ (ed25519P - b) % ed25519P := by
      intro hh
      exact hL (hiff.mpr hh)
    have ha1 : (a == (ed25519P - b) % ed25519P) = false := by simp [hR]
    rw [hb1, ha1]

theorem isNegation_comm (P Q : AffinePoint) (hxP : P.x < ed25519P) (hxQ : Q.x < ed25519P) :
    IsNegation P Q = IsNegation Q P := by
  unfold IsNegation
  rw [beq_mod_sub_symm P.x Q.x hxP hxQ]
  rw [show (Q.y == P.y) = (P.y == Q.y) from by simp [eq_comm]]

/-- **Negative control**: without reduced coordinates the negation test is not
    symmetric. `P.x = p` is not reduced; `IsNegation P Q` holds while
    `IsNegation Q P` does not, so `isNegation_comm`'s hypotheses are
    load-bearing. -/
theorem isNegation_noncanonical_counterexample :
    IsNegation ({ x := ed25519P, y := 0, inf := false : AffinePoint })
        ({ x := 0, y := 0, inf := false : AffinePoint }) = true ∧
    IsNegation ({ x := 0, y := 0, inf := false : AffinePoint })
        ({ x := ed25519P, y := 0, inf := false : AffinePoint }) = false := by
  have hp0 : ed25519P ≠ 0 := ne_of_gt ed25519P_pos
  have h1 : IsNegation ({ x := ed25519P, y := 0, inf := false : AffinePoint })
      ({ x := 0, y := 0, inf := false : AffinePoint }) = true := by
    unfold IsNegation
    simp
  have h2 : IsNegation ({ x := 0, y := 0, inf := false : AffinePoint })
      ({ x := ed25519P, y := 0, inf := false : AffinePoint }) = false := by
    unfold IsNegation
    simp [hp0]
  exact ⟨h1, h2⟩

/-! ### The addition formula is symmetric -/

/-- The unified twisted-Edwards addition formula (`a = -1`), factored out of
    `affineAdd` so its symmetry can be stated without the exceptional cases. -/
def affineAddFormula (x1 y1 x2 y2 : Nat) : AffinePoint :=
  let x3num := fadd (fmul x1 y2) (fmul y1 x2)
  let denom := fmul (fmul x1 x2) (fmul y1 y2)
  let denom1 := fadd 1 (fmul ed25519D denom)
  let denom2 := fsub 1 (fmul ed25519D denom)
  let x3 := fmul x3num (fInv denom1)
  let y3num := fadd (fmul y1 y2) (fmul x1 x2)
  let y3 := fmul y3num (fInv denom2)
  { x := x3, y := y3, inf := false }

theorem affineAddFormula_comm (x1 y1 x2 y2 : Nat) :
    affineAddFormula x1 y1 x2 y2 = affineAddFormula x2 y2 x1 y1 := by
  have hdenom : fmul (fmul x1 x2) (fmul y1 y2) = fmul (fmul x2 x1) (fmul y2 y1) := by
    unfold fmul
    rw [Nat.mul_comm x1 x2, Nat.mul_comm y1 y2]
  have hxnum : fadd (fmul x1 y2) (fmul y1 x2) = fadd (fmul x2 y1) (fmul y2 x1) := by
    unfold fadd fmul
    rw [Nat.mul_comm x1 y2, Nat.mul_comm y1 x2, Nat.add_comm]
  have hynum : fadd (fmul y1 y2) (fmul x1 x2) = fadd (fmul y2 y1) (fmul x2 x1) := by
    unfold fadd fmul
    rw [Nat.mul_comm y1 y2, Nat.mul_comm x1 x2]
  unfold affineAddFormula
  rw [hxnum, hdenom, hynum]

/-- `affineAdd` on non-exceptional points is the formula. -/
theorem affineAdd_eq_formula (P Q : AffinePoint) (hP : ¬ P.inf) (hQ : ¬ Q.inf)
    (hneg : IsNegation P Q = false) :
    affineAdd P Q = affineAddFormula P.x P.y Q.x Q.y := by
  unfold IsNegation at hneg
  unfold affineAdd
  rw [if_neg hP, if_neg hQ, hneg]
  rfl

/-! ### The proved group laws -/

/-- `affineIdentity` is a right identity for consistent points. -/
theorem affineAdd_identity (P : AffinePoint) (hc : IsConsistent P) :
    affineAdd P affineIdentity = P := by
  rcases hc with h | h
  · simp [affineAdd, affineIdentity, h]
  · rw [h]
    rfl

/-- `affineIdentity` is a left identity for consistent points. -/
theorem affineAdd_identity_left (P : AffinePoint) (hc : IsConsistent P) :
    affineAdd affineIdentity P = P := by
  rcases hc with h | h
  · rfl
  · rw [h]
    rfl

/-- **Negative control**: a false infinity is not a fixed point of
    `affineAdd · affineIdentity`, so `IsConsistent` is load-bearing. -/
theorem affineAdd_identity_false_infinity :
    affineAdd ({ x := 5, y := 7, inf := true : AffinePoint }) affineIdentity
      = affineIdentity := by
  rfl

/-- **`affineAdd` is commutative on reduced representatives.** -/
theorem affineAdd_comm (P Q : AffinePoint) (hP : ¬ P.inf) (hQ : ¬ Q.inf)
    (hxP : P.x < ed25519P) (hxQ : Q.x < ed25519P) :
    affineAdd P Q = affineAdd Q P := by
  have hneg : IsNegation P Q = IsNegation Q P := isNegation_comm P Q hxP hxQ
  cases hb : IsNegation P Q with
  | true =>
      have hb' : IsNegation Q P = true := by rw [← hneg]; exact hb
      have e1 : affineAdd P Q = affineIdentity := by
        unfold affineAdd
        rw [if_neg hP, if_neg hQ]
        simp only [IsNegation] at hb ⊢
        rw [hb]
        rfl
      have e2 : affineAdd Q P = affineIdentity := by
        unfold affineAdd
        rw [if_neg hQ, if_neg hP]
        simp only [IsNegation] at hb' ⊢
        rw [hb']
        rfl
      rw [e1, e2]
  | false =>
      have hb' : IsNegation Q P = false := by rw [← hneg]; exact hb
      rw [affineAdd_eq_formula P Q hP hQ hb, affineAdd_eq_formula Q P hQ hP hb',
          affineAddFormula_comm]

/-- `affineAdd` preserves reduced coordinates. -/
theorem affineAdd_canonical (P Q : AffinePoint) (hP : IsCanonical P) (hQ : IsCanonical Q) :
    IsCanonical (affineAdd P Q) := by
  have hp := ed25519P_pos
  have hone : 1 < ed25519P := by unfold ed25519P; norm_num
  unfold IsCanonical
  cases hPi : P.inf with
  | true =>
      have h : affineAdd P Q = Q := by simp [affineAdd, hPi]
      rw [h]
      exact hQ
  | false =>
      have hPi' : ¬ P.inf := by rw [hPi]; simp
      cases hQi : Q.inf with
      | true =>
          have h : affineAdd P Q = P := by simp [affineAdd, hPi, hQi]
          rw [h]
          exact hP
      | false =>
          have hQi' : ¬ Q.inf := by rw [hQi]; simp
          cases hb : IsNegation P Q with
          | true =>
              have h : affineAdd P Q = affineIdentity := by
                simp only [affineAdd, hPi, hQi]
                simp only [IsNegation] at hb ⊢
                rw [hb]
                rfl
              rw [h]
              exact ⟨hp, hone⟩
          | false =>
              have h : affineAdd P Q = affineAddFormula P.x P.y Q.x Q.y :=
                affineAdd_eq_formula P Q hPi' hQi' hb
              rw [h, affineAddFormula]
              exact ⟨Nat.mod_lt _ hp, Nat.mod_lt _ hp⟩

/-- The concrete Nat-based `affineAddFormula` is exactly the abstract field law
    `edAddField` after coercion to `ZMod ed25519P`, provided the two unified-law
    denominators are nonzero (needed to identify Nat `fInv` with the field
    inverse; `fmul_fInv_zero` is the negative control). -/
theorem affineAddFormula_zmod_eq_edAddField (hp : Fact (Nat.Prime ed25519P))
    (x1 y1 x2 y2 : ℕ)
    (hden1 : fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2))) % ed25519P ≠ 0)
    (hden2 : fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2))) % ed25519P ≠ 0) :
    (((affineAddFormula x1 y1 x2 y2).x : ZMod ed25519P),
     ((affineAddFormula x1 y1 x2 y2).y : ZMod ed25519P)) =
    edAddField (ed25519D : ZMod ed25519P) (x1 : ZMod ed25519P) (y1 : ZMod ed25519P)
      (x2 : ZMod ed25519P) (y2 : ZMod ed25519P) := by
  letI := hp
  have hinv1 : (fInv (fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) : ZMod ed25519P) =
      ((fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2))) : ℕ) : ZMod ed25519P)⁻¹ := by
    have hmul : fmul (fInv (fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))))
        (fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) = 1 := fmul_fInv hp hden1
    have hmulz : ((fmul (fInv (fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))))
        (fadd 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) : ℕ) : ZMod ed25519P) = 1 := by
      rw [hmul]
      norm_num
    rw [fmul_zmod] at hmulz
    exact eq_inv_of_mul_eq_one_left hmulz
  have hinv2 : (fInv (fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) : ZMod ed25519P) =
      ((fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2))) : ℕ) : ZMod ed25519P)⁻¹ := by
    have hmul : fmul (fInv (fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))))
        (fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) = 1 := fmul_fInv hp hden2
    have hmulz : ((fmul (fInv (fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))))
        (fsub 1 (fmul ed25519D (fmul (fmul x1 x2) (fmul y1 y2)))) : ℕ) : ZMod ed25519P) = 1 := by
      rw [hmul]
      norm_num
    rw [fmul_zmod] at hmulz
    exact eq_inv_of_mul_eq_one_left hmulz
  simp only [affineAddFormula, fadd_zmod, fsub_zmod, fmul_zmod, hinv1, hinv2, edAddField]
  ring_nf

/-- Wrapper for the four-branch `affineAdd`: the identity and negation branches
    are excluded explicitly because `edAddField` has no infinity flag or
    exceptional case. -/
theorem affineAdd_zmod_eq_edAddField (hp : Fact (Nat.Prime ed25519P)) (P Q : AffinePoint)
    (hP : ¬ P.inf) (hQ : ¬ Q.inf) (hneg : IsNegation P Q = false)
    (hden1 : fadd 1 (fmul ed25519D (fmul (fmul P.x Q.x) (fmul P.y Q.y))) % ed25519P ≠ 0)
    (hden2 : fsub 1 (fmul ed25519D (fmul (fmul P.x Q.x) (fmul P.y Q.y))) % ed25519P ≠ 0) :
    (((affineAdd P Q).x : ZMod ed25519P), ((affineAdd P Q).y : ZMod ed25519P)) =
    edAddField (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
      (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P) := by
  rw [affineAdd_eq_formula P Q hP hQ hneg]
  exact affineAddFormula_zmod_eq_edAddField hp P.x P.y Q.x Q.y hden1 hden2

/-- Full bridge: on-curve points plus twisted-Edwards completeness discharge the
    two denominator hypotheses, so the concrete `affineAdd` really computes the
    field-level Edwards sum. What remains explicit: primality of `p`,
    `IsSquare (-1)` and nonsquareness of `d` in `ZMod p`, the on-curve equations,
    and exclusion of the infinity/negation branches. -/
theorem affineAdd_zmod_eq_edAddField_of_onCurve (hp : Fact (Nat.Prime ed25519P))
    (hsq : IsSquare (-1 : ZMod ed25519P)) (hnd : ¬ IsSquare (ed25519D : ZMod ed25519P))
    (P Q : AffinePoint) (hP : ¬ P.inf) (hQ : ¬ Q.inf) (hneg : IsNegation P Q = false)
    (hEP : edwardsEq (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P))
    (hEQ : edwardsEq (ed25519D : ZMod ed25519P) (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P)) :
    (((affineAdd P Q).x : ZMod ed25519P), ((affineAdd P Q).y : ZMod ed25519P)) =
    edAddField (ed25519D : ZMod ed25519P) (P.x : ZMod ed25519P) (P.y : ZMod ed25519P)
      (Q.x : ZMod ed25519P) (Q.y : ZMod ed25519P) := by
  letI := hp
  have hD := edwards_denoms_ne_zero hEP hEQ hsq hnd
  let den := fmul (fmul P.x Q.x) (fmul P.y Q.y)
  have hden1Z : (1 : ZMod ed25519P) + (ed25519D : ZMod ed25519P) * (P.x : ZMod ed25519P) *
      (Q.x : ZMod ed25519P) * (P.y : ZMod ed25519P) * (Q.y : ZMod ed25519P) ≠ 0 := by
    simpa [mul_assoc] using hD.1
  have hden2Z : (1 : ZMod ed25519P) - (ed25519D : ZMod ed25519P) * (P.x : ZMod ed25519P) *
      (Q.x : ZMod ed25519P) * (P.y : ZMod ed25519P) * (Q.y : ZMod ed25519P) ≠ 0 := by
    simpa [mul_assoc] using hD.2
  have hden1nat : fadd 1 (fmul ed25519D den) % ed25519P ≠ 0 := by
    intro h
    have hv : fadd 1 (fmul ed25519D den) = 0 := by
      have h' : fadd 1 (fmul ed25519D den) % ed25519P = 0 := h
      rwa [Nat.mod_eq_of_lt (fadd_lt _ _)] at h'
    have hz : ((fadd 1 (fmul ed25519D den) : ℕ) : ZMod ed25519P) = 0 := by
      rw [hv]
      norm_num
    simp only [fadd_zmod, fmul_zmod] at hz
    exact hden1Z (by simpa [den, fmul_zmod, mul_assoc] using hz)
  have hden2nat : fsub 1 (fmul ed25519D den) % ed25519P ≠ 0 := by
    intro h
    have hv : fsub 1 (fmul ed25519D den) = 0 := by
      have h' : fsub 1 (fmul ed25519D den) % ed25519P = 0 := h
      rwa [Nat.mod_eq_of_lt (fsub_lt _ _)] at h'
    have hz : ((fsub 1 (fmul ed25519D den) : ℕ) : ZMod ed25519P) = 0 := by
      rw [hv]
      norm_num
    simp only [fsub_zmod, fmul_zmod] at hz
    exact hden2Z (by simpa [den, fmul_zmod, mul_assoc] using hz)
  exact affineAdd_zmod_eq_edAddField hp P Q hP hQ hneg hden1nat hden2nat

end LeanFormalization
