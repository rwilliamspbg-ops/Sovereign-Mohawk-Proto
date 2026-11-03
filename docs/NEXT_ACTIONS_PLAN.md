# Next Actions Plan

## 1. ZK Theorem 5 (separate PR)
- Add BenchmarkVerifyProof and enforce <5ms.
- Audit public input injection: no static mock keys.
- Assert proof payload ≤200 bytes.
- Constant-time scalar mult / MSE paths.
- Clean ErrInvalidProofBoundary propagation.
- Sync Poseidon/Groth16 gadgets with Lean 4 Theorem5_Verifiability.lean.

## 2. Testing hardening (continue audit evidence)
- Implement mutation score tracking (parse gremlins, trend).
- Commit seed corpora from smoke runs.
- Expand property tests (ordering, NPU, trust, determinism).
- Add benchmarks for hot paths.

## 3. CI
- Quarantine/fix TestGetVerifiedQuoteLeaseCache (done).
- Make stress-race green on ubuntu (verify).
- Add coverage gate informational.

## 4. Dependencies
- Keep dependabot PRs flowing; re-run trivy on new changes.
