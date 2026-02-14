# Theorem 4: Straggler and Dropout Resilience

### Formal Statement
With redundancy parameter $r = 10\times$, the system tolerates a 50% regional dropout rate with a success probability of at least $1 - \exp(-k/2)$, where $k$ is the expected number of successful regional aggregations.

### Chernoff Bound Derivation
1. **Regional Failure:** With $r=10$ and $50\%$ dropout: $P(\text{fail}) = (0.5)^{10} \approx 0.001$.
2. **Expected Success ($k$):** For $n=1,000$ regions, $E[\text{success}] = 999$.
3. **Exponential Reliability:** $$P(X < 500) < \exp(-999 \times 0.25 / 2) < 10^{-54}$$
   
### Conclusion
The hierarchical redundancy provides exponentially strong guarantees against stragglers, achieving $>99.99\%$ operational reliability.
