# Theorem 4: Straggler and Dropout Resilience

### Formal Statement
The current Lean module does not yet formalize a probability distribution over dropouts. It machine-checks an integer redundancy surrogate showing that configured redundancy settings exceed fixed liveness guard thresholds for selected concrete profiles.

### Chernoff Bound Derivation
1. **Regional Failure:** With $r=10$ and $50\%$ dropout: $P(\text{fail}) = (0.5)^{10} \approx 0.001$.
2. **Expected Success ($k$):** For $n=1,000$ regions, $E[\text{success}] = 999$.
3. **Exponential Reliability:** $$P(X < 500) < \exp(-999 \times 0.25 / 2) < 10^{-54}$$
   
### Conclusion
The hierarchical redundancy analysis suggests exponentially strong guarantees against stragglers, but the current Lean proof file should be understood as a surrogate guard model rather than a full formal proof of the Chernoff-style probability statement above.
