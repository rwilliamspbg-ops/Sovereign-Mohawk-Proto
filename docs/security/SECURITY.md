# Security Overview — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

This document is the index for the security documentation set. The canonical
security policy (vulnerability reporting, supported versions) lives in the
repository root: [`SECURITY.md`](../../SECURITY.md).

## 1. Security documentation map

| Document | Purpose |
|---|---|
| `docs/security/THREAT_MODEL.md` | STRIDE analysis of tiers, transport, attestation, aggregation |
| `docs/security/INCIDENT_RESPONSE.md` | Severity, playbooks, evidence, post-incident template |
| `docs/security/SUPPLY_CHAIN_SECURITY.md` | Artifact signing, SLSA, in-toto, dependency hygiene |
| `docs/security/COMPLIANCE.md` | Regulatory alignment (EU AI Act, FedRAMP-style) |
| `docs/EXTERNAL_AUDIT_SCOPE.md` | External audit scope and axiom inventory |
| `docs/AUDITOR_QUICK_REFERENCE.md` | Auditor verification procedures |
| `SECURITY.md` (root) | Vulnerability reporting policy, threat model summary, runtime hardening notes |

## 2. Cryptographic primitives in use

- **Transport KEX**: hybrid x25519-mlkem768 (PQC). See `internal/crypto/`,
  `internal/transport/`. Badge: "PQC Transport x25519-mlkem768-hybrid".
- **Identity / attestation**: TPM-backed, XMSS. `internal/tpm/`. Badge:
  "TPM Identity XMSS Enforced".
- **ZK**: Groth16 over BN254, MiMC circuit. Two paths:
  - Legacy: `internal/zksnark_verifier.go` (genesisVK — fixed identity, no
    circuit). Do not treat as attesting to data.
  - Circuit: `internal/zksnark_circuit_verifier.go` (real circuit-derived VK
    from an MPC trusted setup). Treat as development/demo key (in-process
    simulation).
- **Privacy accounting**: RDP, epsilon = 2.0 budget. `internal/rdp_accountant.go`.
- **Byzantine filtering**: Multi-Krum, guard `n > 2f+2`.
  `internal/hbft/simulator.go`, `internal/multikrum*`.

## 3. Runtime hardening (as of Apr 2026)

- Verifier boot is fail-closed by default: node-agent startup fails when the
  configured verifier module is missing/invalid.
- Insecure verifier fallback is explicit and non-default:
  `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true` (CI/dev only).
- Constrained-host transport profile: `MOHAWK_DISABLE_QUIC=true` falls back
  to authenticated TCP.

## 4. Formal verification status

- Lean 4 proofs under `proofs/`. CI: `verify-lean-formalization`,
  `verify-lean-formalizations`, `proof-traceability`, `proof-quality-checks`.
- One-command check: `make audit-ready-check`.
- Axiom inventory: `docs/EXTERNAL_AUDIT_SCOPE.md` section 6 (16 axioms,
  all documented; 0 `sorry`).

## 5. Cross-references

- Root security policy: `SECURITY.md`
- Threat model: `docs/security/THREAT_MODEL.md`
- Incident response: `docs/security/INCIDENT_RESPONSE.md`
- Supply chain: `docs/security/SUPPLY_CHAIN_SECURITY.md`
- Compliance: `docs/security/COMPLIANCE.md`
