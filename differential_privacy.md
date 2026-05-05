# Differential Privacy (Companion Summary)

This companion document provides a concise reference for the Rényi
Differential Privacy (RDP) definitions and conversion rules used across the
Sovereign-Mohawk formalization and runtime accountant.

Key items:

- RDP definition (informal): For α > 1, D_α(P || Q) = (1/(α-1)) · log(E_Q[(P(x)/Q(x))^{α-1}])
- Gaussian mechanism RDP bound: (α, α/(2σ²) · Δ²)
- Conversion to (ε,δ)-DP (simplified): ε = ε_rdp + log(1/δ)/(α-1)
- Composition: RDP adds across independent mechanisms (ε_total = Σ ε_i)
- Subsampling amplification: sampling probability p reduces ε approximately by factor p
- Moment Accountant: alternative accounting via E[exp(λ · loss)] and Markov bounds

Usage in repository:

- Lean proofs (Phase 3c/3d) live under `proofs/LeanFormalization/`.
- Runtime accountant implementation is `internal/rdp_accountant.go`.
- Tests validating conversions and bounds are in `test/phase3c_theorems_test.go`
  and `test/phase3d_advanced_theorems_test.go`.

References:
- Mironov, Ilya. "Rényi Differential Privacy." 2017.
- Dong, J., Roth, A., and Su, S. "Gaussian Differential Privacy." 2019.
- Wang, Y.-X., Balle, B., and Kasiviswanathan, S. P. "Subsampled RDP." 2019.

This file resolves local documentation references used in the DEEPENING_FORMAL_PROOFS_PLAN.md
and provides a single place for quick cross-references between Lean and Go artifacts.
