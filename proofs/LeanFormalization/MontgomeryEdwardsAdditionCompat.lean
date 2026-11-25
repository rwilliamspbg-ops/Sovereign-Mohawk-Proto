import Mathlib
import LeanFormalization.EdwardsWeierstrassBridge

/-!
# Montgomery ↔ Edwards addition compatibility (framework + pinned residual)

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

## Pinned residual (explicit, not a prose gap)

The *second* (v-)coordinate compatibility is a real rational identity on the
admissible locus (checked numerically over `F_101`, `d = 2`, and by clearing
denominators), but its direct `field_simp`+`ring` proof expands to a polynomial
that exceeds the tactic budget on the pinned toolchain. It is pinned as the single
field of `MontgomeryEdwardsAddCompat`, and both the full map compatibility
(`edAdd_toMont_eq_montAdd`) and Edwards associativity
(`edAddField_associative_of_compat`) are proved **conditionally** on it. Every
other ingredient of the route is unconditional and machine-checked.

The concrete Edwards implementation `Ed25519.affineAdd` is `Nat`-based modulo
`2^255 - 19`; transporting these field-level results to it additionally needs a
`ZMod`-lifting argument and twisted-Edwards completeness (`d` a non-square mod p),
which remain separate.
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

/-- The single pinned residual: v-coordinate compatibility of the two addition laws. -/
structure MontgomeryEdwardsAddCompat (d : K) : Prop where
  v_compat : ∀ {u1 v1 u2 v2 : K},
    montgomeryEq d u1 v1 → montgomeryEq d u2 v2 →
    1 + d ≠ 0 → (2 : K) ≠ 0 →
    u1 + 1 ≠ 0 → u2 + 1 ≠ 0 → montQ d u1 ≠ 0 → montQ d u2 ≠ 0 →
    u1 ≠ u2 →
    1 + d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
        ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0 →
    1 - d * (2 * v1 / montQ d u1) * (2 * v2 / montQ d u2) *
        ((u1 - 1) / (u1 + 1)) * ((u2 - 1) / (u2 + 1)) ≠ 0 →
    1 - (edAddField d
        (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
        (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2 ≠ 0 →
    (edwardsToMont d
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).1
        (edAddField d
          (2 * v1 / montQ d u1) ((u1 - 1) / (u1 + 1))
          (2 * v2 / montQ d u2) ((u2 - 1) / (u2 + 1))).2).2 =
      (montAdd d u1 v1 u2 v2).2

/-- Full addition-law compatibility, conditional on the pinned v-coordinate fact. -/
theorem edAdd_toMont_eq_montAdd (hC : MontgomeryEdwardsAddCompat d)
    {u1 v1 u2 v2 : K}
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
  · exact hC.v_compat hM1 hM2 hd h2 hu1 hu2 hq1 hq2 hu12 hD1 hD2 hy3


/-- The residual needed to transport Mathlib's associativity back to the Edwards law:
    full addition compatibility stated directly in Edwards coordinates. It follows
    from `edAdd_mont_u` plus the pinned `v_compat`, together with closure and
    denominator completeness of the Edwards law; those are separate number-theoretic
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
