# Theorem 4: Straggler and Dropout Resilience

### Formal Statement
The current Lean module does not yet formalize a probability distribution over dropouts. It machine-checks an integer redundancy surrogate showing that configured redundancy settings exceed fixed liveness guard thresholds for selected concrete profiles.

### Probability Model Status
Previous drafts mixed distinct probability settings (quorum thresholding and
redundancy-copy failure) and could apply Chernoff bounds outside their valid
parameter regime. The canonical Lean claim should therefore be read as:

1. **Surrogate guard claim (machine-checked):** configured redundancy profiles
	satisfy deterministic liveness guard inequalities.
2. **Redundancy-copy probability model:** when each copy fails independently
	with probability $(1-\alpha)$, failure is bounded by $(1-\alpha)^r$.
3. **Not yet formalized in Lean:** full binomial quorum proof for arbitrary
	$(p, q, c)$ settings, including cases where quorum threshold exceeds mean.

### Conclusion
The project tracks straggler resilience as a guard-verified model today. Full
probability-measure formalization with explicit tail conditions remains planned work.
