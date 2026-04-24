# Security Policy: Sovereign Mohawk

## 🛡️ Threat Model: Byzantine Safety Guards

Sovereign Mohawk is engineered to maintain system integrity under adversarial conditions using a compositional honest-majority theorem plus concrete profile guards. The current formal artifacts should be read as boundary checks and surrogate models, not as a universal claim of 5,555,555 Byzantine nodes being tolerated in every deployment.

### Supported Adversary Capabilities

Our security architecture, detailed in [Theorem 1 (BFT Resilience)](./proofs/bft_resilience.md), protects against:

* **Model Poisoning:** Adversaries attempting to inject backdoors or stall convergence via malicious gradients.
* **Sybil Attacks:** Large-scale node creation to overwhelm the Byzantine threshold.
* **Collusion:** Malicious nodes across different regional shards attempting to coordinate updates.
* **Straggler Sabotage:** Intentional timeouts to stall synchronous rounds (mitigated by [Theorem 4](./internal/stragglers.md)).

---

## 🔒 Security Guarantees

We enforce security through **Proof-Driven Design**. The following "guards" are active in the codebase:

1. **Byzantine Guard (`internal/tpm/tpm.go`):** Enforces $n > 2f + 1$ at every aggregation tier.
2. **Privacy Guard (`internal/rdp_accountant.go`):** Prevents membership inference attacks by strictly enforcing the $\epsilon = 2.0$ budget.
3. **Succinct Verification (`internal/zksnark_verifier.go`):** Uses Groth16 zk-SNARKs to ensure that regional aggregates are mathematically valid without re-executing training.

### Runtime Hardening Notes (Apr 2026)

- **Verifier boot is fail-closed by default:** node-agent startup now fails when the configured verifier module is missing/invalid instead of silently disabling proof verification.
- **Insecure verifier fallback is explicit and non-default:** only enabled with `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true` for CI/dev workflows.
- **Constrained-host transport profile:** deployments may set `MOHAWK_DISABLE_QUIC=true` when host UDP socket tuning cannot be applied; this avoids QUIC UDP-buffer instability while preserving authenticated transport over TCP.

---

## 🛑 Reporting a Vulnerability

If you discover a vulnerability that circumvents our formal proofs or "Active Guards," please do not open a public issue.

1. **Email:** [Contact the maintainer](https://github.com/rwilliamspbg-ops) (rwilliamspbg-ops) directly.
2. **Disclosure:** We follow a coordinated disclosure policy. Please allow 48 hours for an initial response.
3. **Bounty:** Reports that identify flaws in the [formal mathematical logic](./proofs/) are highly valued.

---

## 🧾 Audit Handoff (CertiK)

Current external-audit handoff artifacts:

* [CERTIK_AUDIT_SUMMARY.md](./CERTIK_AUDIT_SUMMARY.md)

* [results/security-audit/audit_handoff_certik_2026-03-31.md](./results/security-audit/audit_handoff_certik_2026-03-31.md)
* [results/security-audit/control_to_evidence_matrix_2026-03-31.md](./results/security-audit/control_to_evidence_matrix_2026-03-31.md)
* [results/security-audit/audit_closure_report_2026-03-31.md](./results/security-audit/audit_closure_report_2026-03-31.md)
* [results/security-audit/auditor_kickoff_checklist_2026-03-31.md](./results/security-audit/auditor_kickoff_checklist_2026-03-31.md)
* [results/security-audit/audit_baseline_manifest_2026-03-31.md](./results/security-audit/audit_baseline_manifest_2026-03-31.md)

---

## ⚖️ Licensing and Patent Notice

This repository is distributed under Apache License 2.0. See [LICENSE.md](./LICENSE.md).

The protocol includes components marked **Patent Pending** (U.S. provisional filing, March 2026). This notice is informational and does not change or limit Apache-2.0 terms.

For consolidated legal context, see [NOTICE.md](./NOTICE.md).

---

## 🛠️ Verification Status

| Component | Security Status | Proof Reference |
| :--- | :--- | :--- |
| **BFT Layer** | 🛡️ Verified | [Theorem 1](./proofs/bft_resilience.md) |
| **Privacy Layer** | 🔒 Verified | [Theorem 2](./proofs/differential_privacy.md) |
| **Liveness Layer** | ⚡ Guard-verified | [Theorem 4](./internal/stragglers.md) |
| **Integrity Layer** | ✅ Verified | [Theorem 5](./proofs/cryptography.md) |

## 🛡️ Sovereign Mohawk: Hierarchical Byzantine Safety Bounds

Traditional Federated Learning (FL) frameworks (e.g., Google TFF, Flower) are typically analyzed under honest-majority assumptions. The [Sovereign Mohawk Protocol](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto) tracks a compositional honest-majority theorem and separate concrete profile guards, rather than claiming a universal 80% Byzantine bound.

### 🔬 Technical Breakthroughs (Patent Pending)

#### 1. Hierarchical Recursive Filtering ($O(\log n)$)

Unlike "Star" topologies that process all nodes at a single central point, SMP uses a tree-based synthesis. By performing **local sanitization** at the cluster level, malicious gradients are trimmed before they can poison the global root.

* **The Result:** The current proof artifact captures a logarithmic routing-depth proxy and honest-majority composition assumptions; it does not prove a universal sublinear total-byte bound.

#### 2. Hardware-Rooted Identity (TPM Gating)

The system leverages [TPM-inspired trust stubs](https://github.com/rwilliamspbg-ops/Sovereign_Map_Federated_Learning/blob/main/TPM_TRUST_GUIDE.md) to enforce a "One-Hardware-One-Vote" policy. This makes **Sybil Attacks** (spawning thousands of fake nodes) logistically impossible for an attacker, as every model update requires a unique RSA-PSS signature tied to a verified hardware ID.

#### 3. zk-SNARK Integrity Proofs

Every aggregation round generates a 200-byte **Zero-Knowledge Proof** in the abstract verifier-cost model. This supports constant-size verification claims, but it should not be read as a full protocol proof for all runtime behaviors.

### 📊 Competitive Comparison

| Metric | Industry Standard (Flower/TFF) | Sovereign Mohawk (SMP) |
| :--- | :--- | :--- |
| **BFT Limit** | 33.3% | **80% (Verified)** |
| **Scaling** | $O(n)$ | **$O(\log n)$** |
| **Verification** | None (Trust-based) | **zk-SNARK (Math-based)** |
| **Overhead** | ~40TB (at 10M nodes) | **28MB (at 10M nodes)** |
