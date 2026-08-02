# Formal Traceability Matrix

This document maps each formal theorem to its Lean source, the corresponding
Go runtime implementation, and the runtime tests that validate the binding.

A condensed excerpt is provided here; the full matrix is maintained in
`results/proofs/PHASE_3c_3f_FINAL_VALIDATION_REPORT.md` and will be expanded
as Phase 3e integration proceeds.

| Theorem | Lean Source | Go Binding | Runtime Test |
|--------:|:------------|:-----------|:-------------|
| Theorem 1 — Multi-Krum Safety | proofs/LeanFormalization/Theorem1BFT.lean | internal/multikrum/aggregate.go | test/multikrum_test.go |
| Theorem 2 — RDP Composition (base) | proofs/LeanFormalization/Theorem2RDP_Enhanced.lean | internal/rdp_accountant.go | test/phase3c_theorems_test.go |
| Gaussian RDP Exact Bound (runtime-aligned bound set) | proofs/LeanFormalization/Theorem2RDP_Enhanced.lean | internal/rdp_accountant.RecordGaussianStepRDP | test/phase3c_theorems_test.go |
| Subsampling Amplification | proofs/LeanFormalization/Theorem2AdvancedRDP.lean | internal/rdp_accountant.RecordSubsampledStep | test/phase3d_advanced_theorems_test.go |
| Moment Accountant Conversion (advanced roadmap mapping) | proofs/LeanFormalization/Theorem2AdvancedRDP.lean | internal/rdp_accountant.MomentAccountant | test/phase3d_advanced_theorems_test.go |

Notes:
- All traceability entries in this matrix point to active `.lean` modules that
  are part of the Lake build graph.
- The full traceability table should be used during Phase 3e integration to
  link exact theorem names to function signatures in `internal/`.
