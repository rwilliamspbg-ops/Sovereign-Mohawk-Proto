# Theorem 3: Communication Optimality

### Formal Statement
The hierarchical aggregation protocol achieves a communication complexity of $O(d \log n)$, matching the information-theoretic lower bound $\Omega(d \log n)$ for distributed functional aggregation.

### Comparison
* **Naive FedAvg:** $O(dn)$ — requiring $\approx 40\text{TB}$ for $10\text{M}$ nodes.
* **Sovereign-Mohawk:** $O(d \log_{10} n)$ — requiring $\approx 28\text{MB}$ total.

### Proof Sketch
By aggregating updates in a balanced 4-tier tree, each internal node only transmits a single $d$-dimensional vector to its parent. With a branching factor of 10, the path length is $\log_{10}(10^7) = 7$, leading to the logarithmic scaling factor.
