# Formal Results Summary

**Status:** archival summary of the machine-checked results in this repository.
**Last updated:** 2026-11-21.
**Authoritative per-claim status:** [`proofs/FORMAL_TRACEABILITY_MATRIX.md`](../proofs/FORMAL_TRACEABILITY_MATRIX.md)
(34 main rows + the Workstream 4 table). This document is a reading guide, not a
claim registry — where the two disagree, the matrix wins.

Every theorem named below was checked with `#print axioms` on the pinned
toolchain (`leanprover/lean4:v4.30.0-rc2`, Mathlib `v4.30.0-rc2`) and reports
only Mathlib's foundation (`propext`, `Classical.choice`, `Quot.sound`) unless
an explicit hypothesis is listed. No `axiom` declaration, no `sorry`, no
`admit`, no `native_decide` anywhere in `proofs/`.

Reproduce:

```bash
cd proofs
lake build LeanFormalization Specification Refinement
bash scripts/ci/validate_formal_traceability.sh
python3 scripts/ci/check_no_unsafe_placeholders.py
```

---

## 1. Hierarchical Multi-Krum: a machine-checked negative result, and a probabilistic repair

**Module:** `LeanFormalization/Theorem1BFT.lean`, `LeanFormalization/ProtocolSafety.lean`.

**Negative result.** `hierarchical_composition_counterexample` is a concrete
two-child aggregation tree in which a *weighted* (by actual subtree leaf count)
local honest-majority guard holds at every level, yet the true global Byzantine
leaf fraction is **60%**. Deterministic composition of per-tier guards does not
compose. This is a disproof, not an artifact: no per-tier threshold fixes it,
because a passed committee is credited its full leaf weight regardless of how
close to 50% Byzantine it is internally.

**Repair.** `chernoff_hierarchical_bound_deployment_scale` proves, at the
system's own published scale ($T = 200$ committees of $c = 50{,}000$ leaves,
$10\%$ global Byzantine rate), that the union-bound failure probability is at
most $200/10^{1000}$. `binomial_mean` and `binomialTail_le_chernoffBoundZ` are
proved from scratch (Mathlib's `Binomial` mean is an unproven `proof_wanted`
stub). The deployment-scale numeric check is done by **exponent reduction**
(`pow_le_pow_iff_left₀` + `norm_num`), not `native_decide`.

**Scope.** The repair is proved for an explicit i.i.d. Bernoulli committee
sampling model. The deterministic compositional question stays closed
negatively and permanently. `probabilistic_bound_too_loose_at_deployment_scale`
records that the earlier Markov-inequality attempt evaluates to `40` (vacuous)
at the same parameters.

## 2. Ed25519 UF-CMA, composed from four proved pieces

**Modules:** `SchnorrForking.lean`, `SchnorrUF_CMA.lean`,
`SchnorrUF_CMAWithOracle.lean`, `Ed25519VerificationEquation.lean`,
`Ed25519UF_CMASecurity.lean`.

The capstone `ed25519_ufcma_security` concludes $\epsilon \le 1/\mathrm{dlL}$
for a UF-CMA adversary against the **real** Ed25519 verification equation
$S \cdot B = R + h \cdot A$. It composes:

1. `Ed25519GroupLaws affineBase` — **four** group laws for the unaudited
   `affineScalarMulImpl`/`affineAdd` (reduced from six; `zeroMul` and `oneMul`
   had zero dependents and were removed). Each surviving law has a concrete
   violator.
2. `verificationEquation_iff_ModEq` — the curve equation is *equivalent* to the
   Schnorr exponent equation $s \equiv r + h a \pmod L$.
3. `ufcma_security_of_dl_hard` — the random-oracle forking reduction
   $\phi \ge \epsilon^2 - \epsilon/N$, hence $\epsilon \le 1/N$ under
   `SchnorrDLHard`.
4. `SchnorrDLHard dlL` — the discrete-log hardness assumption (an explicit
   `def`, not an axiom).

**Two scope limits, load-bearing:** the group laws are **assumed**, not proved
from the curve arithmetic; and the random oracle is a **uniform-challenge**
abstraction, so the Pointcheval–Stern $\epsilon^2/q_H$ loss is **not** recovered.
The forking *content* is a proved pigeonhole argument
(`exists_fork_of_card`), not an opaque hypothesis.

