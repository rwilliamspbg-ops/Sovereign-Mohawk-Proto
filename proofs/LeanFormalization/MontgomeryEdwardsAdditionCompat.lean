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

## Residual assumptions and scope limits (explicit, not hidden)

The proved compatibility still takes explicit non-vanishing hypotheses:
`hDenP` (cleared denominator of the Edwards sum's `x`-coordinate) and
`hPnumHyp` (its divided form, used to clear nested denominators). The former
`hx3` hypothesis is no longer needed: when the Edwards sum has `x₃ = 0`, both
sides map to `(0, 0)` on the Montgomery curve, discharged by
`montAdd_v_eq_zero_of_u_eq_zero`.

Transporting Mathlib's associativity back to the Edwards law still needs
`EdwardsAddCompatForAssociativity`: full compatibility in Edwards coordinates,
closure of the Edwards law, and the auxiliary non-vanishing conditions are
carried as one explicit bundle. Denominator completeness itself is now proved
by `edwards_denoms_ne_zero` under `IsSquare (-1)` and `¬ IsSquare d`; what remains
is packaging that proof into the bundle and handling the `y = 1` exceptional
point, where the birational map itself is undefined.

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
    `p = 2^255 - 19 ≡ 1 mod 4`, so `-1` is a square). No division, no `2 ≠ 0`
    and no coordinate-nonzero hypotheses are needed.

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
    edwardsEq d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 →
    1 - (edAddField d x1 y1 x2 y2).2 ≠ 0 →
    edwardsToMont d (edAddField d x1 y1 x2 y2).1 (edAddField d x1 y1 x2 y2).2 =
      montAdd d (edwardsToMont d x1 y1).1 (edwardsToMont d x1 y1).2
               (edwardsToMont d x2 y2).1 (edwardsToMont d x2 y2).2
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
    exact hA.compat hE1 hE2 hy1 hy2 hd h2 hE12 hy12
  have hcomp23 : M23 = montAdd d M2.1 M2.2 M3.1 M3.2 := by
    dsimp [M23, P23, M2, M3]
    exact hA.compat hE2 hE3 hy2 hy3 hd h2 hE23 hy23
  have hcompL : edwardsToMont d L.1 L.2 = montAdd d M12.1 M12.2 M3.1 M3.2 := by
    dsimp [L, M12, M3, P12]
    exact hA.compat hE12 hE3 hy12 hy3 hd h2 hE12L hy12L
  have hcompR : edwardsToMont d R.1 R.2 = montAdd d M1.1 M1.2 M23.1 M23.2 := by
    dsimp [R, M23, M1, P23]
    exact hA.compat hE1 hE23 hy1 hy23 hd h2 hE1R hy1R
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

end
end LeanFormalization
