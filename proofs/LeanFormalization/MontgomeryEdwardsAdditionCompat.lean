import Mathlib
import LeanFormalization.EdwardsWeierstrassBridge

/-!
# Montgomery ↔ Edwards addition compatibility (machine-checked)

This module takes one more step on the Edwards → Weierstrass route documented in
`EdwardsWeierstrassBridge.lean`. It is deliberately scoped and states openly what
is and is not machine-checked.

## Machine-checked here

* `montWeier` / `montToWeier`: the Montgomery curve `M_{A,B} : B·v² = u³ + A·u² + u`
  is transformed into Mathlib's Weierstrass model
  `Y² = X³ + (A·B)·X² + B²·X` by `X = B·u`, `Y = B²·v`
  (`montgomeryToWeier_equation`).
* `montAdd`: the Montgomery secant addition law. `montToWeier_addCoord` shows it is
  exactly Mathlib's `WeierstrassCurve.Affine.addX` / `addY` under that scaling.
* `montAdd_associative_of_weierstrass`: associativity of `montAdd` is **inherited
  from Mathlib's `WeierstrassCurve.Affine.Point.instAddCommGroup`** (no new proof of
  the cubic identity), for triples with distinct secant coordinates and nonzero
  `v`. `#print axioms` on it reports only the kernel's standard axioms.
* `edAddField`: the twisted-Edwards unified law `a = -1` over a field.
  `montgomery_v_sq` and `edAdd_mont_u` prove that the Edwards sum's *u*-coordinate
  is transported to the Montgomery sum's *u*-coordinate, on the admissible locus.
* The **v-coordinate half is now machine-checked as a theorem**, not assumed:
  `edAdd_mont_v` proves it over an arbitrary field from explicit non-vanishing
  hypotheses. Its proof uses `edwards_of_montgomery_aux` (Montgomery points map to
  Edwards points), `edAddClosure_aux` (Edwards addition closes on `E_d` with
  explicit denominators), `edAddMont_v_mul_aux` (`x·v = -2u` on `E_d`), and
  `x3_mul_vadd_aux` (the small identity `x₃·v_add = -2·u_add`). The direct
  `field_simp`+`ring` expansion is degree 9; these four lemmas factor it into
  degree-4 and degree-16 pieces that the pinned toolchain discharges.
* `edAdd_toMont_eq_montAdd` is therefore **unconditional on any compatibility
  assumption**: both coordinates are proved.
* `edwards_denoms_ne_zero`: twisted-Edwards completeness for `a = -1` under the
  standard hypothesis `IsSquare (-1)` and `¬ IsSquare d`; both unified-law
  denominators are nonzero for every on-curve pair.
* **Negative control for `hu12`** (section `SecantMapNegativeControl`):
  `montAdd`'s slope divides by zero when `u₁ = u₂`.
  `montAdd_self_eq_degenerate` proves the collapse over an arbitrary
  field; concrete `F_11` witnesses show `montAdd` landing off-curve and
  the compatibility conclusion failing with `hu12` as the *only* dropped
  hypothesis (all other hypotheses of `edAdd_toMont_eq_montAdd` hold).

## Residual assumptions and scope limits (explicit, not hidden)