## 3. Measure-theoretic Rényi divergence, and the Gaussian bound derived

**Module:** `LeanFormalization/RenyiDivergenceMeasure.lean`.

`RenyiDivergenceMeasure` is the divergence of two densities w.r.t. a base
measure; `renyiDivergenceMeasure_count_eq_renyiDivergence` proves the existing
finite-support `RenyiDivergence` is exactly its counting-measure special case,
so the old development is subsumed rather than paralleled.

`gaussianRDP_integral` **proves** the completed-square identity
$\int q^\alpha / p^{\alpha-1} = \exp(\alpha(\alpha-1)\Delta^2/(2\sigma^2))$ for
$p = N(0,\sigma^2)$, $q = N(\Delta,\sigma^2)$, from Mathlib's `integral_gaussian`
plus a proved shift lemma (`gaussianIntegral_shift`). `gaussianRDPBound_measure`
then **derives** $D_\alpha = \alpha \Delta^2 / (2\sigma^2)$ **unconditionally**
(only $\sigma \ne 0$, $\alpha \ne 1$). The earlier `GaussianRDPHypotheses`
bundle and the `Theorem2RDP.gaussianRDPBound` existence witness are both
superseded.

## 4. Composition across rounds, over a product measure

**Module:** `LeanFormalization/RenyiDivergenceCompose.lean`.

`renyiDivergenceMeasure_prod` tensorizes the divergence over a product measure:
for nonnegative densities with positive marginal integrands,
$D_\alpha(p_1 \otimes p_2 \parallel q_1 \otimes q_2)$ w.r.t. $\mu \cdot \nu$ equals
$D_\alpha(p_1 \parallel q_1) + D_\alpha(p_2 \parallel q_2)$. The consumer
`gaussianRDPMeasure_two_rounds` composes the Gaussian bound across two
independent rounds: $2 \cdot \alpha \Delta^2/(2\sigma^2)$.

**Scope.** Independent composition only. Adaptive composition — the second
mechanism depending on the first's realized output — is covered for finite
support by `Theorem2RDP.RDP_adaptive_composition` (worst-case bound), not here.
The negative control `renyiDivergenceMeasure_prod_positivity_needed` shows the
marginal-integral positivity is load-bearing.

## 5. Supporting results

| Result | Declaration |
| --- | --- |
| Schnorr special soundness / HVZK / forking | `schnorr_special_soundness`, `schnorr_hvzk_simulation`, `exists_fork_of_card`, `success_card_le_of_dl_hard` |
| MiMC round injectivity at BN254 | `mimcRound_bn254_injective` |
| RDP → $(\epsilon,\delta)$-DP conversion bound | `Refinement.rdpToApproxDP_bound`, `rdpLog_sandwich` |
| ZK circuit relation modelled | `Refinement.ZKCircuit.zk_impl_accept_iff` (Groth16 soundness **not** formalized) |
| a.s. convergence under Robbins–Monro | `LeanFormalization.multikrum_convergence_ae` |

---

## Standing assumptions

None is an `axiom`; each is an explicit argument at the use site.

| Assumption | Kind | Used by |
| --- | --- | --- |
| `FloatOrderLaws` | IEEE-754 non-NaN order laws (structure) | Multi-Krum refinement |
| `Fact (Nat.Prime dlL)` | number fact, not discharged by `decide` at 254 bits | Ed25519 group order |
| `Fact (Nat.Prime bn254Prime)` | number fact | MiMC at BN254 |
| `SchnorrDLHard` | cryptographic hardness (`def`) | Schnorr / Ed25519 security |
| `Ed25519GroupLaws affineBase` | four curve-model laws (structure) | Ed25519 verification-equation bridge |

## Deliberately not claimed

- Full Groth16 / q-SDH soundness (Mathlib has no pairing or hardness
  machinery).
- MiMC collision resistance (only round injectivity is proved).
- The multivariate Gaussian mechanism, adaptive composition in the
  measure-theoretic framework, and the Gaussian `(ε,δ)`-DP conversion.
- Byte-level Ed25519 decode (`decodePoint`, `sha512`, the 64-byte layout) is not
  refined; `Refinement/DLP.lean` refines the coordinate comparison only.
- The trusted setup is an in-process simulated ceremony (a development key).
