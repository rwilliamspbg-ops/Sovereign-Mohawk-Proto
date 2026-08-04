# Theorem 1: Hierarchical Multi-Krum Resilience

### Formal Statement
Let $T$ be the number of tiers in the hierarchy. For any tier $t \in \{1, \dots, T\}$, let $n_t$ be the number of aggregators and $f_t$ be the number of Byzantine nodes. If $f_t < \frac{n_t}{2}$ for all $t$, the global model is $(\sum_{t=1}^T f_t)$-Byzantine resilient.

The current Lean development additionally machine-checks a concrete 5/9 profile
guard ($9f < 5n$) for selected tier configurations, but it does not prove that
an arbitrary tier with malicious fraction above $1/2$ remains robust under the
same honest-majority argument.

### Proof Sketch
1. **Lemma 1 (Single-Tier Selection):** The Multi-Krum algorithm selects a set of updates $S$ such that the squared distance to honest neighbors is minimized. Given $f < \frac{n}{2}$, the scoring phase ensures that at least one honest update is chosen as the barycenter.
2. **Lemma 2 (Inductive Safety):** * **Base Case:** At the Edge tier ($t=1$), local updates are filtered via Krum, ensuring the first aggregate is honest-bounded.
    * **Inductive Step:** If tier $t-1$ outputs a $(\sum_{i=1}^{t-1} f_i)$-resilient model, tier $t$ preserves this safety property because $f_t < \frac{n_t}{2}$.
3. **Conclusion:** Two distinct results are tracked:
    - a compositional honest-majority theorem under $f_t < n_t/2$ assumptions, and
    - a concrete numeric 5/9 profile check for the published 10M-node configuration.

These should not be conflated into a general proof that recursive filtering
preserves correctness when an input tier exceeds $50\%$ malicious participation.

### Correction: the "Inductive Safety" proof sketch above is FALSE

Lemma 2's inductive step — "if tier $t-1$ outputs a resilient model and
$f_t < n_t/2$, tier $t$ preserves this safety property" — was formalized as a
deterministic compositional theorem and found to be **false**, with a
concrete, machine-checked counterexample: `LeanFormalization/Theorem1BFT.lean`,
`hierarchical_composition_counterexample`. A weighted (by actual subtree
leaf-count, not just child-count) local honest-majority guard holding at
*every* level of a 2-child, depth-3 tree still permits 60% of leaves to be
Byzantine overall. The gap: a "safe" tier is only guaranteed *better than
half* honest internally, and crediting it with its *full* leaf-weight (the
only option available to a parent that can't see past an aggregated output)
lets an adversary concentrate near-50% corruption inside a nominally-safe
branch while a separate wholly-Byzantine branch adds more uncredited weight
than the local majority check accounts for. Reworking the algebra for any
fixed per-level threshold (not just $1/2$) reproduces the same gap — this is
structural, not a threshold-tuning problem.

What this means for the claim above: "the global model is
$(\sum_t f_t)$-Byzantine resilient" given only "$f_t < n_t/2$ for all $t$" is
not established, and the natural deterministic argument for it doesn't work.
A real version of this claim needs a *probabilistic* argument — consistent
with this system's actual architecture (randomly-sampled committees, not a
fixed adversarial partition): if committee membership is drawn via random
sampling from a population with a bounded *global* Byzantine fraction, the
adversary can't choose which tier to concentrate corruption in, and a
concentration bound (hypergeometric/binomial tail) shows any single
committee exceeding its local threshold is exponentially unlikely. That is a
different, measure-theoretic formalization task, not attempted here — see
`Theorem1BFT.lean`'s own comment on this section for the full argument.

The concrete 5/9 profile check (`theorem1_five_ninths_guard`,
`theorem1_global_bound_checked`) is unaffected — it's a real, correct fact
about a *given* tier's Byzantine count and was never claiming to compose.

### Phase 3, pass 1: the probabilistic repair was attempted — real, but not yet useful at deployment scale

The probabilistic argument this section calls for was subsequently
formalized for real in `Theorem1BFT.lean`: `binomial_mean` (the mean of a
Binomial(n,p) count, proved from scratch — not available in Mathlib),
`binomial_markov` (a per-committee Markov's-inequality tail bound under
i.i.d. random sampling), and `probabilistic_hierarchical_bound` (unioning
that bound across `T` committees via the already-proven `theorem4_union_bound`).

This was a deliberately scoped-down version of the fix: Markov's inequality
is real and provable without the general measure-theoretic machinery a full
Chernoff/Hoeffding exponential tail bound would need, but it is also
*weak* — polynomial decay, not exponential. `probabilistic_bound_too_loose_at_deployment_scale`
checked, honestly, that this weaker bound was **not useful at this system's
own published scale**: at `T=200` committees of `c=50,000` (10M nodes total),
10% global Byzantine rate, majority threshold, the bound evaluates to `40`
— far past `1`, i.e. vacuous. `probabilistic_hierarchical_bound_small_scale_example`
confirmed the underlying theorem gives a genuinely useful (`≤6%`) bound at a
smaller illustrative scale, so this wasn't vacuous in general — the gap was
specifically that Markov's inequality is too weak for the union bound to
survive being taken over 200 committees at this system's node count.

### Phase 3, pass 2: the deployment-scale gap is now closed for real

`Theorem1BFT.lean` now also has a real Chernoff-style bound:
`chernoffBoundZ`/`binomialTail_le_chernoffBoundZ` apply Markov's inequality
to `zˣ` for an arbitrary rational base `z ≥ 1` (equivalent to the standard
`e^{tX}`-based Chernoff method with `z = e^t`, but formalized entirely in
`ℚ` — no transcendental functions, and no need for Mathlib's general
sub-Gaussian/MGF machinery), reusing the exact same weighted-sum-extension
technique already proven for `binomial_mean`/`binomial_markov`.
`chernoff_hierarchical_bound` unions this per-committee bound across `T`
committees the same way the Markov version did.

At the identical deployment-scale parameters the Markov bound failed at
(`T=200`, `c=50,000`, `p=10%`, majority threshold), `chernoff_hierarchical_bound_deployment_scale`
(at base `z=2`) proves the union-bound failure probability is at most
`200/10^1000` — not merely below `1`, but smaller than any probability that
could ever matter operationally. The huge-exponent numeric check needed
`native_decide` rather than `norm_num` (comparing ~5000-digit rationals,
which `norm_num` could not decide in reasonable time), the same technique
already used elsewhere in this repo for large concrete numeric checks.

This closes the gap the previous pass left open, without needing the full
general measure-theoretic Chernoff/Hoeffding machinery originally assumed
necessary — the elementary `ℚ`-arithmetic technique already established in
this file turned out to be sufficient.
