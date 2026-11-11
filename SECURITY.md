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
3. **Succinct Verification (`internal/zksnark_verifier.go`):** Uses Groth16 zk-SNARKs to check a proof against a verification key. **Scope caveat:** the configured key (`genesisVK`) is a fixed, content-free pairing identity, not derived from a circuit's trusted setup — so the verifier attests to a hardcoded genesis proof, not to "regional nodes haven't tampered with model weights". See `internal/zksnark_verifier.go`'s own doc comment and `proofs/cryptography.md`.

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

* [CERTIK_AUDIT_SUMMARY.md](docs/CERTIK_AUDIT_SUMMARY.md)

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
| **BFT Layer** | 🛡️ Model-checked (single tier) | [Theorem 1](./proofs/bft_resilience.md) — hierarchical composition **disproven**; see matrix row 1 |
| **Privacy Layer** | 🔒 Surrogate-verified | [Theorem 2](./proofs/differential_privacy.md) — list-based rational surrogate |
| **Liveness Layer** | ⚡ Model-verified | [Theorem 4](./internal/stragglers.md) — Chernoff surrogate on a probability model |
| **Integrity Layer** | ✅ Model-verified | [Theorem 5](./proofs/cryptography.md) — abstract constant-cost model, not a soundness proof |

## 🛡️ Sovereign Mohawk: Hierarchical Byzantine Safety Bounds

Traditional Federated Learning (FL) frameworks (e.g., Google TFF, Flower) are typically analyzed under honest-majority assumptions. The [Sovereign Mohawk Protocol](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto) tracks a compositional honest-majority theorem and separate concrete profile guards, rather than claiming a universal 80% Byzantine bound.

### 🔬 Technical Breakthroughs (Patent Pending)

#### 1. Hierarchical Recursive Filtering ($O(\log n)$)

Unlike "Star" topologies that process all nodes at a single central point, SMP uses a tree-based synthesis. By performing **local sanitization** at the cluster level, malicious gradients are trimmed before they can poison the global root.

* **The Result:** The current proof artifact captures a logarithmic routing-depth proxy and honest-majority composition assumptions; it does not prove a universal sublinear total-byte bound.

#### 2. Hardware-Rooted Identity (TPM Gating)

The system uses TPM-backed attestation metadata to support a
"One-Hardware-One-Vote" policy. **Scope caveat:** the TPM integration is a
stubbed/abstracted layer on some platforms (see `internal/tpm/` and
`results/go-live/evidence/`), and a hardware identity check raises the cost of
a Sybil attack rather than making it "logistically impossible" — an attacker
with access to sufficiently many distinct hardware identities, or to a
compromised attestation path, is not addressed by this control alone.

#### 3. zk-SNARK Integrity Proofs

The cost model in `Theorem5Cryptography.lean` is an **abstract
constant-operation model**: it shows that, under the model's assumptions, proof
size and verification cost do not grow with the number of participants. It is
**not** a soundness proof for Groth16, and it is **not** a measurement of the
production verifier. Separately, the deployed verifier
(`internal/zksnark_verifier.go`) checks Groth16 proofs against a fixed
`genesisVK` that is not derived from a circuit's trusted setup, so it does not
currently bind a proof to gradient or model-weight content.

### 📊 Competitive Comparison

| Metric | Industry Standard (Flower/TFF) | Sovereign Mohawk (SMP) |
| :--- | :--- | :--- |
| **BFT claim** | 33.3% (honest majority) | **No global bound.** Single-tier guard arithmetic is machine-checked; deterministic hierarchical composition is **disproven** (60% counterexample). A probabilistic Chernoff repair is proved for the i.i.d. Bernoulli committee-sampling model. |
| **Path depth** | $O(n)$ | $O(\log n)$ **path-depth proxy** (machine-checked); total bytes remain model-dependent |
| **Verification** | Trust-based | Abstract constant-cost **model**; deployed verifier checks against a fixed genesis VK |
| **Overhead** | ~40TB (at 10M nodes, naive) | 28MB (at 10M nodes) — **model-level** estimate from the Lean transport spec, not a measured deployment figure |
