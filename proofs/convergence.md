# Theorem 6: Non-IID Convergence Bound

### Formal Statement
Under non-IID data distributions with heterogeneity bound $\zeta^2$, hierarchical SGD with $K$ local steps and $T$ rounds converges:
$$E[\|\nabla F(x_T)\|^2] \leq O\left(\frac{1}{\sqrt{KT}}\right) + O(\zeta^2)$$

### Impact
This establishes that the system converges to a neighborhood of stationarity at a rate comparable to standard Federated Averaging, even with massive data heterogeneity across $10\text{M}$ nodes.
