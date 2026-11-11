# Security Policy: Sovereign Mohawk

## 🛡️ Our Commitment
Sovereign Mohawk pairs an axiom-free Lean 4 formal development — in which every
claim carries a status label and a recorded scope — with zero-trust hardware
controls. Those formal results are machine-checked **about stated models and
hypotheses**, not about the deployed runtime, and the Go↔Lean correspondence is
empirical; per-claim status is in `proofs/FORMAL_TRACEABILITY_MATRIX.md`. No
system is perfect. We take security reports seriously and prioritize fixing
vulnerabilities that could compromise data sovereignty or model integrity.

## 🚀 Reporting a Vulnerability
**Do not open a public GitHub issue for security vulnerabilities.**

If you discover a bug that could lead to:
- Raw data leakage (SGP-001 violation)
- Proof-of-Contribution spoofing (zk-SNARK bypass)
- Unauthorized model poisoning (BFT failure)

Please report it privately via
- **Email:** architects@sovereignmap.network
- **GitHub Private Advisory:** [Open a Private Report](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/security/advisories/new)

### 📋 Please include
1. A brief description of the vulnerability.
2. Steps to reproduce (or a proof-of-concept script).
3. The potential impact on the mesh.

## 🎁 Security Rewards
Verified security researchers who discover critical flaws will receive:
- **Major Audit Points:** (250+ points toward the Incentive Tier).
- **Hall of Fame:** Permanent recognition on the [Project Dashboard](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/DASHBOARD.md).
- **Priority Access:** Early access to the mainnet governance council.

---
*Note: We follow a 90-day responsible disclosure window. We ask that you give us time to patch the vulnerability before sharing details publicly.
