# Theorem 2: Rényi Differential Privacy (RDP) Composition

### Formal Statement
The Lean module machine-checks two distinct things:

**1. An integer/rational surrogate for additive privacy-budget bookkeeping:**
- `composeEps`/`composeEpsRat` sum a list of tier budgets,
- composition over concatenation is additive,
- appending extra steps is monotone, and
- selected concrete profiles remain under configured guards.

**2. A real RDP composition theorem for independent mechanisms**, stated and
proved over actual probability distributions (`RenyiDivergence`, a real
Rényi-divergence formula, not the integer surrogate): `RDP_sequential_composition`
shows that if two mechanisms' output distributions (on the inputs under
comparison) are `(α, ε1)`- and `(α, ε2)`-RDP respectively, their independent
joint output is `(α, ε1+ε2)`-RDP. This follows from `RenyiDivergence_product_add`,
which proves Rényi divergence tensorizes exactly over independent product
distributions. Scope: this covers *independent* composition (two mechanisms run
independently on the same inputs, combined as a pair) — it does not cover
*adaptive* composition, where a second mechanism's behavior additionally depends
on the first mechanism's realized output; that needs the conditional/joint
Rényi chain rule and is not formalized here.

Item 1 is a useful bookkeeping model but not a formalization of RDP as a
property of mechanisms; item 2 is. Both machine-checked; neither result implies
the other.

### Proof of Conversion to $(\epsilon, \delta)$-DP
The standard analytical conversion discussed for future formalization is:
$$\epsilon = \epsilon_{RDP} + \frac{\log(1/\delta)}{\alpha - 1}$$

### Application to Sovereign-Mohawk
Based on our 4-tier architecture:
* **Edge:** $\epsilon = 0.1$
* **Regional:** $\epsilon = 0.5$
* **Continental:** $\epsilon = 1.0$
* **Total RDP:** $\epsilon \approx 1.6$

Using $\alpha = 10$ and $\delta = 10^{-5}$, the architecture target is **$\epsilon \approx 2.0$**.

At present, that real-valued RDP-to-$(\epsilon, \delta)$ statement is documented analytically and runtime-checked in the accountant, but the Lean proof file only establishes the integer composition surrogate described above.
