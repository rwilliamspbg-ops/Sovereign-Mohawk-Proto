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
	with probability $(1-\alpha)$, failure is bounded by $(1-\alpha)^r$. This is
	now genuinely connected to a measure-theoretic probability space, not just
	asserted by fiat: `chernoff_bound_eq_binomial_zero_prob` in
	`LeanFormalization/Theorem4ChernoffBounds.lean` proves `chernoff_bound alpha r`
	equals the probability of zero "heads" in Mathlib's real `PMF.binomial`
	(r independent α-coin flips), citing Mathlib's own `PMF.binomial_apply_zero`
	rather than asserting the connection.
3. **Not yet formalized in Lean:** full binomial quorum proof for arbitrary
	$(p, q, c)$ settings, including cases where quorum threshold exceeds mean.
	The `PMF.binomial` connection above covers the "all copies fail" tail
	(0 heads) specifically, not a general quorum threshold $c$ out of $r$.

### Conclusion
The project tracks straggler resilience as a guard-verified model today, now
with the specific redundancy-copy failure probability genuinely grounded in
a real probability space rather than an unconnected formula. Full
probability-measure formalization for arbitrary quorum thresholds with
explicit tail conditions remains planned work.
