# Theorem 2: Rényi Differential Privacy (RDP) Composition

### Formal Statement
The current Lean module machine-checks an integer surrogate for additive privacy-budget composition:

- `composeEps` sums a list of tier budgets represented as `Nat`,
- composition over concatenation is additive,
- appending extra steps is monotone, and
- selected concrete profiles remain under configured integer guards.

This is a useful bookkeeping model, but it is not yet a formalization of RDP as a property of mechanisms or probability distributions.

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
