# Theorem 6: Non-IID Convergence Bound

### Formal Statement
The current Lean formalization does not prove the full stochastic convergence theorem over expectations. Instead, it machine-checks surrogate convergence envelopes that:

- decrease as the effective round budget grows,
- increase with larger heterogeneity surrogates, and
- satisfy concrete large-scale guard checks for selected protocol parameters.

The two current machine-checked models are:

- an integer surrogate envelope of the form `zeta^2 + 1000000 / (K*T + 1)`, and
- a rational envelope of the form `1 / (2KT) + zeta^2` for positive `K, T`.

The stronger claim
$$E[\|\nabla F(x_T)\|^2] \leq O\left(\frac{1}{\sqrt{KT}}\right) + O(\zeta^2)$$
remains a roadmap item until it is formalized directly in Lean.

### Impact
This gives the project a machine-checked surrogate sanity check for convergence-related tuning and thresholding, but it should not yet be described as a formal proof of the full non-IID SGD rate.
