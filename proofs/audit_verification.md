---
name: "🛡️ Cryptographic Audit / Theorem Verification"
about: Report findings from an audit of the formal proofs or zk-SNARK logic.
title: "[AUDIT] <Theorem/Logic Component Name>"
labels: ["audit", "cryptography", "priority-high"]
assignees: ""
---

### 🔍 Audit Target
Specify which theorem or code section you audited (e.g., Theorem 5 Verification Logic, zk-SNARK Aggregation).

### 🛠️ Methodology
Describe how you verified the logic (e.g., manual code review, formal solver, or running the `proofs/` scripts).

### 📋 Findings
- **Status:** [PASSED / FAILED / OBSERVATION]
- **Details:** Provide a technical breakdown of your findings.
- **Accuracy Verification:** Compare against [`proofs/FORMAL_TRACEABILITY_MATRIX.md`](FORMAL_TRACEABILITY_MATRIX.md) for the current, honest scope of each theorem (e.g. Theorem 5's abstract constant-cost verifier model is explicitly *not* a full Groth16 soundness proof -- see [`proofs/cryptography.md`](cryptography.md) and `internal/zksnark_verifier.go`'s doc comment for the exact gap). There is no "Round 45 Audit" or "10ms verification time" baseline in this repo to compare against -- a previous revision of this template referenced both, and neither traced to any real artifact here. If you measure a real verification latency, report the number and how you measured it instead.

### 💡 Suggestions
Any improvements to the cryptographic primitives or potential edge cases discovered?

### 🔗 PQC Migration Audit Addendum (Theorem 7/8)
- **Theorem 7 target:** `LeanFormalization/Theorem7PQCMigrationContinuity.lean`
- **Theorem 8 target:** `LeanFormalization/Theorem8DualSignatureNonHijack.lean`
- **Go linkage:** `internal/token/migration_signatures.go`, `internal/token/settlement.go`
- **Required evidence:**
	- `lake build LeanFormalization.Theorem7PQCMigrationContinuity LeanFormalization.Theorem8DualSignatureNonHijack`
	- Runtime tests: `test/utility_coin_test.go`, `test/utility_coin_settlement_test.go`