The proved compatibility still takes explicit non-vanishing hypotheses:
`hDenP` (cleared denominator of the Edwards sum's `x`-coordinate) and
`hPnumHyp` (its divided form, used to clear nested denominators). The former
`hx3` hypothesis is no longer needed: when the Edwards sum has `x₃ = 0`, both
sides map to `(0, 0)` on the Montgomery curve, discharged by
`montAdd_v_eq_zero_of_u_eq_zero`.

Transporting Mathlib's associativity back to the Edwards law is now a theorem:
`edAddField_associative_of_complete` derives the formerly assumed bundle
(`edwardsAddCompat_of_complete`), `1 + d ≠ 0`, and closure of all four
intermediate sums from `edwards_denoms_ne_zero`. What remains explicit is the
admissibility of the three inputs (`y ≠ 1`, `x ≠ 0`), three pairwise distinctness
conditions on the Montgomery u-coordinates, and four `y ≠ 1` conditions on the
intermediate sums -- the latter are genuine exceptional cases where the sum is
the affine identity, handled by the branch in the concrete `affineAdd`.

The tangent/doubling law (`montgomery_tangent_double_v`) is proved over an
arbitrary field and closes on `M_{A,B}`. The general field-level doubling
compatibility is now a theorem: `edwardsToMont_eq_montDouble` proves
`edwardsToMont d (edAddField d x y x y) = montDouble d u v` over an arbitrary
field from `edwardsEq d x y`, `1 - y ≠ 0`, `x ≠ 0`, `1 + d ≠ 0`, `2 ≠ 0` and
the two unified-law denominators `1 ± d·x²·y² ≠ 0`; `1 - y₃ ≠ 0` and
`1 + d·y² ≠ 0` are derived. The nested denominators are factored into the
closed-form lemmas `dbl_ed_u_formula`, `dbl_mont_u_formula`,
`dbl_tangent_slope_formula` and `dbl_x_mul_v_aux`, mirroring the secant
proof's `edAdd_mont_v` factorisation. The concrete `F_11` agreement
(`montDouble_matches_edAddField_zmod11`) remains as a positive control.

`edAddField_associative_double_of_complete` now covers the **doubling exceptional
case** `P = Q` of field-level associativity: over an arbitrary field with
twisted-Edwards completeness, the first addition is transported through
`montDouble` (via `montToWeier_doubleCoord` and
`montDouble_add_associative_of_weierstrass`), while the two outer secant sums
use `edwardsToMont_eq_montAdd_of_complete`. Its explicit residuals are the
admissibility of the two inputs (`x, x' ≠ 0`, `y, y' ≠ 1`), three u-coordinate
distinctness conditions (`u ≠ u₃`, `montDouble(u,v).1 ≠ u₃`,
`u ≠ montAdd(u,v,u₃,v₃).1`), and the three `y ≠ 1` conditions on the sums
`P+R`, `(P+P)+R` and `P+(P+R)`.

The concrete Edwards implementation `Ed25519.affineAdd` is `Nat`-based modulo
`2^255 - 19`; transporting these field-level results to it additionally needs a
`ZMod`-lifting argument, which remains separate.
-/

set_option maxRecDepth 100000
set_option maxHeartbeats 4000000
namespace LeanFormalization
noncomputable section
variable {K : Type*} [Field K] [DecidableEq K]

def montWeier (d : K) : WeierstrassCurve K :=
  WeierstrassCurve.mk 0 (montA d * montB d) 0 (montB d ^ 2) 0
def montToWeier (d : K) (u v : K) : K × K := (montB d * u, montB d ^ 2 * v)
def montAdd (d u1 v1 u2 v2 : K) : K × K :=
  let l := (v1 - v2) / (u1 - u2)
  let mu := montB d * l ^ 2 - montA d - u1 - u2
  (mu, l * (u1 - mu) - v1)

lemma montB_ne_zero {d : K} (hd : 1 + d ≠ 0) : montB d ≠ 0 := by
  unfold montB; exact div_ne_zero (by norm_num) hd

lemma montgomeryToWeier_equation {d u v : K} (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0) :
    (montWeier d).toAffine.Equation (montToWeier d u v).1 (montToWeier d u v).2 := by
  rw [WeierstrassCurve.Affine.equation_iff]
  unfold montWeier montToWeier
  dsimp
  unfold montA montB
  unfold montgomeryEq montA montB at hM
  field_simp [hd] at hM ⊢
  linear_combination -hM

lemma montToWeier_addCoord {d u1 v1 u2 v2 : K} (hd : 1 + d ≠ 0) (hu : u1 ≠ u2) :
    let W := (montWeier d).toAffine
    let l := W.slope (montB d * u1) (montB d * u2) (montB d ^ 2 * v1) (montB d ^ 2 * v2)
    montToWeier d (montAdd d u1 v1 u2 v2).1 (montAdd d u1 v1 u2 v2).2 =
      (W.addX (montB d * u1) (montB d * u2) l,
       W.addY (montB d * u1) (montB d * u2) (montB d ^ 2 * v1) l) := by
  dsimp
  have hB := montB_ne_zero hd
  have hX : montB d * u1 ≠ montB d * u2 := fun h => hu (mul_left_cancel₀ hB h)
  rw [WeierstrassCurve.Affine.slope_of_X_ne hX]
  unfold montWeier montToWeier montAdd
  dsimp
  field_simp [hB, hu]
  ring

lemma mont_nonsingular {d u v : K} (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0)
    (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    (montWeier d).toAffine.Nonsingular (montB d * u) (montB d ^ 2 * v) := by
  rw [WeierstrassCurve.Affine.nonsingular_iff']
  constructor
  · exact montgomeryToWeier_equation hM hd
  · right
    dsimp [montWeier]
    simpa only [zero_mul, add_zero] using
      (mul_ne_zero h2 (mul_ne_zero (pow_ne_zero 2 (montB_ne_zero hd)) hv))

lemma montAdd_associative_of_weierstrass {d u1 v1 u2 v2 u3 v3 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2) (hM3 : montgomeryEq d u3 v3)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hv1 : v1 ≠ 0) (hv2 : v2 ≠ 0) (hv3 : v3 ≠ 0)
    (hu12 : u1 ≠ u2) (hu23 : u2 ≠ u3)
    (hu12_3 : (montAdd d u1 v1 u2 v2).1 ≠ u3)
    (hu1_23 : u1 ≠ (montAdd d u2 v2 u3 v3).1) :
    montAdd d (montAdd d u1 v1 u2 v2).1 (montAdd d u1 v1 u2 v2).2 u3 v3 =
    montAdd d u1 v1 (montAdd d u2 v2 u3 v3).1 (montAdd d u2 v2 u3 v3).2 := by
  let W := (montWeier d).toAffine
  let X1 := montB d * u1; let Y1 := montB d ^ 2 * v1
  let X2 := montB d * u2; let Y2 := montB d ^ 2 * v2
  let X3 := montB d * u3; let Y3 := montB d ^ 2 * v3
  have hn1 : W.Nonsingular X1 Y1 := mont_nonsingular hM1 hd h2 hv1
  have hn2 : W.Nonsingular X2 Y2 := mont_nonsingular hM2 hd h2 hv2
  have hn3 : W.Nonsingular X3 Y3 := mont_nonsingular hM3 hd h2 hv3
  let P1 := WeierstrassCurve.Affine.Point.some X1 Y1 hn1
  let P2 := WeierstrassCurve.Affine.Point.some X2 Y2 hn2
  let P3 := WeierstrassCurve.Affine.Point.some X3 Y3 hn3
  let M12 := montAdd d u1 v1 u2 v2
  let M23 := montAdd d u2 v2 u3 v3
  have hB := montB_ne_zero hd
  have hX12 : X1 ≠ X2 := fun h => hu12 (mul_left_cancel₀ hB h)
  have hX23 : X2 ≠ X3 := fun h => hu23 (mul_left_cancel₀ hB h)
  have hX12_3 : montB d * M12.1 ≠ X3 := fun h => hu12_3 (mul_left_cancel₀ hB h)
  have hX1_23 : X1 ≠ montB d * M23.1 := fun h => hu1_23 (mul_left_cancel₀ hB h)
  let ℓ12 := W.slope X1 X2 Y1 Y2
  let ℓ23 := W.slope X2 X3 Y2 Y3
  let hn12 := WeierstrassCurve.Affine.nonsingular_add hn1 hn2 (fun h => hX12 h.1)
  let hn23 := WeierstrassCurve.Affine.nonsingular_add hn2 hn3 (fun h => hX23 h.1)
  have h12 : P1 + P2 = WeierstrassCurve.Affine.Point.some
      (W.addX X1 X2 ℓ12) (W.addY X1 X2 Y1 ℓ12) hn12 := by
    simpa [P1, P2, ℓ12] using
      (WeierstrassCurve.Affine.Point.add_of_X_ne (h₁ := hn1) (h₂ := hn2) hX12)
  have h23 : P2 + P3 = WeierstrassCurve.Affine.Point.some
      (W.addX X2 X3 ℓ23) (W.addY X2 X3 Y2 ℓ23) hn23 := by
    simpa [P2, P3, ℓ23] using
      (WeierstrassCurve.Affine.Point.add_of_X_ne (h₁ := hn2) (h₂ := hn3) hX23)
  -- coordinate incarnation of M12/M23
  have hc12 := montToWeier_addCoord (d := d) (u1 := u1) (v1 := v1) (u2 := u2) (v2 := v2) hd hu12
  have hc23 := montToWeier_addCoord (d := d) (u1 := u2) (v1 := v2) (u2 := u3) (v2 := v3) hd hu23
  have hc12x : montB d * M12.1 = W.addX X1 X2 ℓ12 := by
    have := congrArg Prod.fst hc12
    simpa [W, X1, Y1, X2, Y2, ℓ12, M12, montToWeier] using this
  have hc12y : montB d ^ 2 * M12.2 = W.addY X1 X2 Y1 ℓ12 := by
    have := congrArg Prod.snd hc12
    simpa [W, X1, Y1, X2, Y2, ℓ12, M12, montToWeier] using this
  have hc23x : montB d * M23.1 = W.addX X2 X3 ℓ23 := by
    have := congrArg Prod.fst hc23
    simpa [W, X2, Y2, X3, Y3, ℓ23, M23, montToWeier] using this
  have hc23y : montB d ^ 2 * M23.2 = W.addY X2 X3 Y2 ℓ23 := by
    have := congrArg Prod.snd hc23
    simpa [W, X2, Y2, X3, Y3, ℓ23, M23, montToWeier] using this
  -- rebuild P12/P23 at the montAdd coordinates using the transported nonsingularity
  let hn12' : W.Nonsingular (montB d * M12.1) (montB d ^ 2 * M12.2) := by
    rw [hc12x, hc12y]; exact hn12
  let hn23' : W.Nonsingular (montB d * M23.1) (montB d ^ 2 * M23.2) := by
    rw [hc23x, hc23y]; exact hn23
  let P12 := WeierstrassCurve.Affine.Point.some (montB d * M12.1) (montB d ^ 2 * M12.2) hn12'
  let P23 := WeierstrassCurve.Affine.Point.some (montB d * M23.1) (montB d ^ 2 * M23.2) hn23'
  have h12' : P1 + P2 = P12 := by
    rw [h12]
    dsimp [P12]
    rw [WeierstrassCurve.Affine.Point.some.injEq]
    exact ⟨hc12x.symm, hc12y.symm⟩
  have h23' : P2 + P3 = P23 := by
    rw [h23]
    dsimp [P23]
    rw [WeierstrassCurve.Affine.Point.some.injEq]
    exact ⟨hc23x.symm, hc23y.symm⟩
  have hassoc := add_assoc P1 P2 P3
  rw [h12', h23'] at hassoc
  -- rewrite the outer additions
  rw [WeierstrassCurve.Affine.Point.add_of_X_ne hX12_3] at hassoc
  rw [WeierstrassCurve.Affine.Point.add_of_X_ne hX1_23] at hassoc
  rw [WeierstrassCurve.Affine.Point.some.injEq] at hassoc
  rcases hassoc with ⟨hxeq, hyeq⟩
  let Lres := montAdd d M12.1 M12.2 u3 v3
  let Rres := montAdd d u1 v1 M23.1 M23.2
  have hcL := montToWeier_addCoord (d := d) (u1 := M12.1) (v1 := M12.2) (u2 := u3) (v2 := v3) hd hu12_3
  have hcR := montToWeier_addCoord (d := d) (u1 := u1) (v1 := v1) (u2 := M23.1) (v2 := M23.2) hd hu1_23
  have hcLx : montB d * Lres.1 = W.addX (montB d * M12.1) X3 (W.slope (montB d * M12.1) X3 (montB d ^ 2 * M12.2) Y3) := by
    have := congrArg Prod.fst hcL
    simpa [W, Lres, X3, Y3, montToWeier] using this
  have hcRx : montB d * Rres.1 = W.addX X1 (montB d * M23.1) (W.slope X1 (montB d * M23.1) Y1 (montB d ^ 2 * M23.2)) := by
    have := congrArg Prod.fst hcR
    simpa [W, Rres, X1, Y1, montToWeier] using this
  have hcLy : montB d ^ 2 * Lres.2 = W.addY (montB d * M12.1) X3 (montB d ^ 2 * M12.2) (W.slope (montB d * M12.1) X3 (montB d ^ 2 * M12.2) Y3) := by
    have := congrArg Prod.snd hcL
    simpa [W, Lres, X3, Y3, montToWeier] using this
  have hcRy : montB d ^ 2 * Rres.2 = W.addY X1 (montB d * M23.1) Y1 (W.slope X1 (montB d * M23.1) Y1 (montB d ^ 2 * M23.2)) := by
    have := congrArg Prod.snd hcR
    simpa [W, Rres, X1, Y1, montToWeier] using this
  -- hxeq/hyeq are between those addX/addY terms; align
  have hx' : montB d * Lres.1 = montB d * Rres.1 := by
    rw [hcLx, hcRx]
    -- hxeq may need matching with renamed slope args
    simpa [W, ℓ12, ℓ23] using hxeq
  have hy' : montB d ^ 2 * Lres.2 = montB d ^ 2 * Rres.2 := by
    rw [hcLy, hcRy]
    simpa [W, ℓ12, ℓ23] using hyeq
  apply Prod.ext
  · exact mul_left_cancel₀ hB hx'
  · exact mul_left_cancel₀ (pow_ne_zero 2 hB) hy'


/-- Twisted-Edwards unified addition law for `a = -1`, over a field. -/
def edAddField (d x1 y1 x2 y2 : K) : K × K :=
  ((x1 * y2 + y1 * x2) / (1 + d * x1 * x2 * y1 * y2),
   (y1 * y2 + x1 * x2) / (1 - d * x1 * x2 * y1 * y2))

/-- Every Montgomery point satisfies `v² = -u·Q(u)`, where `Q` is `montQ`. -/
lemma montgomery_v_sq {d u v : K} (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0) :
    v ^ 2 = -(u * montQ d u) := by
  unfold montgomeryEq montA montB at hM
  unfold montQ
  field_simp [hd] at hM
  linear_combination -hM

/-- If the Montgomery secant sum has `u`-coordinate zero, its `v`-coordinate is
    also zero. Uses only the two Montgomery curve equations and `u₁ ≠ u₂`.
    This is the torsion case that removes `x₃ ≠ 0` from the v-coordinate
    compatibility: when the Edwards sum has `x₃ = 0`, both sides map to `(0, 0)`. -/
lemma montAdd_v_eq_zero_of_u_eq_zero {d u1 v1 u2 v2 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2)
    (hd : 1 + d ≠ 0) (hu12 : u1 ≠ u2)
    (hmu : (montAdd d u1 v1 u2 v2).1 = 0) :
    (montAdd d u1 v1 u2 v2).2 = 0 := by
  let l := (v1 - v2) / (u1 - u2)
  let nu := (montAdd d u1 v1 u2 v2).2
  have hsub : u1 - u2 ≠ 0 := sub_ne_zero.mpr hu12
  have hl_mul : l * (u1 - u2) = v1 - v2 := by
    dsimp [l]
    field_simp [hsub]
  have hmu0 : montB d * l ^ 2 - montA d - u1 - u2 = 0 := by
    simpa [montAdd, l] using hmu
  have hl2 : l ^ 2 = -2 * (1 - d) - (1 + d) * (u1 + u2) := by
    have h := hmu0
    unfold montA montB at h
    field_simp [hd] at h
    ring_nf at h ⊢
    linear_combination -h
  have hv1 := montgomery_v_sq hM1 hd
  have hv2 := montgomery_v_sq hM2 hd
  have hv1' : v1 ^ 2 = -((1 + d) * u1 ^ 3 + 2 * (1 - d) * u1 ^ 2 + (1 + d) * u1) := by
    rw [hv1]
    unfold montQ
    ring
  have hv2' : v2 ^ 2 = -((1 + d) * u2 ^ 3 + 2 * (1 - d) * u2 ^ 2 + (1 + d) * u2) := by
    rw [hv2]
    unfold montQ
    ring
  have hnu1 : nu = l * u1 - v1 := by
    dsimp [nu, montAdd]
    rw [show montB d * ((v1 - v2) / (u1 - u2)) ^ 2 - montA d - u1 - u2 = 0 by
      simpa [l] using hmu0]
    ring
  have hnu2 : nu = l * u2 - v2 := by
    rw [hnu1]
    linear_combination hl_mul
  have htmp : (u1 - u2) * ((l * u1 - v1) * (l * u2 - v2)) =
      (u1 * u2) * (u1 - u2) * l ^ 2 + u1 * v2 ^ 2 - u2 * v1 ^ 2 := by
    linear_combination -(u1 * v2 + u2 * v1) * hl_mul
  have hsq_mul : (u1 - u2) * nu ^ 2 = 0 := by
    rw [show nu ^ 2 = (l * u1 - v1) * (l * u2 - v2) by
      rw [← hnu1, ← hnu2]
      ring]
    rw [htmp]
    rw [hl2, hv1', hv2']
    ring
  have hsq : nu ^ 2 = 0 := by
    exact (mul_eq_zero.mp hsq_mul).resolve_left hsub
  have hnu : nu = 0 := by
    have h' : nu * nu = 0 := by simpa [pow_two] using hsq
    rcases mul_eq_zero.mp h' with h | h <;> exact h
  exact hnu

/-- The `u`-coordinate half of Edwards → Montgomery addition compatibility. -/
lemma edAdd_mont_u {d u1 v1 u2 v2 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hu1 : u1 + 1 ≠ 0) (hu2 : u2 + 1 ≠ 0)
    (hq1 : montQ d u1 ≠ 0) (hq2 : montQ d u2 ≠ 0)
    (hu12 : u1 ≠ u2)
    (hD1 : 1 + d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hD2 : 1 - d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hy3 : 1 - (edAddField d
        (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
        (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2 ≠ 0)
    (hDenQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d ≠ 0)
    (hNumQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d -
              ((u1 - 1) * (u2 - 1) * montQ d u1 * montQ d u2 +
               (u1 + 1) * (u2 + 1) * (2 : K) ^ 2 * v1 * v2) ≠ 0) :
    (edwardsToMont d
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).1
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2).1 =
      (montAdd d u1 v1 u2 v2).1 := by
  have hv1 := montgomery_v_sq hM1 hd
  have hv2 := montgomery_v_sq hM2 hd
  have hsub : u1 - u2 ≠ 0 := sub_ne_zero.mpr hu12
  have hv1c : v1 ^ 3 = -(u1 * montQ d u1) * v1 := by
    rw [show v1 ^ 3 = v1 ^ 2 * v1 by ring, hv1]
  have hv2c : v2 ^ 3 = -(u2 * montQ d u2) * v2 := by
    rw [show v2 ^ 3 = v2 ^ 2 * v2 by ring, hv2]
  simp only [edAddField, edwardsToMont, montAdd, montA, montB]
  field_simp [hu1, hu2, hq1, hq2, hu12, hD1, hD2, hy3, hDenQ, hNumQ, hsub, hd, h2]
  ring_nf
  rw [hv1, hv2, hv1c, hv2c]
  unfold montQ
  ring

/-- **Twisted-Edwards completeness.** For `a = -1`, if `-1` is a square in `K`
    and `d` is not a square, then both denominators of the unified law are
    nonzero for every pair of on-curve points. This is the standard completeness
    condition (the `a = -1` special case uses `IsSquare (-1)`; for Ed25519
    `p = 2^255 - 19 ≡ 1 mod 4`, so `-1` is a square). The `IsSquare (-1)`
    hypothesis is load-bearing: the `CompletenessNegativeControl` section below
    proves explicit on-curve counterexamples over `F_11` where `d = 2` is a
    nonsquare but `-1` is not. No division, no `2 ≠ 0` and no coordinate-nonzero
    hypotheses are needed.

    Proof shape: a vanishing denominator forces `(d·x₁·x₂·y₁·y₂)² = 1`. Combining
    that with the two curve equations by one explicit `linear_combination`
    certificate yields `(1 + d·y₁²)·((d·x₁²·y₂² - 1)·(d·y₁²·y₂² + 1)) = 0`;
    cancelling `1 + d·y₁²` leaves either `d = (d·x₁·y₂)²` or
    `d = (i·d·y₁·y₂)²`, each contradicting `¬ IsSquare d`. -/
lemma edwards_denoms_ne_zero {d x1 y1 x2 y2 : K}
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2)
    (hi : IsSquare (-1 : K)) (hnd : ¬ IsSquare d) :
    1 + d * x1 * x2 * y1 * y2 ≠ 0 ∧ 1 - d * x1 * x2 * y1 * y2 ≠ 0 := by
  rcases hi with ⟨i, hi⟩
  have h1d : 1 + d ≠ 0 := by
    intro h
    have hd_eq : d = -1 := by linear_combination h
    have hd_sq : d = i * i := by rw [hd_eq, hi]
    exact hnd ⟨i, hd_sq⟩
  have hcurve1 : x1 ^ 2 * (1 + d * y1 ^ 2) = y1 ^ 2 - 1 := by
    unfold edwardsEq at hE1
    linear_combination -hE1
  have hcurve2 : x2 ^ 2 * (1 + d * y2 ^ 2) = y2 ^ 2 - 1 := by
    unfold edwardsEq at hE2
    linear_combination -hE2
  have hdy1 : 1 + d * y1 ^ 2 ≠ 0 := by
    intro h
    have hc := hcurve1
    rw [h] at hc
    have hy2 : y1 ^ 2 = 1 := by linear_combination -hc
    have hdy : d * y1 ^ 2 = -1 := by linear_combination h
    have hd_eq_neg : d = -1 := by
      calc d = d * 1 := by ring
        _ = d * y1 ^ 2 := by rw [hy2]
        _ = -1 := hdy
    exact h1d (by rw [hd_eq_neg]; ring)
  have hDsq_plus (hD : 1 + d * x1 * x2 * y1 * y2 = 0) :
      d ^ 2 * x1 ^ 2 * x2 ^ 2 * y1 ^ 2 * y2 ^ 2 - 1 = 0 := by
    have ht : d * x1 * x2 * y1 * y2 = -1 := by linear_combination hD
    calc d ^ 2 * x1 ^ 2 * x2 ^ 2 * y1 ^ 2 * y2 ^ 2 - 1 =
        (d * x1 * x2 * y1 * y2) ^ 2 - 1 := by ring
      _ = 0 := by rw [ht]; ring
  have hDsq_minus (hD : 1 - d * x1 * x2 * y1 * y2 = 0) :
      d ^ 2 * x1 ^ 2 * x2 ^ 2 * y1 ^ 2 * y2 ^ 2 - 1 = 0 := by
    have ht : d * x1 * x2 * y1 * y2 = 1 := by linear_combination -hD
    calc d ^ 2 * x1 ^ 2 * x2 ^ 2 * y1 ^ 2 * y2 ^ 2 - 1 =
        (d * x1 * x2 * y1 * y2) ^ 2 - 1 := by ring
      _ = 0 := by rw [ht]; ring
  constructor
  · intro hD
    have hDsq := hDsq_plus hD
    have hmaster : (1 + d * y1 ^ 2) *
        ((d * x1 ^ 2 * y2 ^ 2 - 1) * (d * y1 ^ 2 * y2 ^ 2 + 1)) = 0 := by
      linear_combination ((1 + d * y1 ^ 2) * (1 + d * y2 ^ 2)) * hDsq -
        ((1 + d * y1 ^ 2) * d ^ 2 * x1 ^ 2 * y1 ^ 2 * y2 ^ 2) * hcurve2 +
        (d * y2 ^ 2 * (1 + d * y1 ^ 2)) * hcurve1
    have hfactor : (d * x1 ^ 2 * y2 ^ 2 - 1) * (d * y1 ^ 2 * y2 ^ 2 + 1) = 0 :=
      (mul_eq_zero.mp hmaster).resolve_left hdy1
    rcases mul_eq_zero.mp hfactor with hA | hB
    · have hA' : d * x1 ^ 2 * y2 ^ 2 = 1 := by linear_combination hA
      have hsqrt : d = (d * x1 * y2) * (d * x1 * y2) := by
        calc d = d * 1 := by ring
          _ = d * (d * x1 ^ 2 * y2 ^ 2) := by rw [hA']
          _ = (d * x1 * y2) * (d * x1 * y2) := by ring
      exact hnd ⟨d * x1 * y2, hsqrt⟩
    · have hB' : d * y1 ^ 2 * y2 ^ 2 = -1 := by linear_combination hB
      have hnegd : -d = (d * y1 * y2) * (d * y1 * y2) := by
        calc -d = d * (d * y1 ^ 2 * y2 ^ 2) := by rw [hB']; ring
          _ = (d * y1 * y2) * (d * y1 * y2) := by ring
      have hsqrt : d = (i * (d * y1 * y2)) * (i * (d * y1 * y2)) := by
        calc d = -(-d) := by ring
          _ = -((d * y1 * y2) * (d * y1 * y2)) := by rw [hnegd]
          _ = (i * i) * ((d * y1 * y2) * (d * y1 * y2)) := by rw [← hi]; ring
          _ = (i * (d * y1 * y2)) * (i * (d * y1 * y2)) := by ring
      exact hnd ⟨i * (d * y1 * y2), hsqrt⟩
  · intro hD
    have hDsq := hDsq_minus hD
    have hmaster : (1 + d * y1 ^ 2) *
        ((d * x1 ^ 2 * y2 ^ 2 - 1) * (d * y1 ^ 2 * y2 ^ 2 + 1)) = 0 := by
      linear_combination ((1 + d * y1 ^ 2) * (1 + d * y2 ^ 2)) * hDsq -
        ((1 + d * y1 ^ 2) * d ^ 2 * x1 ^ 2 * y1 ^ 2 * y2 ^ 2) * hcurve2 +
        (d * y2 ^ 2 * (1 + d * y1 ^ 2)) * hcurve1
    have hfactor : (d * x1 ^ 2 * y2 ^ 2 - 1) * (d * y1 ^ 2 * y2 ^ 2 + 1) = 0 :=
      (mul_eq_zero.mp hmaster).resolve_left hdy1
    rcases mul_eq_zero.mp hfactor with hA | hB
    · have hA' : d * x1 ^ 2 * y2 ^ 2 = 1 := by linear_combination hA
      have hsqrt : d = (d * x1 * y2) * (d * x1 * y2) := by
        calc d = d * 1 := by ring
          _ = d * (d * x1 ^ 2 * y2 ^ 2) := by rw [hA']
          _ = (d * x1 * y2) * (d * x1 * y2) := by ring
      exact hnd ⟨d * x1 * y2, hsqrt⟩
    · have hB' : d * y1 ^ 2 * y2 ^ 2 = -1 := by linear_combination hB
      have hnegd : -d = (d * y1 * y2) * (d * y1 * y2) := by
        calc -d = d * (d * y1 ^ 2 * y2 ^ 2) := by rw [hB']; ring
          _ = (d * y1 * y2) * (d * y1 * y2) := by ring
      have hsqrt : d = (i * (d * y1 * y2)) * (i * (d * y1 * y2)) := by
        calc d = -(-d) := by ring
          _ = -((d * y1 * y2) * (d * y1 * y2)) := by rw [hnegd]
          _ = (i * i) * ((d * y1 * y2) * (d * y1 * y2)) := by rw [← hi]; ring
          _ = (i * (d * y1 * y2)) * (i * (d * y1 * y2)) := by ring
      exact hnd ⟨i * (d * y1 * y2), hsqrt⟩

section CompletenessNegativeControl

/-! ### Negative control: nonsquareness of `d` alone is NOT enough

    Machine-checked witnesses over `F_11`, where `d = 2` is a nonsquare and
    `-1` is also a nonsquare: both unified-law denominators vanish for explicit
    on-curve pairs. This makes the extra `IsSquare (-1)` hypothesis of
    `edwards_denoms_ne_zero` load-bearing rather than an artifact of the proof. -/
local instance : Fact (Nat.Prime 11) := ⟨by norm_num⟩

lemma neg_one_not_square_zmod11 : ¬ IsSquare (-1 : ZMod 11) := by
  rw [ZMod.exists_sq_eq_neg_one_iff]
  norm_num

lemma two_not_square_zmod11 : ¬ IsSquare (2 : ZMod 11) := by
  decide

lemma zmod11_curve_1_3 : edwardsEq (2 : ZMod 11) 1 3 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 8 19 11).2 (by norm_num)
lemma zmod11_curve_4_5 : edwardsEq (2 : ZMod 11) 4 5 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 9 801 11).2 (by norm_num)
lemma zmod11_curve_4_6 : edwardsEq (2 : ZMod 11) 4 6 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 20 1153 11).2 (by norm_num)

lemma zmod11_den_plus_zero : 1 + (2 : ZMod 11) * 1 * 4 * 3 * 5 = 0 := by decide
lemma zmod11_den_minus_zero : 1 - (2 : ZMod 11) * 1 * 4 * 3 * 6 = 0 := by decide

lemma edwards_denoms_completeness_counterexample_plus :
    ¬ (∀ {x1 y1 x2 y2 : ZMod 11},
      edwardsEq 2 x1 y1 → edwardsEq 2 x2 y2 → 1 + 2 * x1 * x2 * y1 * y2 ≠ 0) := by
  intro h
  exact h (x1 := 1) (y1 := 3) (x2 := 4) (y2 := 5) zmod11_curve_1_3 zmod11_curve_4_5 zmod11_den_plus_zero

lemma edwards_denoms_completeness_counterexample_minus :
    ¬ (∀ {x1 y1 x2 y2 : ZMod 11},
      edwardsEq 2 x1 y1 → edwardsEq 2 x2 y2 → 1 - 2 * x1 * x2 * y1 * y2 ≠ 0) := by
  intro h
  exact h (x1 := 1) (y1 := 3) (x2 := 4) (y2 := 6) zmod11_curve_1_3 zmod11_curve_4_6 zmod11_den_minus_zero

lemma edwards_denoms_completeness_counterexample_combined :
    ¬ (∀ {x1 y1 x2 y2 : ZMod 11},
      edwardsEq 2 x1 y1 → edwardsEq 2 x2 y2 →
        (1 + 2 * x1 * x2 * y1 * y2 ≠ 0 ∧ 1 - 2 * x1 * x2 * y1 * y2 ≠ 0)) := by
  intro h
  exact (h (x1 := 1) (y1 := 3) (x2 := 4) (y2 := 5)
    zmod11_curve_1_3 zmod11_curve_4_5).1 zmod11_den_plus_zero

/-! ### Negative control: squareness of `d` is load-bearing

    Two machine-checked refutations of the completeness conclusion when the
    `¬ IsSquare d` hypothesis of `edwards_denoms_ne_zero` is dropped.

    * Over `F_7` with `d = 4 = 2^2` (a square), the on-curve points `(1,2)` and
      `(2,3)` make `1 + d·x₁·x₂·y₁·y₂ = 0`. Here `-1` is NOT a square
      (`neg_one_not_square_zmod7`), so this control cannot also keep the
      `IsSquare (-1)` hypothesis; it refutes completeness for square `d` in
      the requested smallest field.
    * Over `F_13`, `-1` IS a square and `d = 3 = 4^2` IS a square, yet the
      on-curve points `(1,5)` and `(2,3)` again make the plus denominator
      vanish. This is the strict control: `edwards_denoms_ne_zero_requires_`
      `d_nonsquare_strict` drops ONLY `¬ IsSquare d` from `edwards_denoms_ne_zero`.
-/
local instance : Fact (Nat.Prime 7) := ⟨by norm_num⟩
local instance : Fact (Nat.Prime 13) := ⟨by norm_num⟩

lemma neg_one_not_square_zmod7 : ¬ IsSquare (-1 : ZMod 7) := by decide
lemma four_square_zmod7 : IsSquare (4 : ZMod 7) := by decide

lemma zmod7_curve_1_2 : edwardsEq (4 : ZMod 7) 1 2 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 3 17 7).2 (by norm_num)

lemma zmod7_curve_2_3 : edwardsEq (4 : ZMod 7) 2 3 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 5 145 7).2 (by norm_num)

lemma zmod7_den_plus_zero : 1 + (4 : ZMod 7) * 1 * 2 * 2 * 3 = 0 := by decide

/-- Over `F_7`, `d = 4` is a square and completeness fails: the universal
    plus-denominator statement is refuted by `(1,2)`, `(2,3)`. -/
lemma edwards_denoms_ne_zero_requires_d_nonsquare :
    ¬ (∀ {d x1 y1 x2 y2 : ZMod 7},
      edwardsEq d x1 y1 → edwardsEq d x2 y2 → 1 + d * x1 * x2 * y1 * y2 ≠ 0) := by
  intro h
  exact h (d := 4) (x1 := 1) (y1 := 2) (x2 := 2) (y2 := 3)
    zmod7_curve_1_2 zmod7_curve_2_3 zmod7_den_plus_zero

lemma neg_one_square_zmod13 : IsSquare (-1 : ZMod 13) := by decide
lemma three_square_zmod13 : IsSquare (3 : ZMod 13) := by decide

lemma zmod13_curve_1_5 : edwardsEq (3 : ZMod 13) 1 5 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 24 76 13).2 (by norm_num)

lemma zmod13_curve_2_3 : edwardsEq (3 : ZMod 13) 2 3 := by
  unfold edwardsEq
  norm_num
  exact (ZMod.natCast_eq_natCast_iff 5 109 13).2 (by norm_num)

lemma zmod13_den_plus_zero : 1 + (3 : ZMod 13) * 1 * 2 * 5 * 3 = 0 := by decide

/-- Strict load-bearing control: over `F_13`, `-1` is a square but `d = 3` is
    also a square, and the plus denominator vanishes. Hence the `¬ IsSquare d`
    hypothesis of `edwards_denoms_ne_zero` cannot be removed even keeping
    `IsSquare (-1)`. -/
lemma edwards_denoms_ne_zero_requires_d_nonsquare_strict :
    ¬ (∀ {d x1 y1 x2 y2 : ZMod 13},
      edwardsEq d x1 y1 → edwardsEq d x2 y2 → IsSquare (-1 : ZMod 13) →
        1 + d * x1 * x2 * y1 * y2 ≠ 0) := by
  intro h
  exact h (d := 3) (x1 := 1) (y1 := 5) (x2 := 2) (y2 := 3)
    zmod13_curve_1_5 zmod13_curve_2_3 neg_one_square_zmod13 zmod13_den_plus_zero
end CompletenessNegativeControl

/-- Edwards addition closes on the twisted-Edwards curve (explicit denominators). -/
lemma edAddClosure_aux {d x1 y1 x2 y2 : K}
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2)
    (hd1 : 1 + d * y1 ^ 2 ≠ 0) (hd2 : 1 + d * y2 ^ 2 ≠ 0)
    (hP : 1 + d * x1 * y1 * x2 * y2 ≠ 0)
    (hM : 1 - d * x1 * y1 * x2 * y2 ≠ 0) :
    edwardsEq d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 := by
  have hP' : 1 + x1 * y2 * y1 * x2 * d ≠ 0 := by ring_nf at hP ⊢; exact hP
  have hM' : 1 - x1 * y2 * y1 * x2 * d ≠ 0 := by ring_nf at hM ⊢; exact hM
  have hP2' : (1 + x1 * y2 * y1 * x2 * d) ^ 2 ≠ 0 := pow_ne_zero 2 hP'
  have hM2' : (1 - x1 * y2 * y1 * x2 * d) ^ 2 ≠ 0 := pow_ne_zero 2 hM'
  have hx1mul : (1 + d * y1 ^ 2) * x1 ^ 2 = y1 ^ 2 - 1 := by
    unfold edwardsEq at hE1
    linear_combination -hE1
  have hx2mul : (1 + d * y2 ^ 2) * x2 ^ 2 = y2 ^ 2 - 1 := by
    unfold edwardsEq at hE2
    linear_combination -hE2
  have hx1 : x1 ^ 2 = (y1 ^ 2 - 1) / (1 + d * y1 ^ 2) := by
    rw [eq_div_iff hd1]
    simpa [mul_comm] using hx1mul
  have hx2 : x2 ^ 2 = (y2 ^ 2 - 1) / (1 + d * y2 ^ 2) := by
    rw [eq_div_iff hd2]
    simpa [mul_comm] using hx2mul
  have hx1_3 : x1 ^ 3 = ((y1 ^ 2 - 1) / (1 + d * y1 ^ 2)) * x1 := by
    calc x1 ^ 3 = x1 ^ 2 * x1 := by ring
      _ = ((y1 ^ 2 - 1) / (1 + d * y1 ^ 2)) * x1 := by rw [hx1]
  have hx2_3 : x2 ^ 3 = ((y2 ^ 2 - 1) / (1 + d * y2 ^ 2)) * x2 := by
    calc x2 ^ 3 = x2 ^ 2 * x2 := by ring
      _ = ((y2 ^ 2 - 1) / (1 + d * y2 ^ 2)) * x2 := by rw [hx2]
  have hx1_4 : x1 ^ 4 = ((y1 ^ 2 - 1) / (1 + d * y1 ^ 2)) ^ 2 := by
    calc x1 ^ 4 = (x1 ^ 2) ^ 2 := by ring
      _ = ((y1 ^ 2 - 1) / (1 + d * y1 ^ 2)) ^ 2 := by rw [hx1]
  have hx2_4 : x2 ^ 4 = ((y2 ^ 2 - 1) / (1 + d * y2 ^ 2)) ^ 2 := by
    calc x2 ^ 4 = (x2 ^ 2) ^ 2 := by ring
      _ = ((y2 ^ 2 - 1) / (1 + d * y2 ^ 2)) ^ 2 := by rw [hx2]
  have hd12 : (1 + d * y1 ^ 2) * (1 + d * y2 ^ 2) ≠ 0 := mul_ne_zero hd1 hd2
  have hd12_2 : ((1 + d * y1 ^ 2) * (1 + d * y2 ^ 2)) ^ 2 ≠ 0 := pow_ne_zero 2 hd12
  have hd12_3 : ((1 + d * y1 ^ 2) * (1 + d * y2 ^ 2)) ^ 3 ≠ 0 := pow_ne_zero 3 hd12
  have hd12_4 : ((1 + d * y1 ^ 2) * (1 + d * y2 ^ 2)) ^ 4 ≠ 0 := pow_ne_zero 4 hd12
  have hd12c : 1 + y2 ^ 2 * y1 ^ 2 * d ^ 2 + y2 ^ 2 * d + y1 ^ 2 * d ≠ 0 := by
    ring_nf at hd12 ⊢
    exact hd12
  have hd12c2 : (1 + y2 ^ 2 * y1 ^ 2 * d ^ 2 + y2 ^ 2 * d + y1 ^ 2 * d) ^ 2 ≠ 0 :=
    pow_ne_zero 2 hd12c
  have hd12c3 : (1 + y2 ^ 2 * y1 ^ 2 * d ^ 2 + y2 ^ 2 * d + y1 ^ 2 * d) ^ 3 ≠ 0 :=
    pow_ne_zero 3 hd12c
  have hd12c4 : (1 + y2 ^ 2 * y1 ^ 2 * d ^ 2 + y2 ^ 2 * d + y1 ^ 2 * d) ^ 4 ≠ 0 :=
    pow_ne_zero 4 hd12c
  have hdz1 : 1 + y1 ^ 2 * d ≠ 0 := by ring_nf at hd1 ⊢; exact hd1
  have hdz2 : 1 + y2 ^ 2 * d ≠ 0 := by ring_nf at hd2 ⊢; exact hd2
  have hdz12 : (1 + y1 ^ 2 * d) * (1 + y2 ^ 2 * d) ≠ 0 := mul_ne_zero hdz1 hdz2
  unfold edAddField edwardsEq at *
  field_simp [hP, hM, hP', hM', hP2', hM2']
  ring_nf
  rw [hx1, hx2, hx1_3, hx2_3, hx1_4, hx2_4]
  ring_nf
  field_simp (disch := (
    ring_nf at hdz1 hdz2 hdz12 ⊢;
    first
    | exact hdz1 | exact hdz2 | exact hdz12
    | exact pow_ne_zero 2 hdz1 | exact pow_ne_zero 3 hdz1 | exact pow_ne_zero 4 hdz1
    | exact pow_ne_zero 2 hdz2 | exact pow_ne_zero 3 hdz2 | exact pow_ne_zero 4 hdz2
    | exact pow_ne_zero 2 hdz12 | exact pow_ne_zero 3 hdz12 | exact pow_ne_zero 4 hdz12))
  ring_nf

