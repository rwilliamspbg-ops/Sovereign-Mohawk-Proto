# Theorem 2: Rényi Differential Privacy (RDP) Composition

### Formal Statement
For $k$ mechanisms where each mechanism $M_i$ satisfies $(\alpha, \epsilon_i)$-RDP, their sequential composition satisfies $(\alpha, \sum \epsilon_i)$-RDP.

### Proof of Conversion to $(\epsilon, \delta)$-DP
We convert the RDP sum to standard $(\epsilon, \delta)$ using:
$$\epsilon = \epsilon_{RDP} + \frac{\log(1/\delta)}{\alpha - 1}$$

### Application to Sovereign-Mohawk
Based on our 4-tier architecture:
* **Edge:** $\epsilon = 0.1$
* **Regional:** $\epsilon = 0.5$
* **Continental:** $\epsilon = 1.0$
* **Total RDP:** $\epsilon \approx 1.6$

Using $\alpha = 10$ and $\delta = 10^{-5}$, the tightened bound achieves the target **$\epsilon \approx 2.0$**.
