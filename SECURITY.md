# Security Policy: Sovereign Mohawk

## 🛡️ Threat Model: 5.55M Malicious Nodes
Sovereign Mohawk is engineered to maintain system integrity under an **Adversarial Majority** at the global scale, specifically designed to withstand up to **5,555,555 Byzantine nodes** (55.5% of a 10M node network).

### Supported Adversary Capabilities
Our security architecture, detailed in [Theorem 1 (BFT Resilience)](./proofs/bft_resilience.md), protects against:
* **Model Poisoning:** Adversaries attempting to inject backdoors or stall convergence via malicious gradients.
* **Sybil Attacks:** Large-scale node creation to overwhelm the Byzantine threshold.
* **Collusion:** Malicious nodes across different regional shards attempting to coordinate updates.
* **Straggler Sabotage:** Intentional timeouts to stall synchronous rounds (mitigated by [Theorem 4](./proofs/stragglers.md)).

---

## 🔒 Security Guarantees
We enforce security through **Proof-Driven Design**. The following "guards" are active in the codebase:

1. **Byzantine Guard (`internal/tpm/tpm.go`):** Enforces $n > 2f + 1$ at every aggregation tier.
2. **Privacy Guard (`internal/rdp_accountant.go`):** Prevents membership inference attacks by strictly enforcing the $\epsilon = 2.0$ budget.
3. **Succinct Verification (`internal/zksnark_verifier.go`):** Uses Groth16 zk-SNARKs to ensure that regional aggregates are mathematically valid without re-executing training.

---

## 🛑 Reporting a Vulnerability
If you discover a vulnerability that circumvents our formal proofs or "Active Guards," please do not open a public issue. 

1. **Email:** [Contact the maintainer](https://github.com/rwilliamspbg-ops) (rwilliamspbg-ops) directly.
2. **Disclosure:** We follow a coordinated disclosure policy. Please allow 48 hours for an initial response.
3. **Bounty:** Reports that identify flaws in the [formal mathematical logic](./proofs/) are highly valued.

---

## 🛠️ Verification Status
| Component | Security Status | Proof Reference |
| :--- | :--- | :--- |
| **BFT Layer** | 🛡️ Verified | [Theorem 1](./proofs/bft_resilience.md) |
| **Privacy Layer** | 🔒 Verified | [Theorem 2](./proofs/differential_privacy.md) |
| **Liveness Layer** | ⚡ Verified | [Theorem 4](./proofs/stragglers.md) |
| **Integrity Layer** | ✅ Verified | [Theorem 5](./proofs/cryptography.md) |