lemma x3_mul_vadd_aux {d u1 v1 u2 v2 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hu1 : u1 + 1 ≠ 0) (hu2 : u2 + 1 ≠ 0)
    (hq1 : montQ d u1 ≠ 0) (hq2 : montQ d u2 ≠ 0)
    (hu12 : u1 ≠ u2)
    (hD1 : 1 + d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hDenP : (u1 + 1) * montQ d u2 * montQ d u1 * (u2 + 1) +
      2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d ≠ 0)
    (hPnumHyp : 1 + 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d /
      (montQ d u1 * (u2 + 1) * (u1 + 1) * montQ d u2) ≠ 0) :
    (edAddField d
        (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
        (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).1 *
      (montAdd d u1 v1 u2 v2).2 +
      2 * (montAdd d u1 v1 u2 v2).1 = 0 := by
  have hv1 := montgomery_v_sq hM1 hd
  have hv2 := montgomery_v_sq hM2 hd
  have hsub : u1 - u2 ≠ 0 := sub_ne_zero.mpr hu12
  have hD1' := hD1
  field_simp [hu1, hu2, hq1, hq2] at hD1'
  ring_nf at hD1'
  have hPnum := hPnumHyp
  have hq1c := hq1; have hq2c := hq2
  have hu1c := hu1; have hu2c := hu2
  have hsubc := hsub; have hdc := hd; have hD1c := hD1'
  simp only [edAddField, montAdd, montA, montB]
  field_simp (disch := (
    ring_nf at hq1c hq2c hu1c hu2c hsubc hdc hD1c ⊢;
    first
    | exact hq1c | exact hq2c | exact hu1c | exact hu2c
    | exact hsubc | exact hdc | exact hD1c | exact hPnum
    | exact pow_ne_zero 2 hPnum | exact pow_ne_zero 3 hPnum
    | exact pow_ne_zero 2 hq1c | exact pow_ne_zero 2 hq2c
    | exact pow_ne_zero 2 hu1c | exact pow_ne_zero 2 hu2c
    | exact pow_ne_zero 2 hsubc | exact pow_ne_zero 2 hD1c
    | exact pow_ne_zero 3 hsubc | exact pow_ne_zero 3 hD1c
    | exact mul_ne_zero hq1c hq2c | exact mul_ne_zero hu1c hu2c
    | exact mul_ne_zero hsubc hdc | exact mul_ne_zero hq1c hsubc
    | exact mul_ne_zero hq2c hsubc | exact mul_ne_zero hD1c hsubc))
  field_simp [hDenP]
  ring_nf
  have hv1c : v1 ^ 3 = -(u1 * montQ d u1) * v1 := by
    calc v1 ^ 3 = v1 ^ 2 * v1 := by ring
      _ = -(u1 * montQ d u1) * v1 := by rw [hv1]
  have hv2c : v2 ^ 3 = -(u2 * montQ d u2) * v2 := by
    calc v2 ^ 3 = v2 ^ 2 * v2 := by ring
      _ = -(u2 * montQ d u2) * v2 := by rw [hv2]
  have hv1d : v1 ^ 4 = (u1 * montQ d u1) ^ 2 := by
    calc v1 ^ 4 = (v1 ^ 2) ^ 2 := by ring
      _ = (u1 * montQ d u1) ^ 2 := by rw [hv1]; ring
  have hv2d : v2 ^ 4 = (u2 * montQ d u2) ^ 2 := by
    calc v2 ^ 4 = (v2 ^ 2) ^ 2 := by ring
      _ = (u2 * montQ d u2) ^ 2 := by rw [hv2]; ring
  rw [hv1, hv2, hv1c, hv2c, hv1d, hv2d]
  unfold montQ
  ring

lemma edAddMont_v_mul_aux {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) :
    x * (edwardsToMont d x y).2 = -2 * (edwardsToMont d x y).1 := by
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  simp only [edwardsToMont]
  field_simp [hy]
  ring_nf
  linear_combination 2 * hcurve

lemma ed_dy_ne_zero_aux {d u : K}
    (hu : u + 1 ≠ 0) (hq : montQ d u ≠ 0) :
    1 + d * ((u - 1) / (u + 1)) ^ 2 ≠ 0 := by
  have hq' : (u + 1) ^ 2 + d * (u - 1) ^ 2 ≠ 0 := by
    rw [← montQ_completes_square]
    exact hq
  field_simp [hu]
  exact div_ne_zero hq' (pow_ne_zero 2 hu)

lemma edwards_of_montgomery_aux {d u v : K}
    (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0)
    (hu : u + 1 ≠ 0) (hq : montQ d u ≠ 0) :
    edwardsEq d (2 * v / montQ d u) ((u - 1) / (u + 1)) := by
  have hv := montgomery_v_sq hM hd
  unfold edwardsEq
  field_simp [hu, hq]
  ring_nf
  rw [hv]
  unfold montQ
  ring

lemma edAdd_mont_v {d u1 v1 u2 v2 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hu1 : u1 + 1 ≠ 0) (hu2 : u2 + 1 ≠ 0)
    (hq1 : montQ d u1 ≠ 0) (hq2 : montQ d u2 ≠ 0)
    (hu12 : u1 ≠ u2)
    (hD1 : 1 + d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hD2 : 1 - d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hy3 : 1 - (edAddField d
        (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
        (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2 ≠ 0)
    (hDenQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d ≠ 0)
    (hNumQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d -
              ((u1 - 1) * (u2 - 1) * montQ d u1 * montQ d u2 +
               (u1 + 1) * (u2 + 1) * (2 : K) ^ 2 * v1 * v2) ≠ 0)
    (hDenP : (u1 + 1) * montQ d u2 * montQ d u1 * (u2 + 1) +
      2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d ≠ 0)
    (hPnumHyp : 1 + 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d /
      (montQ d u1 * (u2 + 1) * (u1 + 1) * montQ d u2) ≠ 0) :
    (edwardsToMont d
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).1
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2).2 =
      (montAdd d u1 v1 u2 v2).2 := by
  let x1 := 2 * v1 / montQ d u1
  let y1 := (u1 - 1) / (u1 + 1)
  let x2 := 2 * v2 / montQ d u2
  let y2 := (u2 - 1) / (u2 + 1)
  let E := edAddField d x1 y1 x2 y2
  let mu := (montAdd d u1 v1 u2 v2).1
  let nu := (montAdd d u1 v1 u2 v2).2
  change (edwardsToMont d E.1 E.2).2 = nu
  have huEq : (edwardsToMont d E.1 E.2).1 = mu := by
    dsimp [E, x1, y1, x2, y2, mu]
    exact edAdd_mont_u hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12 hD1 hD2 hy3 hDenQ hNumQ
  have hxnu : E.1 * nu = -2 * mu := by
    dsimp [E, x1, y1, x2, y2, mu, nu]
    have h := x3_mul_vadd_aux hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12 hD1 hDenP hPnumHyp
    linear_combination h
  have hE1 : edwardsEq d x1 y1 := by
    dsimp [x1, y1]
    exact edwards_of_montgomery_aux hM1 hd hu1 hq1
  have hE2 : edwardsEq d x2 y2 := by
    dsimp [x2, y2]
    exact edwards_of_montgomery_aux hM2 hd hu2 hq2
  have hdY1 : 1 + d * y1 ^ 2 ≠ 0 := by
    dsimp [y1]
    exact ed_dy_ne_zero_aux hu1 hq1
  have hdY2 : 1 + d * y2 ^ 2 ≠ 0 := by
    dsimp [y2]
    exact ed_dy_ne_zero_aux hu2 hq2
  have hE12 : edwardsEq d E.1 E.2 := by
    dsimp [E]
    exact edAddClosure_aux hE1 hE2 hdY1 hdY2
      (by simpa [x1, y1, x2, y2, mul_assoc, mul_left_comm, mul_comm] using hD1)
      (by simpa [x1, y1, x2, y2, mul_assoc, mul_left_comm, mul_comm] using hD2)
  have hy3' : 1 - E.2 ≠ 0 := by
    simpa [E, x1, y1, x2, y2] using hy3
  have hxE : E.1 * (edwardsToMont d E.1 E.2).2 = -2 * (edwardsToMont d E.1 E.2).1 :=
    edAddMont_v_mul_aux hE12 hy3'
  by_cases hx3' : E.1 = 0
  · have hneg : (-2 : K) * mu = 0 := by
      rw [hx3'] at hxnu
      simpa using hxnu.symm
    have hmu : mu = 0 := (mul_eq_zero.mp hneg).resolve_left (neg_ne_zero.mpr h2)
    have hnu : nu = 0 := montAdd_v_eq_zero_of_u_eq_zero hM1 hM2 hd hu12 hmu
    rw [show (edwardsToMont d E.1 E.2).2 = 0 by simp [edwardsToMont, hx3'], hnu]
  · apply mul_left_cancel₀ hx3'
    rw [hxE, huEq]
    exact hxnu.symm

/-- Full map compatibility, now unconditional on any compatibility assumption. -/
theorem edAdd_toMont_eq_montAdd {u1 v1 u2 v2 : K}
    (hM1 : montgomeryEq d u1 v1) (hM2 : montgomeryEq d u2 v2)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hu1 : u1 + 1 ≠ 0) (hu2 : u2 + 1 ≠ 0)
    (hq1 : montQ d u1 ≠ 0) (hq2 : montQ d u2 ≠ 0)
    (hu12 : u1 ≠ u2)
    (hD1 : 1 + d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hD2 : 1 - d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
              ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0)
    (hy3 : 1 - (edAddField d
        (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
        (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2 ≠ 0)
    (hDenQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d ≠ 0)
    (hNumQ : (u1 + 1) * (u2 + 1) * montQ d u1 * montQ d u2 -
              (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d -
              ((u1 - 1) * (u2 - 1) * montQ d u1 * montQ d u2 +
               (u1 + 1) * (u2 + 1) * (2 : K) ^ 2 * v1 * v2) ≠ 0)
    (hDenP : (u1 + 1) * montQ d u2 * montQ d u1 * (u2 + 1) +
      2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d ≠ 0)
    (hPnumHyp : 1 + 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d /
      (montQ d u1 * (u2 + 1) * (u1 + 1) * montQ d u2) ≠ 0) :
    edwardsToMont d
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).1
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2 =
      montAdd d u1 v1 u2 v2 := by
  apply Prod.ext
  · exact edAdd_mont_u hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12 hD1 hD2 hy3 hDenQ hNumQ
  · exact edAdd_mont_v hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12 hD1 hD2 hy3
      hDenQ hNumQ hDenP hPnumHyp


/-- `(u+1)` of the image of an Edwards point is `2/(1-y)`, nonzero in characteristic != 2. -/
lemma edwardsToMont_u_add_one_ne_zero {d x y : K} (hy : 1 - y ≠ 0) (h2 : (2 : K) ≠ 0) :
    (edwardsToMont d x y).1 + 1 ≠ 0 := by
  rw [edwardsToMont_fst]
  have heq : (1 + y) / (1 - y) + 1 = 2 / (1 - y) := by
    field_simp [hy]
    ring
  rw [heq]
  exact div_ne_zero h2 hy

/-- `Q(u)` of the image is `4(1+d·y²)/(1-y)²`, nonzero on the admissible locus. -/
lemma montQ_edwardsToMont_ne_zero {d x y : K} (hE : edwardsEq d x y)
    (hy : 1 - y ≠ 0) (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) :
    montQ d (edwardsToMont d x y).1 ≠ 0 := by
  rw [edwardsToMont_fst]
  rw [montQ_of_edwards d y hy]
  apply div_ne_zero
  · apply mul_ne_zero
    · rw [show (4 : K) = 2 * 2 by norm_num]
      exact mul_ne_zero h2 h2
    · exact edwards_one_add_dy_ne_zero hE hy hd
  · exact pow_ne_zero 2 hy

/-- Addition compatibility stated directly in Edwards coordinates, derived from
    `edAdd_toMont_eq_montAdd` plus `edwards_denoms_ne_zero`. All four auxiliary
    Montgomery-side non-vanishing hypotheses of the field-level theorem are
    cleared here: they are exactly `1 ± d·x₁·x₂·y₁·y₂ ≠ 0` and `1 - y₃ ≠ 0`
    multiplied by the nonzero factor `Q₁·Q₂·(u₁+1)·(u₂+1)`. -/
lemma edwardsToMont_eq_montAdd_of_complete {d x1 y1 x2 y2 : K}
    (hi : IsSquare (-1 : K)) (hnd : ¬ IsSquare d) (h2 : (2 : K) ≠ 0)
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2)
    (hy1 : 1 - y1 ≠ 0) (hy2 : 1 - y2 ≠ 0)
    (hu12 : (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d x2 y2).1)
    (hy12 : 1 - (edAddField d x1 y1 x2 y2).2 ≠ 0) :
    edwardsToMont d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 =
      montAdd d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
               (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2 := by
  have hd : 1 + d ≠ 0 := by
    rcases hi with ⟨i, hi⟩
    intro h
    have hd_eq : d = -1 := by linear_combination h
    exact hnd ⟨i, by rw [hd_eq, hi]⟩
  have hD12 := edwards_denoms_ne_zero hE1 hE2 hi hnd
  have hD1 := hD12.1
  have hD2 := hD12.2
  let u1 := (edwardsToMont d x1 y1).1
  let v1 := (edwardsToMont d x1 y1).2
  let u2 := (edwardsToMont d x2 y2).1
  let v2 := (edwardsToMont d x2 y2).2
  let Q1 := montQ d u1
  let Q2 := montQ d u2
  have hM1 : montgomeryEq d u1 v1 := by
    change montgomeryEq d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
    exact edwardsToMont_montgomery hE1 hy1 hd
  have hM2 : montgomeryEq d u2 v2 := by
    change montgomeryEq d (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2
    exact edwardsToMont_montgomery hE2 hy2 hd
  have hu1 : u1 + 1 ≠ 0 := by
    change (edwardsToMont d x1 y1).1 + 1 ≠ 0
    exact edwardsToMont_u_add_one_ne_zero hy1 h2
  have hu2 : u2 + 1 ≠ 0 := by
    change (edwardsToMont d x2 y2).1 + 1 ≠ 0
    exact edwardsToMont_u_add_one_ne_zero hy2 h2
  have hq1 : Q1 ≠ 0 := by
    change montQ d (edwardsToMont d x1 y1).1 ≠ 0
    exact montQ_edwardsToMont_ne_zero hE1 hy1 hd h2
  have hq2 : Q2 ≠ 0 := by
    change montQ d (edwardsToMont d x2 y2).1 ≠ 0
    exact montQ_edwardsToMont_ne_zero hE2 hy2 hd h2
  have hx1' : 2 * v1 / Q1 = x1 := by
    change 2 * (edwardsToMont d x1 y1).2 / montQ d (edwardsToMont d x1 y1).1 = x1
    exact edwards_x_recover hy1 (edwards_one_add_dy_ne_zero hE1 hy1 hd) h2
  have hx2' : 2 * v2 / Q2 = x2 := by
    change 2 * (edwardsToMont d x2 y2).2 / montQ d (edwardsToMont d x2 y2).1 = x2
    exact edwards_x_recover hy2 (edwards_one_add_dy_ne_zero hE2 hy2 hd) h2
  have hy1' : (u1 - 1) / (u1 + 1) = y1 := by
    change ((edwardsToMont d x1 y1).1 - 1) / ((edwardsToMont d x1 y1).1 + 1) = y1
    exact edwards_y_recover hy1 h2
  have hy2' : (u2 - 1) / (u2 + 1) = y2 := by
    change ((edwardsToMont d x2 y2).1 - 1) / ((edwardsToMont d x2 y2).1 + 1) = y2
    exact edwards_y_recover hy2 h2
  have hD1' : 1 + d * (2 * v1 / Q1) * (2 * v2 / Q2) *
      ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0 := by
    simpa [hx1', hx2', hy1', hy2'] using hD1
  have hD2' : 1 - d * (2 * v1 / Q1) * (2 * v2 / Q2) *
      ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0 := by
    simpa [hx1', hx2', hy1', hy2'] using hD2
  have hy3' : 1 - (edAddField d (2 * v1 / Q1) ((u1 - 1) / (u1 + 1))
      (2 * v2 / Q2) ((u2 - 1) / (u2 + 1))).2 ≠ 0 := by
    simpa [hx1', hx2', hy1', hy2'] using hy12
  have hDfac : Q1 * Q2 * (u1 + 1) * (u2 + 1) ≠ 0 :=
    mul_ne_zero (mul_ne_zero (mul_ne_zero hq1 hq2) hu1) hu2
  have hDenP_eq : (u1 + 1) * Q2 * Q1 * (u2 + 1) +
      2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d =
      (1 + d * x1 * x2 * y1 * y2) * (Q1 * Q2 * (u1 + 1) * (u2 + 1)) := by
    rw [← hx1', ← hx2', ← hy1', ← hy2']
    field_simp [hu1, hu2, hq1, hq2]
  have hDenP : (u1 + 1) * Q2 * Q1 * (u2 + 1) +
      2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d ≠ 0 := by
    rw [hDenP_eq]
    exact mul_ne_zero hD1 hDfac
  have hfrac : 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d /
      (Q1 * (u2 + 1) * (u1 + 1) * Q2) = d * x1 * x2 * y1 * y2 := by
    rw [← hx1', ← hx2', ← hy1', ← hy2']
    field_simp [hu1, hu2, hq1, hq2]
  have hPnumHyp : 1 + 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * d /
      (Q1 * (u2 + 1) * (u1 + 1) * Q2) ≠ 0 := by
    rw [hfrac]
    exact hD1
  have hDenQ_eq : (u1 + 1) * (u2 + 1) * Q1 * Q2 -
      (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d =
      (1 - d * x1 * x2 * y1 * y2) * (Q1 * Q2 * (u1 + 1) * (u2 + 1)) := by
    rw [← hx1', ← hx2', ← hy1', ← hy2']
    field_simp [hu1, hu2, hq1, hq2]
  have hDenQ : (u1 + 1) * (u2 + 1) * Q1 * Q2 -
      (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d ≠ 0 := by
    rw [hDenQ_eq]
    exact mul_ne_zero hD2 hDfac
  have hNumQ_eq : (u1 + 1) * (u2 + 1) * Q1 * Q2 -
      (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d -
      ((u1 - 1) * (u2 - 1) * Q1 * Q2 + (u1 + 1) * (u2 + 1) * (2 : K) ^ 2 * v1 * v2) =
      (1 - (edAddField d x1 y1 x2 y2).2) * (1 - d * x1 * x2 * y1 * y2) *
        (Q1 * Q2 * (u1 + 1) * (u2 + 1)) := by
    rw [← hx1', ← hx2', ← hy1', ← hy2']
    unfold edAddField
    field_simp [hu1, hu2, hq1, hq2, hD2']
  have hNumQ : (u1 + 1) * (u2 + 1) * Q1 * Q2 -
      (u1 - 1) * (u2 - 1) * (2 : K) ^ 2 * v1 * v2 * d -
      ((u1 - 1) * (u2 - 1) * Q1 * Q2 + (u1 + 1) * (u2 + 1) * (2 : K) ^ 2 * v1 * v2) ≠ 0 := by
    rw [hNumQ_eq]
    exact mul_ne_zero (mul_ne_zero hy12 hD2) hDfac
  change edwardsToMont d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 =
    montAdd d u1 v1 u2 v2
  rw [← hx1', ← hx2', ← hy1', ← hy2']
  exact edAdd_toMont_eq_montAdd hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12
    hD1' hD2' hy3' hDenQ hNumQ hDenP hPnumHyp

/-- The residual needed to transport Mathlib's associativity back to the Edwards law:
    full addition compatibility stated directly in Edwards coordinates. It follows
    from the machine-checked `edAdd_mont_u` and `edAdd_mont_v`, together with closure
    and denominator completeness of the Edwards law; those are separate number-theoretic
    facts (twisted-Edwards completeness), so they are carried here as one explicit
    bundle rather than assumed globally. -/
structure EdwardsAddCompatForAssociativity (d : K) : Prop where
  compat : ∀ {x1 y1 x2 y2 : K},
    edwardsEq d x1 y1 → edwardsEq d x2 y2 →
    1 - y1 ≠ 0 → 1 - y2 ≠ 0 → 1 + d ≠ 0 → (2 : K) ≠ 0 →
    (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d x2 y2).1 →
    edwardsEq d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 →
    1 - (edAddField d x1 y1 x2 y2).2 ≠ 0 →
    edwardsToMont d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 =
      montAdd d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
               (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2

/-- The compatibility bundle is now **proved**, not assumed: completeness supplies
    every denominator the field-level compatibility theorem needs. -/
theorem edwardsAddCompat_of_complete {d : K} (hi : IsSquare (-1 : K)) (hnd : ¬ IsSquare d)
    (h2 : (2 : K) ≠ 0) : EdwardsAddCompatForAssociativity d := by
  refine ⟨?_⟩
  intro x1 y1 x2 y2 hE1 hE2 hy1 hy2 hd _hu2 hu12 hE12 hy12
  exact edwardsToMont_eq_montAdd_of_complete hi hnd h2 hE1 hE2 hy1 hy2 hu12 hy12

/-- Associativity of the Edwards field law, inherited from Mathlib's Weierstrass
    `AddCommGroup` conditional on the compatibility bundle above. All other
    ingredients (the Montgomery law, its associativity, and injectivity of the
    bridge on its admissible locus) are machine-checked unconditionally. -/
theorem edAddField_associative_of_compat (hA : EdwardsAddCompatForAssociativity d)
    {x1 y1 x2 y2 x3 y3 : K}
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2) (hE3 : edwardsEq d x3 y3)
    (hy1 : 1 - y1 ≠ 0) (hy2 : 1 - y2 ≠ 0) (hy3 : 1 - y3 ≠ 0)
    (hx1 : x1 ≠ 0) (hx2 : x2 ≠ 0) (hx3 : x3 ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hu12 : (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d x2 y2).1)
    (hu23 : (edwardsToMont d x2 y2).1 ≠ (edwardsToMont d x3 y3).1)
    (hu12_3 : (montAdd d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
        (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2).1 ≠
        (edwardsToMont d x3 y3).1)
    (hu1_23 : (edwardsToMont d x1 y1).1 ≠
        (montAdd d (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2
          (edwardsToMont d x3 y3).1 (edwardsToMont d x3 y3).2).1)
    (hE12 : edwardsEq d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2)
    (hE23 : edwardsEq d (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2)
    (hy12 : 1 - (edAddField d x1 y1 x2 y2).2 ≠ 0)
    (hy23 : 1 - (edAddField d x2 y2 x3 y3).2 ≠ 0)
    (hE12L : edwardsEq d
        (edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).1
        (edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).2)
    (hE1R : edwardsEq d
        (edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).1
        (edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).2)
    (hy12L : 1 - (edAddField d
        (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).2 ≠ 0)
    (hy1R : 1 - (edAddField d x1 y1
        (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).2 ≠ 0) :
    edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3 =
      edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2 := by
  let P12 := edAddField d x1 y1 x2 y2
  let P23 := edAddField d x2 y2 x3 y3
  let L := edAddField d P12.1 P12.2 x3 y3
  let R := edAddField d x1 y1 P23.1 P23.2
  let M1 := edwardsToMont d x1 y1
  let M2 := edwardsToMont d x2 y2
  let M3 := edwardsToMont d x3 y3
  let M12 := edwardsToMont d P12.1 P12.2
  let M23 := edwardsToMont d P23.1 P23.2
  have hM1 : montgomeryEq d M1.1 M1.2 := edwardsToMont_montgomery hE1 hy1 hd
  have hM2 : montgomeryEq d M2.1 M2.2 := edwardsToMont_montgomery hE2 hy2 hd
  have hM3 : montgomeryEq d M3.1 M3.2 := edwardsToMont_montgomery hE3 hy3 hd
  have hv1 : M1.2 ≠ 0 := by
    rw [show M1.2 = 2 * x1 * (1 + d * y1 ^ 2) / (1 - y1) ^ 2 by rfl]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx1)
      (edwards_one_add_dy_ne_zero hE1 hy1 hd)) (pow_ne_zero 2 hy1)
  have hv2 : M2.2 ≠ 0 := by
    rw [show M2.2 = 2 * x2 * (1 + d * y2 ^ 2) / (1 - y2) ^ 2 by rfl]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx2)
      (edwards_one_add_dy_ne_zero hE2 hy2 hd)) (pow_ne_zero 2 hy2)
  have hv3 : M3.2 ≠ 0 := by
    rw [show M3.2 = 2 * x3 * (1 + d * y3 ^ 2) / (1 - y3) ^ 2 by rfl]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx3)
      (edwards_one_add_dy_ne_zero hE3 hy3 hd)) (pow_ne_zero 2 hy3)
  have hassoc := montAdd_associative_of_weierstrass hM1 hM2 hM3 hd h2
      hv1 hv2 hv3 hu12 hu23 hu12_3 hu1_23
  have hcomp12 : M12 = montAdd d M1.1 M1.2 M2.1 M2.2 := by
    dsimp [M12, P12, M1, M2]
    exact hA.compat hE1 hE2 hy1 hy2 hd h2 hu12 hE12 hy12
  have hcomp23 : M23 = montAdd d M2.1 M2.2 M3.1 M3.2 := by
    dsimp [M23, P23, M2, M3]
    exact hA.compat hE2 hE3 hy2 hy3 hd h2 hu23 hE23 hy23
  have hcomp12' := hcomp12
  dsimp [M12, P12, M1, M2] at hcomp12'
  have hu12L : (edwardsToMont d P12.1 P12.2).1 ≠ (edwardsToMont d x3 y3).1 := by
    rw [hcomp12']
    exact hu12_3
  have hcomp23' := hcomp23
  dsimp [M23, P23, M2, M3] at hcomp23'
  have hu1R : (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d P23.1 P23.2).1 := by
    rw [hcomp23']
    exact hu1_23
  have hcompL : edwardsToMont d L.1 L.2 = montAdd d M12.1 M12.2 M3.1 M3.2 := by
    dsimp [L, M12, M3, P12]
    exact hA.compat hE12 hE3 hy12 hy3 hd h2 hu12L hE12L hy12L
  have hcompR : edwardsToMont d R.1 R.2 = montAdd d M1.1 M1.2 M23.1 M23.2 := by
    dsimp [R, M23, M1, P23]
    exact hA.compat hE1 hE23 hy1 hy23 hd h2 hu1R hE1R hy1R
  have hmap : edwardsToMont d L.1 L.2 = edwardsToMont d R.1 R.2 := by
    rw [hcompL, hcompR, hcomp12, hcomp23]
    exact hassoc
  have hbackL' := edwardsToMont_roundtrip hE12L hy12L hd h2
  have hbackR' := edwardsToMont_roundtrip hE1R hy1R hd h2
  have hbackL : montgomeryToEdwards d (edwardsToMont d L.1 L.2).1
      (edwardsToMont d L.1 L.2).2 = L := by
    dsimp [L]
    exact hbackL'
  have hbackR : montgomeryToEdwards d (edwardsToMont d R.1 R.2).1
      (edwardsToMont d R.1 R.2).2 = R := by
    dsimp [R]
    exact hbackR'
  change L = R
  exact hbackL.symm.trans ((congrArg (fun p : K × K => montgomeryToEdwards d p.1 p.2) hmap).trans hbackR)

/-- Associativity of the Edwards field law under twisted-Edwards completeness.
    Compared with `edAddField_associative_of_compat`, the compatibility bundle,
    `1 + d ≠ 0`, and the four on-curve hypotheses for the intermediate sums are
    **derived** rather than assumed; only the curve equations, completeness,
    `2 ≠ 0`, the `y ≠ 1` / `x ≠ 0` admissibility conditions, the three pairwise
    distinctness conditions, and the four `y ≠ 1` conditions on the intermediate
    sums remain explicit. The latter are genuine exceptional cases (a sum may be
    the affine identity), handled by the branch in the concrete `affineAdd`. -/
theorem edAddField_associative_of_complete {d : K} (hi : IsSquare (-1 : K))
    (hnd : ¬ IsSquare d) (h2 : (2 : K) ≠ 0)
    {x1 y1 x2 y2 x3 y3 : K}
    (hE1 : edwardsEq d x1 y1) (hE2 : edwardsEq d x2 y2) (hE3 : edwardsEq d x3 y3)
    (hy1 : 1 - y1 ≠ 0) (hy2 : 1 - y2 ≠ 0) (hy3 : 1 - y3 ≠ 0)
    (hx1 : x1 ≠ 0) (hx2 : x2 ≠ 0) (hx3 : x3 ≠ 0)
    (hu12 : (edwardsToMont d x1 y1).1 ≠ (edwardsToMont d x2 y2).1)
    (hu23 : (edwardsToMont d x2 y2).1 ≠ (edwardsToMont d x3 y3).1)
    (hu12_3 : (montAdd d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
        (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2).1 ≠
        (edwardsToMont d x3 y3).1)
    (hu1_23 : (edwardsToMont d x1 y1).1 ≠
        (montAdd d (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2
          (edwardsToMont d x3 y3).1 (edwardsToMont d x3 y3).2).1)
    (hy12 : 1 - (edAddField d x1 y1 x2 y2).2 ≠ 0)
    (hy23 : 1 - (edAddField d x2 y2 x3 y3).2 ≠ 0)
    (hy12L : 1 - (edAddField d
        (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).2 ≠ 0)
    (hy1R : 1 - (edAddField d x1 y1
        (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).2 ≠ 0) :
    edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3 =
      edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2 := by
  have hd : 1 + d ≠ 0 := by
    rcases hi with ⟨i, hi⟩
    intro h
    have hd_eq : d = -1 := by linear_combination h
    exact hnd ⟨i, by rw [hd_eq, hi]⟩
  have hDy1 := edwards_one_add_dy_ne_zero hE1 hy1 hd
  have hDy2 := edwards_one_add_dy_ne_zero hE2 hy2 hd
  have hDy3 := edwards_one_add_dy_ne_zero hE3 hy3 hd
  have hD12 := edwards_denoms_ne_zero hE1 hE2 hi hnd
  have hD23 := edwards_denoms_ne_zero hE2 hE3 hi hnd
  have hD12p : 1 + d * x1 * y1 * x2 * y2 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12.1
  have hD12m : 1 - d * x1 * y1 * x2 * y2 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12.2
  have hD23p : 1 + d * x2 * y2 * x3 * y3 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD23.1
  have hD23m : 1 - d * x2 * y2 * x3 * y3 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD23.2
  have hE12 : edwardsEq d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 :=
    edAddClosure_aux hE1 hE2 hDy1 hDy2 hD12p hD12m
  have hE23 : edwardsEq d (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2 :=
    edAddClosure_aux hE2 hE3 hDy2 hDy3 hD23p hD23m
  have hDy12 := edwards_one_add_dy_ne_zero hE12 hy12 hd
  have hDy23 := edwards_one_add_dy_ne_zero hE23 hy23 hd
  have hD12L := edwards_denoms_ne_zero hE12 hE3 hi hnd
  have hD1R := edwards_denoms_ne_zero hE1 hE23 hi hnd
  have hD12Lp : 1 + d * (edAddField d x1 y1 x2 y2).1 * (edAddField d x1 y1 x2 y2).2 * x3 * y3 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12L.1
  have hD12Lm : 1 - d * (edAddField d x1 y1 x2 y2).1 * (edAddField d x1 y1 x2 y2).2 * x3 * y3 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12L.2
  have hD1Rp : 1 + d * x1 * y1 * (edAddField d x2 y2 x3 y3).1 * (edAddField d x2 y2 x3 y3).2 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD1R.1
  have hD1Rm : 1 - d * x1 * y1 * (edAddField d x2 y2 x3 y3).1 * (edAddField d x2 y2 x3 y3).2 ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD1R.2
  have hE12L : edwardsEq d
      (edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).1
      (edAddField d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 x3 y3).2 :=
    edAddClosure_aux hE12 hE3 hDy12 hDy3 hD12Lp hD12Lm
  have hE1R : edwardsEq d
      (edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).1
      (edAddField d x1 y1 (edAddField d x2 y2 x3 y3).1 (edAddField d x2 y2 x3 y3).2).2 :=
    edAddClosure_aux hE1 hE23 hDy1 hDy23 hD1Rp hD1Rm
  exact edAddField_associative_of_compat (edwardsAddCompat_of_complete hi hnd h2)
    hE1 hE2 hE3 hy1 hy2 hy3 hx1 hx2 hx3 hd h2 hu12 hu23 hu12_3 hu1_23
    hE12 hE23 hy12 hy23 hE12L hE1R hy12L hy1R


/-! ## Negative control: `hu12 : u₁ ≠ u₂` is load-bearing for the secant map

`montAdd` clears the slope `l = (v₁ - v₂) / (u₁ - u₂)`. On the diagonal `u₁ = u₂`
its denominator is zero, so Lean's total division makes `l = 0` regardless of the
points: the "secant" is neither the tangent nor the negation case that the group
law needs. We formalise the mechanism over an arbitrary field, then exhibit a
concrete `F_11` witness at `d = 2` where every hypothesis of
`edAdd_toMont_eq_montAdd` except `hu12` holds at `(u₁,v₁) = (u₂,v₂) = (3,4)`, yet
`montAdd` lands off the curve and the compatibility conclusion is false. This
makes `hu12` an isolated, load-bearing hypothesis rather than a proof artifact. -/

/-! The mechanism: on the diagonal `u₁ = u₂` the slope is `0 / 0 = 0`, so
    `montAdd d u v u v` collapses to `(-montA d - 2·u, -v)`, independently of any
    curve equation. Without `hu12` the secant has no slope at all. -/
omit [DecidableEq K] in
lemma montAdd_self_eq_degenerate (d u v : K) :
    montAdd d u v u v = (-montA d - 2 * u, -v) := by
  apply Prod.ext
  · simp [montAdd]
    ring
  · simp [montAdd]

section SecantMapNegativeControl

local instance : Fact (Nat.Prime 11) := ⟨by norm_num⟩

/-- At `d = 2` over `F_11`, the on-curve point `(3,4)` self-added by the degenerate
    secant law lands at `(2,7)`, which is OFF `M_{A,B}`. A group-law sum of on-curve
    points must be on the curve, so `montAdd` is not a group law on the equal-`u`
    diagonal. -/
lemma secant_map_degenerate_off_curve_zmod11 :
    montgomeryEq (2 : ZMod 11) 3 4 ∧
    montAdd (2 : ZMod 11) 3 4 3 4 = (2, 7) ∧
    ¬ montgomeryEq (2 : ZMod 11) 2 7 := by
  refine ⟨?_, ?_, ?_⟩
  · unfold montgomeryEq montA montB
    decide
  · decide
  · unfold montgomeryEq montA montB
    decide

/-- Direct refutation of the compatibility conclusion with `u₁ = u₂`: the Edwards
    image `(3,4) ↦ (4,6)` doubles to a point mapping back to `(8,8)`, but
    `montAdd (2) 3 4 3 4 = (2,7)`. -/
lemma secant_map_compatibility_fails_zmod11 :
    edwardsToMont (2 : ZMod 11)
      (edAddField (2 : ZMod 11) 4 6 4 6).1
      (edAddField (2 : ZMod 11) 4 6 4 6).2 ≠
    montAdd (2 : ZMod 11) 3 4 3 4 := by
  decide

/-- **Headline negative control.** Over `F_11` at `d = 2`, with
    `(u₁,v₁) = (u₂,v₂) = (3,4)`, every hypothesis of `edAdd_toMont_eq_montAdd`
    other than `hu12` is satisfied (both points on-curve, `1 + d ≠ 0`, `2 ≠ 0`,
    `uᵢ + 1 ≠ 0`, `montQ 2 uᵢ ≠ 0`, and all six denominator non-vanishing
    hypotheses), while `u₁ = u₂` -- so `hu12` is the *only* failed hypothesis --
    yet the conclusion `edwardsToMont (edAddField E E) = montAdd P P` is FALSE.
    Hence `hu12` is load-bearing and cannot be dropped. -/
theorem montAdd_hu12_load_bearing_zmod11 :
    let u1 : ZMod 11 := 3
    let v1 : ZMod 11 := 4
    let u2 : ZMod 11 := 3
    let v2 : ZMod 11 := 4
    montgomeryEq 2 u1 v1 ∧ montgomeryEq 2 u2 v2 ∧
    (1 + (2 : ZMod 11) ≠ 0) ∧ ((2 : ZMod 11) ≠ 0) ∧
    (u1 + 1 ≠ 0) ∧ (u2 + 1 ≠ 0) ∧
    montQ 2 u1 ≠ 0 ∧ montQ 2 u2 ≠ 0 ∧
    (1 + 2 * (2 * v1 / montQ 2 u1) * (2 * v2 / montQ 2 u2) *
          ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0) ∧
    (1 - 2 * (2 * v1 / montQ 2 u1) * (2 * v2 / montQ 2 u2) *
          ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0) ∧
    (1 - (edAddField 2 (2 * v1 / montQ 2 u1) ((u1 - 1) / (u1 + 1))
                        (2 * v2 / montQ 2 u2) ((u2 - 1) / (u2 + 1))).2 ≠ 0) ∧
    ((u1 + 1) * (u2 + 1) * montQ 2 u1 * montQ 2 u2 -
          (u1 - 1) * (u2 - 1) * (2 : ZMod 11) ^ 2 * v1 * v2 * 2 ≠ 0) ∧
    ((u1 + 1) * (u2 + 1) * montQ 2 u1 * montQ 2 u2 -
          (u1 - 1) * (u2 - 1) * (2 : ZMod 11) ^ 2 * v1 * v2 * 2 -
          ((u1 - 1) * (u2 - 1) * montQ 2 u1 * montQ 2 u2 +
           (u1 + 1) * (u2 + 1) * (2 : ZMod 11) ^ 2 * v1 * v2) ≠ 0) ∧
    ((u1 + 1) * montQ 2 u2 * montQ 2 u1 * (u2 + 1) +
          2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * 2 ≠ 0) ∧
    (1 + 2 ^ 2 * v1 * (u2 - 1) * (u1 - 1) * v2 * 2 /
          (montQ 2 u1 * (u2 + 1) * (u1 + 1) * montQ 2 u2) ≠ 0) ∧
    u1 = u2 ∧
    ¬ (edwardsToMont 2
          (edAddField 2 (2 * v1 / montQ 2 u1) ((u1 - 1) / (u1 + 1))
                        (2 * v2 / montQ 2 u2) ((u2 - 1) / (u2 + 1))).1
          (edAddField 2 (2 * v1 / montQ 2 u1) ((u1 - 1) / (u1 + 1))
                        (2 * v2 / montQ 2 u2) ((u2 - 1) / (u2 + 1))).2 =
        montAdd 2 u1 v1 u2 v2) := by
  unfold montgomeryEq montA montB montQ edAddField edwardsToMont montAdd
  decide

/-- The review's simpler concrete target: with `d = 1` the self-`montAdd` of the
    2-torsion point `(0,0)` is `(0,0)`, contrasting with the non-degenerate
    (`u₁ ≠ u₂`) compatibility proved above. -/
lemma secant_map_self_add_zero_zmod11 :
    montAdd (1 : ZMod 11) 0 0 0 0 = (0, 0) := by
  rw [montAdd_self_eq_degenerate]
  decide

end SecantMapNegativeControl


/-! ## Tangent / doubling law: the correct replacement for the degenerate secant

On the diagonal `u₁ = u₂` the secant slope of `montAdd` is `0 / 0 = 0` (see
`montAdd_self_eq_degenerate`). The group-law double replaces it with the *tangent*
slope, which is forced by the Montgomery equation: implicitly differentiating
`B·v² = u³ + A·u² + u` gives `2·B·v·v' = 3u² + 2A·u + 1`. Everything below is
over an arbitrary field; only `1 + d ≠ 0`, `2 ≠ 0` and `v ≠ 0` are assumed.
The last of these already forces `Q(u) ≠ 0` on the curve (`montQ_ne_zero_of_montgomery`),
so the doubling law needs no separate nondegeneracy hypothesis on `Q`. -/

/-- The tangent slope of `M_{A,B}` at `(u,v)`, obtained from `montgomeryEq d u v`
    by implicit differentiation of `B·v² = u³ + A·u² + u`. -/
def montTangentSlope (d u v : K) : K :=
  (3 * u ^ 2 + 2 * montA d * u + 1) / (2 * montB d * v)

/-- The implicit-differentiation identity characterising `montTangentSlope`:
    `2·B·v·l = 3u² + 2A·u + 1`, the derivative of the defining equation. -/
lemma montTangentSlope_spec {d u v : K} (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hv : v ≠ 0) :
    2 * montB d * v * montTangentSlope d u v = 3 * u ^ 2 + 2 * montA d * u + 1 := by
  unfold montTangentSlope
  have hB : montB d ≠ 0 := montB_ne_zero hd
  field_simp [hB, hv, h2]

omit [DecidableEq K] in
/-- The same slope in the `Q`-normalised form obtained from `montgomeryEq d u v`
    and `montgomery_v_sq`: `l = -(Q(u) + u·Q'(u)) / (2v)`. -/
lemma montTangentSlope_q_form {d u v : K}
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    montTangentSlope d u v =
      -(montQ d u + u * (2 * (1 + d) * u + 2 * (1 - d))) / (2 * v) := by
  unfold montTangentSlope montA montB montQ
  have hB : -(1 : K) / (1 + d) ≠ 0 := div_ne_zero (by norm_num) hd
  field_simp [hB, hv, hd, h2]
  ring

/-- On the curve, `v ≠ 0` already forces the nondegeneracy `Q(u) ≠ 0`. -/
lemma montQ_ne_zero_of_montgomery {d u v : K}
    (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0) (hv : v ≠ 0) :
    montQ d u ≠ 0 := by
  have hv2 := montgomery_v_sq hM hd
  intro hq
  have hz : v * v = 0 := by
    simpa [pow_two, hq] using hv2
  rcases mul_eq_zero.mp hz with h | h <;> exact hv h

/-- The tangent/doubling point: `montAdd`'s coordinate update with the tangent
    slope in place of the degenerate secant slope. -/
def montDouble (d u v : K) : K × K :=
  let l := montTangentSlope d u v
  let mu := montB d * l ^ 2 - montA d - 2 * u
  (mu, l * (u - mu) - v)

omit [DecidableEq K] in
/-- The doubled point's v-coordinate is the tangent formula `l·(u - u₂) - v`
    with `l = montTangentSlope d u v`. -/
lemma montDouble_v_eq (d u v : K) :
    (montDouble d u v).2 =
      montTangentSlope d u v * (u - (montDouble d u v).1) - v := by
  rfl

/-- Closure (the main algebraic obligation): the tangent double of an on-curve
    point with `v ≠ 0` stays on the same Montgomery curve. The single
    `linear_combination` certificate consumes `montgomeryEq d u v`. -/
lemma montDouble_montgomery {d u v : K}
    (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    montgomeryEq d (montDouble d u v).1 (montDouble d u v).2 := by
  unfold montDouble montTangentSlope
  unfold montgomeryEq at hM ⊢
  have hB : montB d ≠ 0 := montB_ne_zero hd
  field_simp [hB, hv, h2] at hM ⊢
  ring_nf at hM ⊢
  linear_combination (64 * (montB d)^3 * v^6) * hM

/-- **Headline tangent law.** For `u₁ = u₂ = u`, `v₁ = v₂ = v` on `M_{A,B}`, the
    doubled point's v-coordinate is the tangent formula and the doubled point
    stays on the curve. No distinctness hypothesis is needed; `v ≠ 0` already
    gives `Q(u) ≠ 0`. -/
theorem montgomery_tangent_double_v {d u v : K}
    (hM : montgomeryEq d u v) (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    montgomeryEq d (montDouble d u v).1 (montDouble d u v).2 ∧
    (montDouble d u v).2 =
      (3 * u ^ 2 + 2 * montA d * u + 1) / (2 * montB d * v) *
        (u - (montB d * ((3 * u ^ 2 + 2 * montA d * u + 1) / (2 * montB d * v)) ^ 2
              - montA d - 2 * u)) - v := by
  exact ⟨montDouble_montgomery hM hd h2 hv, rfl⟩

/-! Positive control: over `F_11` at `d = 2`, the tangent double of the on-curve
    point `(3,4)` is `(8,8)`, exactly the Edwards double of its image `(4,6)`
    mapped back to Montgomery, and it differs from the degenerate secant `(2,7)`. -/
section TangentMapPositiveControl

local instance : Fact (Nat.Prime 11) := ⟨by norm_num⟩

lemma montDouble_zmod11 : montDouble (2 : ZMod 11) 3 4 = (8, 8) := by
  decide

/-- Concrete agreement with Edwards doubling: `montDouble 2 (3,4)` equals the
    Montgomery image of `edAddField 2 (4,6) (4,6)`. The general field-level
    version remains an explicit residual (see the module scope notes). -/
lemma montDouble_matches_edAddField_zmod11 :
    montDouble (2 : ZMod 11) 3 4 =
      edwardsToMont (2 : ZMod 11)
        (edAddField (2 : ZMod 11) 4 6 4 6).1
        (edAddField (2 : ZMod 11) 4 6 4 6).2 := by
  decide

/-- The tangent double is not the degenerate secant result. -/
lemma montDouble_ne_degenerate_zmod11 :
    montDouble (2 : ZMod 11) 3 4 ≠ montAdd (2 : ZMod 11) 3 4 3 4 := by
  decide

end TangentMapPositiveControl

/-! ## General Edwards-to-Montgomery doubling compatibility

The secant compatibility `edAdd_toMont_eq_montAdd` needs `u₁ ≠ u₂` and cannot be
specialised to the diagonal. Here the doubling case is proved directly over an
arbitrary field. The nested rational identity is factored, as in the secant
proof's `edAdd_mont_v`, into small closed-form lemmas:

* `hyp1_aux`, `hy_sq_ne_aux`: `1 + y ≠ 0` and `1 - y² ≠ 0` from the curve
  equation, `x ≠ 0` and `1 + d ≠ 0`;
* `dbl_ed_u_formula`, `dbl_mont_u_formula`: closed forms for the two
  u-coordinates (`y²(1 - d·x²)/(1 - y²)` and
  `y²(1 + d)/((1 - y²)·(1 + d·y²))`), whose equality follows from the curve
  equation;
* `dbl_tangent_slope_formula`, `dbl_x_mul_v_aux`: the tangent slope in terms of
  `x, y`, and the doubling analogue of `x₃·v_add = -2·u_add`;
* `dbl_y_ne_one`: the second unified-law denominator is nonzero on this locus.

`edwardsToMont_eq_montDouble` then cancels the Edwards double's x-coordinate,
with the `x₃ = 0` branch discharged by on-curve closure of `montDouble`. The only
residual hypotheses are the two unified-law denominators `1 ± d·x²·y² ≠ 0`
(plus the standing admissibility conditions); completeness would discharge them.
-/

omit [DecidableEq K] in
lemma hyp1_aux {d x y : K} (hE : edwardsEq d x y) (hx : x ≠ 0) (hd : 1 + d ≠ 0) :
    1 + y ≠ 0 := by
  intro h
  have hy_eq : y = -1 := by linear_combination h
  have hc := hE
  unfold edwardsEq at hc
  rw [hy_eq] at hc
  ring_nf at hc
  have hfac : x ^ 2 * (1 + d) = 0 := by linear_combination -hc
  have hxc : x ^ 2 = 0 := (mul_eq_zero.mp hfac).resolve_right hd
  have hx0 : x = 0 := by
    have h' : x * x = 0 := by simpa [pow_two] using hxc
    rcases mul_eq_zero.mp h' with h' | h' <;> exact h'
  exact hx hx0

omit [DecidableEq K] in
lemma hy_sq_ne_aux {y : K} (hy : 1 - y ≠ 0) (hyp1 : 1 + y ≠ 0) : 1 - y ^ 2 ≠ 0 := by
  rw [show 1 - y ^ 2 = (1 - y) * (1 + y) by ring]
  exact mul_ne_zero hy hyp1


omit [DecidableEq K] in
lemma dbl_ed_u_formula {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hDm : 1 - d * x * y * x * y ≠ 0)
    (hy3 : 1 - (edAddField d x y x y).2 ≠ 0) :
    (edwardsToMont d (edAddField d x y x y).1 (edAddField d x y x y).2).1 =
      y ^ 2 * (1 - d * x ^ 2) / (1 - y ^ 2) := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hy2 : 1 - y ^ 2 ≠ 0 := hy_sq_ne_aux hy hyp1
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
  have hDmn : 1 - y ^ 2 * x ^ 2 * d ≠ 0 := by ring_nf at hDm ⊢; exact hDm
  have hy3' : 1 - y ^ 2 * (1 - y ^ 2 * x ^ 2 * d)⁻¹ - x ^ 2 * (1 - y ^ 2 * x ^ 2 * d)⁻¹ ≠ 0 := by
    have h := hy3
    unfold edAddField at h
    dsimp at h
    ring_nf at h ⊢
    exact h
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
    rw [eq_div_iff hdy]
    simpa [mul_comm] using hcurve
  have hx4 : x ^ 4 = ((y ^ 2 - 1) / (1 + d * y ^ 2)) ^ 2 := by
    calc x ^ 4 = (x ^ 2) ^ 2 := by ring
      _ = ((y ^ 2 - 1) / (1 + d * y ^ 2)) ^ 2 := by rw [hx2]
  unfold edAddField edwardsToMont
  dsimp
  field_simp [hDmn, hDm, hy3', hy, hyp1, hy2]
  ring_nf
  have hy3'' : 1 - y ^ 2 - y ^ 2 * ((y ^ 2 - 1) / (1 + d * y ^ 2)) * d -
      (y ^ 2 - 1) / (1 + d * y ^ 2) ≠ 0 := by
    have heq : 1 - y ^ 2 - y ^ 2 * ((y ^ 2 - 1) / (1 + d * y ^ 2)) * d -
        (y ^ 2 - 1) / (1 + d * y ^ 2) = 2 * (1 - y ^ 2) := by
      field_simp [hdy, hdy']
      ring
    rw [heq]
    exact mul_ne_zero h2 hy2
  have hden2 : 2 - y ^ 2 * 2 + y ^ 2 * d * 2 - y ^ 4 * d * 2 ≠ 0 := by
    have heq : 2 - y ^ 2 * 2 + y ^ 2 * d * 2 - y ^ 4 * d * 2 =
        2 * (1 - y ^ 2) * (1 + y ^ 2 * d) := by ring
    rw [heq]
    exact mul_ne_zero (mul_ne_zero h2 hy2) hdy'
  have hden2c : -2 * y ^ 4 * d + 2 * d * y ^ 2 - 2 * y ^ 2 + 2 ≠ 0 := by
    ring_nf at hden2 ⊢
    exact hden2
  rw [hx2]
  have hden2d : (1 + y ^ 2 * d) * (1 - y ^ 2) - y ^ 2 * (y ^ 2 - 1) * d -
      (y ^ 2 - 1) ≠ 0 := by
    have heq : (1 + y ^ 2 * d) * (1 - y ^ 2) - y ^ 2 * (y ^ 2 - 1) * d -
        (y ^ 2 - 1) = 2 * (1 - y ^ 2) * (1 + y ^ 2 * d) := by ring
    rw [heq]
    exact mul_ne_zero (mul_ne_zero h2 hy2) hdy'
  field_simp [hdy, hdy', hDmn, hy3', hy3'', hden2, hden2c, hden2d]
  ring

omit [DecidableEq K] in
lemma dbl_mont_u_formula {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hdy : 1 + d * y ^ 2 ≠ 0) :
    (montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2).1 =
      y ^ 2 * (1 + d) / ((1 - y ^ 2) * (1 + d * y ^ 2)) := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hy2 : 1 - y ^ 2 ≠ 0 := hy_sq_ne_aux hy hyp1
  have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
  have hcomp : (1 - y ^ 2) * (1 + d * y ^ 2) ≠ 0 := mul_ne_zero hy2 hdy
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
    rw [eq_div_iff hdy]
    simpa [mul_comm] using hcurve
  unfold montDouble montTangentSlope edwardsToMont montA montB
  dsimp
  field_simp [hy, hyp1, hy2, hx, hdy, hd, h2, hcomp]
  ring_nf
  rw [hx2]
  field_simp [hdy, hdy']
  ring

omit [DecidableEq K] in
lemma dbl_tangent_slope_formula {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) :
    montTangentSlope d (edwardsToMont d x y).1 (edwardsToMont d x y).2 =
      -(2 + (1 + d) * y + 2 * d * y ^ 2) / (x * (1 + d * y ^ 2)) := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
  unfold montTangentSlope edwardsToMont montA montB
  dsimp
  field_simp [hy, hyp1, hx, hdy, hdy', hd, h2]
  ring

omit [DecidableEq K] in
lemma dbl_x_mul_v_aux {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hDp : 1 + d * x * y * x * y ≠ 0)
    (hDm : 1 - d * x * y * x * y ≠ 0) :
    (edAddField d x y x y).1 *
        (montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2).2 +
      2 * (montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2).1 = 0 := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hy2 : 1 - y ^ 2 ≠ 0 := hy_sq_ne_aux hy hyp1
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
  have hDpn : 1 + y ^ 2 * x ^ 2 * d ≠ 0 := by ring_nf at hDp ⊢; exact hDp
  have hDmn : 1 - y ^ 2 * x ^ 2 * d ≠ 0 := by ring_nf at hDm ⊢; exact hDm
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
    rw [eq_div_iff hdy]
    simpa [mul_comm] using hcurve
  have hDpn2 : 1 + x ^ 2 * y ^ 2 * d ≠ 0 := by ring_nf at hDp ⊢; exact hDp
  have hDp4 : 1 + y ^ 4 * d ≠ 0 := by
    have heq : 1 + y ^ 4 * d = (1 + x ^ 2 * y ^ 2 * d) * (1 + d * y ^ 2) := by
      rw [hx2]
      field_simp [hdy, hdy']
      ring
    rw [heq]
    exact mul_ne_zero hDpn2 hdy
  have hmu := dbl_mont_u_formula hE hy hx hd h2 hdy
  have hl := dbl_tangent_slope_formula hE hy hx hd h2
  rw [montDouble_v_eq, hmu, hl]
  unfold edAddField edwardsToMont
  dsimp
  field_simp [hy, hyp1, hy2, hx, hdy, hdy', hd, h2, hDp, hDpn, hDmn]
  ring_nf
  rw [hx2]
  field_simp [hdy, hdy', hDp, hDpn, hDpn2, hDmn, hDp4]
  ring



omit [DecidableEq K] in
lemma dbl_y_ne_one {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hDm : 1 - d * x * y * x * y ≠ 0) :
    1 - (edAddField d x y x y).2 ≠ 0 := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hy2 : 1 - y ^ 2 ≠ 0 := hy_sq_ne_aux hy hyp1
  have hDmn : 1 - y ^ 2 * x ^ 2 * d ≠ 0 := by ring_nf at hDm ⊢; exact hDm
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  have heq : 1 - (edAddField d x y x y).2 =
      (2 * (1 - y ^ 2)) / (1 - d * x * y * x * y) := by
    have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
    have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
    have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
      rw [eq_div_iff hdy]
      simpa [mul_comm] using hcurve
    unfold edAddField
    dsimp
    field_simp [hDm, hDmn]
    rw [hx2]
    field_simp [hdy, hdy']
    ring
  rw [heq]
  exact div_ne_zero (mul_ne_zero h2 hy2) hDm

omit [DecidableEq K] in
lemma dbl_u_compat {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hDm : 1 - d * x * y * x * y ≠ 0) :
    (edwardsToMont d (edAddField d x y x y).1 (edAddField d x y x y).2).1 =
      (montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2).1 := by
  have hyp1 : 1 + y ≠ 0 := hyp1_aux hE hx hd
  have hy2 : 1 - y ^ 2 ≠ 0 := hy_sq_ne_aux hy hyp1
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  have hdy' : 1 + y ^ 2 * d ≠ 0 := by ring_nf at hdy ⊢; exact hdy
  have hy3 := dbl_y_ne_one hE hy hx hd h2 hDm
  have hcurve : (1 + d * y ^ 2) * x ^ 2 = y ^ 2 - 1 := by
    unfold edwardsEq at hE
    linear_combination -hE
  have hx2 : x ^ 2 = (y ^ 2 - 1) / (1 + d * y ^ 2) := by
    rw [eq_div_iff hdy]
    simpa [mul_comm] using hcurve
  rw [dbl_ed_u_formula hE hy hx hd h2 hDm hy3,
      dbl_mont_u_formula hE hy hx hd h2 hdy]
  field_simp [hy2, hdy, hdy']
  rw [hx2]
  field_simp [hdy, hdy']
  ring

theorem edwardsToMont_eq_montDouble {d x y : K}
    (hE : edwardsEq d x y) (hy : 1 - y ≠ 0) (hx : x ≠ 0)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0)
    (hDp : 1 + d * x * y * x * y ≠ 0)
    (hDm : 1 - d * x * y * x * y ≠ 0) :
    edwardsToMont d (edAddField d x y x y).1 (edAddField d x y x y).2 =
      montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2 := by
  let E := edAddField d x y x y
  let u := (edwardsToMont d x y).1
  let v := (edwardsToMont d x y).2
  let mu := (montDouble d u v).1
  let nu := (montDouble d u v).2
  change edwardsToMont d E.1 E.2 = montDouble d u v
  have hdy : 1 + d * y ^ 2 ≠ 0 := edwards_one_add_dy_ne_zero hE hy hd
  have hy3 : 1 - E.2 ≠ 0 := by
    dsimp [E]
    exact dbl_y_ne_one hE hy hx hd h2 hDm
  have huEq : (edwardsToMont d E.1 E.2).1 = mu := by
    dsimp [E, mu, u, v]
    exact dbl_u_compat hE hy hx hd h2 hDm
  have hxnu : E.1 * nu = -2 * mu := by
    have h := dbl_x_mul_v_aux hE hy hx hd h2 hDp hDm
    change (edAddField d x y x y).1 * (montDouble d u v).2 +
        2 * (montDouble d u v).1 = 0 at h
    dsimp [E, mu, nu]
    linear_combination h
  have hE12 : edwardsEq d E.1 E.2 := by
    dsimp [E]
    exact edAddClosure_aux hE hE hdy hdy hDp hDm
  have hxE : E.1 * (edwardsToMont d E.1 E.2).2 =
      -2 * (edwardsToMont d E.1 E.2).1 := edAddMont_v_mul_aux hE12 hy3
  have hM : montgomeryEq d u v := by
    dsimp [u, v]
    exact edwardsToMont_montgomery hE hy hd
  have hv : v ≠ 0 := by
    dsimp [v]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx) hdy) (pow_ne_zero 2 hy)
  by_cases hx3 : E.1 = 0
  · have hneg : (-2 : K) * mu = 0 := by
      rw [hx3] at hxnu
      simpa using hxnu.symm
    have hmu : mu = 0 := (mul_eq_zero.mp hneg).resolve_left (neg_ne_zero.mpr h2)
    have hM2 : montgomeryEq d (montDouble d u v).1 (montDouble d u v).2 :=
      montDouble_montgomery hM hd h2 hv
    have hsq := montgomery_v_sq hM2 hd
    rw [show (montDouble d u v).1 = mu by rfl, hmu] at hsq
    have hnu : nu = 0 := by
      have hsq0 : nu ^ 2 = 0 := by simpa using hsq
      have hmul : nu * nu = 0 := by simpa [pow_two] using hsq0
      rcases mul_eq_zero.mp hmul with h' | h' <;> exact h'
    apply Prod.ext
    · rw [huEq, show (montDouble d u v).1 = mu by rfl, hmu]
    · rw [show (montDouble d u v).2 = nu by rfl, hnu]
      simp [edwardsToMont, hx3]
  · apply Prod.ext
    · rw [huEq, show (montDouble d u v).1 = mu by rfl]
    · apply mul_left_cancel₀ hx3
      rw [hxE, huEq]
      exact hxnu.symm
lemma mont_slope_double {d u v : K} (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    let W := (montWeier d).toAffine
    W.slope (montB d * u) (montB d * u) (montB d ^ 2 * v) (montB d ^ 2 * v) =
      montB d * montTangentSlope d u v := by
  dsimp
  have hB := montB_ne_zero hd
  have hyneg0 : montB d ^ 2 * v ≠ -(montB d ^ 2 * v) := by
    intro h
    have hz : (2 : K) * (montB d ^ 2 * v) = 0 := by linear_combination h
    exact (mul_ne_zero h2 (mul_ne_zero (pow_ne_zero 2 hB) hv)) hz
  rw [WeierstrassCurve.Affine.slope_of_Y_ne rfl (by simpa [montWeier] using hyneg0)]
  unfold montWeier
  dsimp
  unfold montTangentSlope
  let N : K := 3 * u ^ 2 + 2 * montA d * u + 1
  have hnum : 3 * (montB d * u) ^ 2 + 2 * (montA d * montB d) * (montB d * u) +
      montB d ^ 2 - 0 * (montB d ^ 2 * v) = montB d ^ 2 * N := by
    dsimp [N]
    ring
  have hden : montB d ^ 2 * v - (-(montB d ^ 2 * v) - 0 * (montB d * u) - 0) =
      2 * montB d ^ 2 * v := by ring
  rw [hnum, hden]
  have hdenL : 2 * montB d ^ 2 * v ≠ 0 :=
    mul_ne_zero (mul_ne_zero h2 (pow_ne_zero 2 hB)) hv
  rw [div_eq_iff hdenL]
  have hdenR : 2 * montB d * v ≠ 0 := mul_ne_zero (mul_ne_zero h2 hB) hv
  rw [show montB d * (N / (2 * montB d * v)) = (montB d * N) / (2 * montB d * v) by
    rw [mul_div_assoc]]
  rw [show 2 * montB d ^ 2 * v = (2 * montB d * v) * montB d by ring]
  rw [← mul_assoc]
  rw [div_mul_cancel₀ (montB d * N) hdenR]
  dsimp [N]
  ring

lemma montToWeier_doubleCoord {d u v : K} (hM : montgomeryEq d u v)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) :
    montToWeier d (montDouble d u v).1 (montDouble d u v).2 =
      let W := (montWeier d).toAffine
      let X := montB d * u
      let Y := montB d ^ 2 * v
      let ℓ := W.slope X X Y Y
      (W.addX X X ℓ, W.addY X X Y ℓ) := by
  dsimp
  rw [mont_slope_double hd h2 hv]
  unfold montToWeier montDouble
  dsimp
  simp only [montWeier, WeierstrassCurve.Affine.addX, WeierstrassCurve.Affine.addY,
    WeierstrassCurve.Affine.negAddY, WeierstrassCurve.Affine.negY]
  unfold montA montB
  ring

lemma montDouble_add_associative_of_weierstrass {d u v u3 v3 : K}
    (hM : montgomeryEq d u v) (hM3 : montgomeryEq d u3 v3)
    (hd : 1 + d ≠ 0) (h2 : (2 : K) ≠ 0) (hv : v ≠ 0) (hv3 : v3 ≠ 0)
    (hu13 : u ≠ u3) (huD3 : (montDouble d u v).1 ≠ u3)
    (hu1D3 : u ≠ (montAdd d u v u3 v3).1) :
    montAdd d (montDouble d u v).1 (montDouble d u v).2 u3 v3 =
    montAdd d u v (montAdd d u v u3 v3).1 (montAdd d u v u3 v3).2 := by
  let W := (montWeier d).toAffine
  let X := montB d * u; let Y := montB d ^ 2 * v
  let X3 := montB d * u3; let Y3 := montB d ^ 2 * v3
  let D := montDouble d u v
  let M23 := montAdd d u v u3 v3
  have hB := montB_ne_zero hd
  have hn := mont_nonsingular hM hd h2 hv
  have hn3 := mont_nonsingular hM3 hd h2 hv3
  have hYneg0 : Y ≠ -Y := by
    dsimp [Y]
    intro h
    have hz : (2 : K) * (montB d ^ 2 * v) = 0 := by linear_combination h
    exact (mul_ne_zero h2 (mul_ne_zero (pow_ne_zero 2 hB) hv)) hz
  have hYneg : Y ≠ W.negY X Y := by
    dsimp [W, montWeier]
    simpa using hYneg0
  have hX3 : X ≠ X3 := fun h => hu13 (mul_left_cancel₀ hB h)
  let ℓ := W.slope X X Y Y
  let ℓ23 := W.slope X X3 Y Y3
  have hnD0 := WeierstrassCurve.Affine.nonsingular_add hn hn (fun hxy => hYneg hxy.2)
  have hn23_0 := WeierstrassCurve.Affine.nonsingular_add hn hn3 (fun hxy => hX3 hxy.1)
  have hnD : W.Nonsingular (W.addX X X ℓ) (W.addY X X Y ℓ) := by
    simpa [W, X, Y, ℓ] using hnD0
  have hn23 : W.Nonsingular (W.addX X X3 ℓ23) (W.addY X X3 Y ℓ23) := by
    simpa [W, X, X3, Y, Y3, ℓ23] using hn23_0
  let P := WeierstrassCurve.Affine.Point.some X Y hn
  let P3 := WeierstrassCurve.Affine.Point.some X3 Y3 hn3
  have hPD0 : P + P = WeierstrassCurve.Affine.Point.some (W.addX X X ℓ) (W.addY X X Y ℓ) hnD := by
    simpa [P, ℓ] using (WeierstrassCurve.Affine.Point.add_self_of_Y_ne (W := W) (h₁ := hn) hYneg)
  have h23 : P + P3 = WeierstrassCurve.Affine.Point.some (W.addX X X3 ℓ23) (W.addY X X3 Y ℓ23) hn23 := by
    simpa [P, P3, ℓ23] using (WeierstrassCurve.Affine.Point.add_of_X_ne (h₁ := hn) (h₂ := hn3) hX3)
  have hcD := montToWeier_doubleCoord (d := d) (u := u) (v := v) hM hd h2 hv
  have hc23 := montToWeier_addCoord (d := d) (u1 := u) (v1 := v) (u2 := u3) (v2 := v3) hd hu13
  have hcDx : montB d * D.1 = W.addX X X ℓ := by
    have := congrArg Prod.fst hcD
    simpa [W, X, Y, ℓ, D, montToWeier] using this
  have hcDy : montB d ^ 2 * D.2 = W.addY X X Y ℓ := by
    have := congrArg Prod.snd hcD
    simpa [W, X, Y, ℓ, D, montToWeier] using this
  have hc23x : montB d * M23.1 = W.addX X X3 ℓ23 := by
    have := congrArg Prod.fst hc23
    simpa [W, X, Y, X3, Y3, ℓ23, M23, montToWeier] using this
  have hc23y : montB d ^ 2 * M23.2 = W.addY X X3 Y ℓ23 := by
    have := congrArg Prod.snd hc23
    simpa [W, X, Y, X3, Y3, ℓ23, M23, montToWeier] using this
  have hnD' : W.Nonsingular (montB d * D.1) (montB d ^ 2 * D.2) := by
    rw [hcDx, hcDy]; exact hnD
  have hn23' : W.Nonsingular (montB d * M23.1) (montB d ^ 2 * M23.2) := by
    rw [hc23x, hc23y]; exact hn23
  let PD := WeierstrassCurve.Affine.Point.some (montB d * D.1) (montB d ^ 2 * D.2) hnD'
  let P23 := WeierstrassCurve.Affine.Point.some (montB d * M23.1) (montB d ^ 2 * M23.2) hn23'
  have hPD : P + P = PD := by
    rw [hPD0]
    dsimp [PD]
    rw [WeierstrassCurve.Affine.Point.some.injEq]
    exact ⟨hcDx.symm, hcDy.symm⟩
  have hP23 : P + P3 = P23 := by
    rw [h23]
    dsimp [P23]
    rw [WeierstrassCurve.Affine.Point.some.injEq]
    exact ⟨hc23x.symm, hc23y.symm⟩
  have hassoc := add_assoc P P P3
  rw [hPD, hP23] at hassoc
  have hXD3 : montB d * D.1 ≠ X3 := fun h => huD3 (mul_left_cancel₀ hB h)
  have hX1_23 : X ≠ montB d * M23.1 := fun h => hu1D3 (mul_left_cancel₀ hB h)
  rw [WeierstrassCurve.Affine.Point.add_of_X_ne hXD3] at hassoc
  rw [WeierstrassCurve.Affine.Point.add_of_X_ne hX1_23] at hassoc
  rw [WeierstrassCurve.Affine.Point.some.injEq] at hassoc
  rcases hassoc with ⟨hxeq, hyeq⟩
  let Lres := montAdd d D.1 D.2 u3 v3
  let Rres := montAdd d u v M23.1 M23.2
  have hcL := montToWeier_addCoord (d := d) (u1 := D.1) (v1 := D.2) (u2 := u3) (v2 := v3) hd huD3
  have hcR := montToWeier_addCoord (d := d) (u1 := u) (v1 := v) (u2 := M23.1) (v2 := M23.2) hd hu1D3
  have hcLx : montB d * Lres.1 = W.addX (montB d * D.1) X3
      (W.slope (montB d * D.1) X3 (montB d ^ 2 * D.2) Y3) := by
    have := congrArg Prod.fst hcL
    simpa [W, Lres, X3, Y3, D, montToWeier] using this
  have hcRx : montB d * Rres.1 = W.addX X (montB d * M23.1)
      (W.slope X (montB d * M23.1) Y (montB d ^ 2 * M23.2)) := by
    have := congrArg Prod.fst hcR
    simpa [W, Rres, X, Y, M23, montToWeier] using this
  have hcLy : montB d ^ 2 * Lres.2 = W.addY (montB d * D.1) X3 (montB d ^ 2 * D.2)
      (W.slope (montB d * D.1) X3 (montB d ^ 2 * D.2) Y3) := by
    have := congrArg Prod.snd hcL
    simpa [W, Lres, X3, Y3, D, montToWeier] using this
  have hcRy : montB d ^ 2 * Rres.2 = W.addY X (montB d * M23.1) Y
      (W.slope X (montB d * M23.1) Y (montB d ^ 2 * M23.2)) := by
    have := congrArg Prod.snd hcR
    simpa [W, Rres, X, Y, M23, montToWeier] using this
  have hx' : montB d * Lres.1 = montB d * Rres.1 := by
    rw [hcLx, hcRx]
    simpa [W, ℓ, ℓ23, D, M23] using hxeq
  have hy' : montB d ^ 2 * Lres.2 = montB d ^ 2 * Rres.2 := by
    rw [hcLy, hcRy]
    simpa [W, ℓ, ℓ23, D, M23] using hyeq
  apply Prod.ext
  · exact mul_left_cancel₀ hB hx'
  · exact mul_left_cancel₀ (pow_ne_zero 2 hB) hy'

/-- Field-level associativity in the doubling case `P = Q`, under twisted-Edwards
    completeness. The first addition `P + P` is transported through
    `edwardsToMont_eq_montDouble`, the two outer secant additions through
    `edwardsToMont_eq_montAdd_of_complete`, and associativity is inherited from
    Mathlib's Weierstrass group law by `montDouble_add_associative_of_weierstrass`. -/
theorem edAddField_associative_double_of_complete {d x y x' y' : K}
    (hi : IsSquare (-1 : K)) (hnd : ¬ IsSquare d) (h2 : (2 : K) ≠ 0)
    (hE : edwardsEq d x y) (hE' : edwardsEq d x' y')
    (hy : 1 - y ≠ 0) (hy' : 1 - y' ≠ 0)
    (hx : x ≠ 0) (hx' : x' ≠ 0)
    (hu13 : (edwardsToMont d x y).1 ≠ (edwardsToMont d x' y').1)
    (huD3 : (montDouble d (edwardsToMont d x y).1 (edwardsToMont d x y).2).1 ≠
        (edwardsToMont d x' y').1)
    (hu1S : (edwardsToMont d x y).1 ≠
        (montAdd d (edwardsToMont d x y).1 (edwardsToMont d x y).2
          (edwardsToMont d x' y').1 (edwardsToMont d x' y').2).1)
    (hyS : 1 - (edAddField d x y x' y').2 ≠ 0)
    (hyL : 1 - (edAddField d (edAddField d x y x y).1 (edAddField d x y x y).2 x' y').2 ≠ 0)
    (hyR : 1 - (edAddField d x y (edAddField d x y x' y').1 (edAddField d x y x' y').2).2 ≠ 0) :
    edAddField d (edAddField d x y x y).1 (edAddField d x y x y).2 x' y' =
      edAddField d x y (edAddField d x y x' y').1 (edAddField d x y x' y').2 := by
  let D := edAddField d x y x y
  let S := edAddField d x y x' y'
  let L := edAddField d D.1 D.2 x' y'
  let R := edAddField d x y S.1 S.2
  let u := (edwardsToMont d x y).1; let v := (edwardsToMont d x y).2
  let u3 := (edwardsToMont d x' y').1; let v3 := (edwardsToMont d x' y').2
  have hd : 1 + d ≠ 0 := by
    rcases hi with ⟨i, hi'⟩
    intro h
    have hd_eq : d = -1 := by linear_combination h
    exact hnd ⟨i, by rw [hd_eq, hi']⟩
  have hdy := edwards_one_add_dy_ne_zero hE hy hd
  have hdy' := edwards_one_add_dy_ne_zero hE' hy' hd
  have hD12 := edwards_denoms_ne_zero hE hE hi hnd
  have hDp : 1 + d * x * y * x * y ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12.1
  have hDm : 1 - d * x * y * x * y ≠ 0 := by
    simpa [mul_assoc, mul_left_comm, mul_comm] using hD12.2
  have hED : edwardsEq d D.1 D.2 := by
    dsimp [D]
    exact edAddClosure_aux hE hE hdy hdy hDp hDm
  have hyD : 1 - D.2 ≠ 0 := by
    dsimp [D]
    exact dbl_y_ne_one hE hy hx hd h2 hDm
  have hDmap : edwardsToMont d D.1 D.2 = montDouble d u v := by
    dsimp [D, u, v]
    exact edwardsToMont_eq_montDouble hE hy hx hd h2 hDp hDm
  have hES : edwardsEq d S.1 S.2 := by
    dsimp [S]
    have hDS := edwards_denoms_ne_zero hE hE' hi hnd
    exact edAddClosure_aux hE hE' hdy hdy'
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDS.1)
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDS.2)
  have hEL : edwardsEq d L.1 L.2 := by
    dsimp [L, D]
    have hDL := edwards_denoms_ne_zero hED hE' hi hnd
    have hyDL := edwards_one_add_dy_ne_zero hED hyD hd
    exact edAddClosure_aux hED hE' hyDL hdy'
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDL.1)
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDL.2)
  have hER : edwardsEq d R.1 R.2 := by
    dsimp [R, S]
    have hDR := edwards_denoms_ne_zero hE hES hi hnd
    have hyDS := edwards_one_add_dy_ne_zero hES hyS hd
    exact edAddClosure_aux hE hES hdy hyDS
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDR.1)
      (by simpa [mul_assoc, mul_left_comm, mul_comm] using hDR.2)
  have hSmap : edwardsToMont d S.1 S.2 = montAdd d u v u3 v3 := by
    dsimp [S, u, v, u3, v3]
    exact edwardsToMont_eq_montAdd_of_complete hi hnd h2 hE hE' hy hy' hu13 hyS
  have hu1S' : (edwardsToMont d x y).1 ≠ (edwardsToMont d S.1 S.2).1 := by
    rw [hSmap]
    exact hu1S
  have huD3' : (edwardsToMont d D.1 D.2).1 ≠ (edwardsToMont d x' y').1 := by
    rw [hDmap]
    exact huD3
  have hLmap : edwardsToMont d L.1 L.2 =
      montAdd d (montDouble d u v).1 (montDouble d u v).2 u3 v3 := by
    change edwardsToMont d (edAddField d D.1 D.2 x' y').1
        (edAddField d D.1 D.2 x' y').2 =
      montAdd d (montDouble d u v).1 (montDouble d u v).2 u3 v3
    have h := edwardsToMont_eq_montAdd_of_complete hi hnd h2 hED hE' hyD hy' huD3' hyL
    rw [h, hDmap]
  have hRmap : edwardsToMont d R.1 R.2 =
      montAdd d u v (montAdd d u v u3 v3).1 (montAdd d u v u3 v3).2 := by
    change edwardsToMont d (edAddField d x y S.1 S.2).1 (edAddField d x y S.1 S.2).2 =
      montAdd d u v (montAdd d u v u3 v3).1 (montAdd d u v u3 v3).2
    have h := edwardsToMont_eq_montAdd_of_complete hi hnd h2 hE hES hy hyS hu1S' hyR
    rw [h, hSmap]
  have hM : montgomeryEq d u v := by
    dsimp [u, v]
    exact edwardsToMont_montgomery hE hy hd
  have hM3 : montgomeryEq d u3 v3 := by
    dsimp [u3, v3]
    exact edwardsToMont_montgomery hE' hy' hd
  have hv : v ≠ 0 := by
    dsimp [v]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx) hdy) (pow_ne_zero 2 hy)
  have hv3 : v3 ≠ 0 := by
    dsimp [v3]
    exact div_ne_zero (mul_ne_zero (mul_ne_zero h2 hx') hdy') (pow_ne_zero 2 hy')
  have hassoc := montDouble_add_associative_of_weierstrass hM hM3 hd h2 hv hv3 hu13 huD3 hu1S
  have hmap : edwardsToMont d L.1 L.2 = edwardsToMont d R.1 R.2 := by
    rw [hLmap, hRmap]
    exact hassoc
  have hbackL := edwardsToMont_roundtrip hEL hyL hd h2
  have hbackR := edwardsToMont_roundtrip hER hyR hd h2
  change L = R
  exact hbackL.symm.trans ((congrArg (fun p : K × K => montgomeryToEdwards d p.1 p.2) hmap).trans hbackR)

end
end LeanFormalization
