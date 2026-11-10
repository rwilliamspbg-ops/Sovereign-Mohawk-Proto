# Threat Model — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.
**Audience**: Security reviewers, external auditors, contributors.

This document expands the high-level threat model in root `SECURITY.md` into a
STRIDE-style analysis of the four-tier federation, transport, attestation, and
aggregation paths. It states explicitly what the Lean formal artifacts do and
do not cover.

## 1. System under analysis

Tiers (L1 Edge to L2 Regional to L3 Continental to L4 Global), with a control
plane (orchestrator) and monitoring (Prometheus/Grafana). See
`internal/federation/` for the tier logic.

Key components:
- **Aggregation**: `internal/federation/`, `internal/batch/aggregator.go`,
  `internal/multikrum*` (Multi-Krum filtering).
- **Transport**: `internal/transport/`, `internal/crypto/` (PQC hybrid KEX
  x25519-mlkem768, MRC multi-path spraying).
- **Attestation**: `internal/tpm/` (TPM-backed identity, XMSS).
- **ZK**: `internal/zksnark_verifier.go` (legacy genesisVK),
  `internal/zksnark_circuit_verifier.go` (circuit-derived VK + MPC setup).
- **Privacy**: `internal/rdp_accountant.go` (RDP, epsilon = 2.0 budget).
- **Formal proofs**: `proofs/` (Lean 4).

## 2. STRIDE analysis

### 2.1 Spoofing

| Threat | Mitigation | Residual / open |
|---|---|---|
| Node identity spoofing | TPM-backed attestation (`internal/tpm/`); XMSS identity | Hardware TPM only on Linux (`hardware_backend_linux_has_tpm.go`); default backend elsewhere = lower assurance |
| ZK proof forgery | Groth16 over MiMC preimage circuit (`zksnark_circuit_verifier.go`) | VK is from an in-process MPC simulation, not a distributed ceremony |
| Credential replay | mTLS + nonce in transport | Verify cert rotation schedule (open: documented but not automated) |

### 2.2 Tampering

| Threat | Mitigation | Residual |
|---|---|---|
| Gradient poisoning / model backdoor | Multi-Krum filtering (`internal/multikrum*`); Byzantine guard `n > 2f+2` (`internal/hbft/simulator.go`) | Single-tier Multi-Krum is formalized; hierarchical composition is a surrogate |
| Aggregate tampering in transit | MRC multi-path spraying + authenticated transport | MRC provides availability, not confidentiality beyond TLS |
| Tampered proof bytes | `VerifyDataCommitmentProof` rejects (tested in `test/zksnark_circuit_verifier_test.go`) | none |

### 2.3 Repudiation

| Threat | Mitigation |
|---|---|
| Node denies sending a gradient | TPM-signed attestation + audit logs |
| Aggregator denies a round | Evidence artifacts under `results/` + CI gates |

### 2.4 Information disclosure

| Threat | Mitigation | Residual |
|---|---|---|
| Membership inference on training data | RDP accountant enforces epsilon = 2.0 (`internal/rdp_accountant.go`) | RDP is an accounting surrogate; not a full DP proof of the aggregation |
| Gradient leakage across tiers | Tier isolation + transport encryption | Cross-tier metadata may leak round counts |
| ZK proof reveals preimage | Circuit proves knowledge only; commitment is public | Commitment = MiMC(preimage); preimage privacy holds under MiMC collision resistance (axiomatized) |

### 2.5 Denial of service

| Threat | Mitigation | Residual |
|---|---|---|
| Straggler sabotage (intentional timeouts) | Straggler handling in federation (`internal/federation/`); Theorem 4 | Timeout thresholds are config-driven; no formal bound on worst-case delay |
| QUIC UDP-buffer instability | `MOHAWK_DISABLE_QUIC=true` fallback to TCP | Documented but manual |
| Byzantine node flood | Byzantine guard + committee sizing | Requires `NodesPerCommittee > 2*f+2`; misconfiguration can panic (tested in `hbft/simulator_test.go`) |

### 2.6 Elevation of privilege

| Threat | Mitigation |
|---|---|
| Insecure verifier fallback | Fail-closed by default; `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK` must be explicitly set (CI/dev only) |
| Privilege escalation via orchestrator | RBAC / auth layer (`internal/auth/`); see `docs/AUTH_LAYER_IMPLEMENTATION_GUIDE.md` |

## 3. What the Lean formal artifacts cover (and do not)

Covered (see `proofs/FORMAL_TRACEABILITY_MATRIX.md` and `proofs/theorem_claims.json`):
- BFT resilience (surrogate model; `2*f < n` spec, `n > 2*f+2` impl bridge).
- RDP privacy accounting (composition + budget).
- UF-CMA Ed25519 reduction (via discrete-log; axioms load-bearing).
- ZK circuit soundness (MiMC preimage knowledge; abstract cost model).
- Convergence / straggler refinement bridges.
- Multi-Krum single-tier selection.

NOT covered (honest scope limits):
- Full Groth16 succinctness/soundness/q-SDH (Mathlib lacks pairing machinery).
- Hierarchical BFT composition (surrogate; single-tier only).
- Real IEEE-754 floating point (axiomatized ordering; see `Refinement/MultiKrum.lean`).
- Per-round gradient commitment wiring (caller must supply `Aggregator.GradientCommitment`).
- Production MPC ceremony (in-process simulation only).

## 4. Trust boundaries

1. Node to Regional aggregator: TPM identity + mTLS + gradient commitment.
2. Regional to Continental to Global: authenticated RPC + Byzantine guard at each tier.
3. Aggregator to ZK verifier: commitment hex routes to circuit path; absent implies legacy genesisVK path (fixed identity, no data binding).
4. Operator to cluster: RBAC + audit logs; no direct DB access assumed.

## 5. Out of scope for this threat model

- Physical security of nodes.
- Side-channel attacks on TPM or ZK prover.
- Social engineering of operators.
- Upstream vulnerabilities in Mathlib / gnark / Go stdlib (tracked via dependabot/govulncheck).

## 6. Cross-references

- Incident response: `docs/security/INCIDENT_RESPONSE.md`
- Supply chain: `docs/security/SUPPLY_CHAIN_SECURITY.md`
- Compliance: `docs/security/COMPLIANCE.md`
- External audit scope: `docs/EXTERNAL_AUDIT_SCOPE.md`
- Root security policy: `SECURITY.md`
- Formal traceability: `proofs/FORMAL_TRACEABILITY_MATRIX.md`

## TEE backend status (2026-11-09)

- Availability probes for SGX, SEV-SNP, and TrustZone now inspect real
  `/dev` nodes instead of unconditionally returning false.
- Enclave creation, attestation, and protected aggregation remain
  unimplemented; providers return `ErrNotAvailable` (fail-closed).
- No TEE backend is currently used to protect aggregation in production.
- Simulation mode (`SimulatedProvider`) remains the CI and development path.
