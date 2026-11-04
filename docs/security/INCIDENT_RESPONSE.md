# Incident Response Playbook — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.
**Audience**: Maintainers, on-call operators, external auditors.
**Owner**: @rwilliamspbg-ops (security contact per root `SECURITY.md`).

This playbook is the operational counterpart to `docs/security/THREAT_MODEL.md`
and `docs/EXTERNAL_AUDIT_SCOPE.md`. Every procedure references a real script,
workflow, or evidence artifact — nothing here is aspirational without an
explicit "open item" marker.

---

## 1. Severity definitions

| Severity | Definition | Examples | Response target |
|---|---|---|---|
| **Critical** | Loss of integrity of the aggregate, or bypass of a formal guard | ZK verifier bypass, TPM identity spoofing accepted, Byzantine quorum exceeded without detection | 1 hour triage, 24 h containment |
| **High** | Confidentiality breach or sustained availability loss | RDP budget exceeded silently, PQC KEX failure across a tier, aggregator crash loop | 4 hours triage, 72 h fix |
| **Medium** | Degraded correctness or partial outage | Straggler timeout storm, single node attestation failure, dashboard data gap | 1 business day |
| **Low** | Cosmetic / non-exploitable | Log noise, metric gap, doc drift | Next release |

Assets in scope: orchestrator control plane, TPM attestation path
(`internal/tpm/`), ZK verifier (`internal/zksnark_circuit_verifier.go`,
`internal/zksnark_verifier.go`), aggregation path (`internal/batch/aggregator.go`,
`internal/federation/`), PQC transport (`internal/crypto/`, `internal/transport/`),
formal proof tree (`proofs/`).

## 2. Detection sources

- **Prometheus/Grafana**: alerts defined in `monitoring/` (scrape configs,
  dashboards). Key signals: proof verification latency, aggregation latency,
  attestation success rate, straggler timeout rate.
- **Readiness/chaos gates**: `.github/workflows/mainnet-readiness-gate.yml`,
  `mainnet-chaos-gate.yml`, chaos-rehearsal evidence in `results/go-live/evidence/`.
- **CI security**: `security-scanning.yml`, `security-supply-chain.yml`,
  `codeql-analysis.yml`, `govulncheck`, `trivy-fs`.
- **Formal drift**: `verify-lean-formalization`, `proof-traceability`,
  `check_theorem_runtime_consistency.py` — a failure here means a runtime
  formula no longer matches its Lean claim.
- **External reports**: GitHub Security Advisories (private reporting enabled)
  or email to maintainer.

## 3. Roles and escalation

- **Incident commander**: @rwilliamspbg-ops.
- **Security contact**: per root `SECURITY.md` (email maintainer directly;
  no public issue for suspected vulnerabilities).
- **External auditor**: if engaged, per `docs/EXTERNAL_AUDIT_SCOPE.md`.
- Escalation: if the maintainer is unavailable > 24 h, post to the repo's
  GitHub Discussion (if enabled) or open a private advisory.

## 4. Playbooks

### 4.1 Compromised node / Byzantine gradient flood

**Signals**: aggregation rejects > threshold of updates; Multi-Krum selects
outliers; `internal/federation/aggregate_test.go` invariant violated in prod.

**Containment**:
1. Identify offending node IDs from aggregator logs (`internal/batch/aggregator.go`
   emits per-round verification results).
2. Revoke the node's TPM-backed identity (see 4.2).
3. Lower the committee size / raise `f` guard temporarily:
   `internal/hbft/simulator.go` enforces `NodesPerCommittee > 2*f+2`;
   do not bypass this check.
4. Re-run the round with the node excluded.

**Eradication**: rotate the node's credentials; re-attest.

**Recovery**: `make go-live-gate` or `scripts/genesis-launch.sh` to re-bootstrap.

### 4.2 Failed TPM attestation / identity spoofing

**Signals**: `internal/tpm/verify.go` returns non-nil error; attestation
success rate drops.

**Containment**:
1. Check `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK` is NOT set in production
   (insecure fallback must stay off — see root `SECURITY.md`).
2. Inspect TPM lease state (`internal/tpm/tpm_lease_test.go` documents the
   lease lifecycle).
3. Re-run attestation: `scripts/genesis-launch.sh` regenerates identity.

**Open item**: TPM attestation is hardware-backed only on Linux with a real
TPM (`internal/tpm/hardware_backend_linux_has_tpm.go`); other platforms use
the default backend. Treat non-Linux attestation as lower assurance.

### 4.3 ZK verifier bypass or proof forgery suspicion

**Signals**: `VerifyDataCommitmentProof` returns true for a tampered proof
(`test/zksnark_circuit_verifier_test.go` covers this); or
`check_theorem_runtime_consistency.py` fails (runtime formula drifted from
Lean claim).

**Containment**:
1. Disable the circuit path: unset the commitment hex so callers fall back to
   the legacy path (`internal/hybrid/verifier.go` routes on commitment presence).
2. Verify the verification key origin: it must come from `ensureDataCommitmentSetup`
   (MPC flow), not a fixed identity. `genesisVK` in `internal/zksnark_verifier.go`
   is a fixed identity with no circuit — do not treat it as attesting to data.
3. Re-run `make audit-ready-check` and `go test ./test/ -run DataCommitment`.

**Open item**: the MPC setup is simulated in-process (N=3 contributors in one
goroutine), not a distributed ceremony. Treat `dataCommitmentVK` as a
development/demo key.

### 4.4 PQC KEX / hybrid transport failure

**Signals**: QUIC UDP-buffer instability; TLS handshake failures.

**Containment**:
1. Set `MOHAWK_DISABLE_QUIC=true` to fall back to authenticated TCP transport
   (documented in root `SECURITY.md`).
2. Check `internal/crypto/` and `internal/transport/` for the hybrid KEX
   (x25519-mlkem768).
3. Verify cert validity and rotation schedule.

### 4.5 Supply-chain / dependency compromise

**Signals**: `govulncheck`, `trivy-fs`, or `dependency-review` CI failure;
unexpected change in `go.sum` / `package-lock`.

**Containment**:
1. Pin and re-verify: `go mod verify`, `npm audit`.
2. Re-run `security-supply-chain.yml`.
3. Check SLSA provenance on the affected release artifact
   (`docs/AUDITOR_QUICK_REFERENCE.md` Phase 3).
4. If a release is compromised, yank it and re-tag.

### 4.6 Formal proof drift

**Signals**: `verify-lean-formalization` or `verify-lean-formalizations` CI
failure; `check_theorem_runtime_consistency.py` reports a missing pattern.

**Containment**:
1. Run `make audit-ready-check` locally.
2. If a theorem changed, update `proofs/theorem_claims.json` runtime targets
   to match — never weaken a claim to make CI pass without review.
3. Open an issue labeled `formal-review`.

## 5. Evidence collection and preservation

- Preserve CI artifacts (formal-proof-report, go-test, chaos reports) — CI
  uploads them with 7-day retention.
- Save relevant logs under `results/` following the existing naming convention
  (`results/go-live/evidence/`).
- For a confirmed incident, create `results/security-incidents/<date>-<slug>.md`
  using the post-incident template below.

## 6. Post-incident review template

```markdown
# Incident: <slug> — <date>

## Summary
## Severity
## Timeline
## Root cause
## Containment actions taken
## Evidence links (CI runs, logs, commits)
## Corrective actions (with owners and dates)
## Formal-claim impact (did any theorem need updating?)
```

## 7. Communication

- Vulnerability reports: GitHub Security Advisories (private reporting enabled)
  or email to maintainer. Do NOT open a public issue for a suspected vuln.
- Coordinated disclosure: 48-hour initial response target (per root `SECURITY.md`).
- Public post-mortem: publish under `results/security-incidents/` and link from
  `AUDITS.md` if an external reviewer was involved.

## 8. Cross-references

- Threat model: `docs/security/THREAT_MODEL.md`
- Supply chain: `docs/security/SUPPLY_CHAIN_SECURITY.md`
- Compliance: `docs/security/COMPLIANCE.md`
- External audit scope: `docs/EXTERNAL_AUDIT_SCOPE.md`
- Auditor quick reference: `docs/AUDITOR_QUICK_REFERENCE.md`
- Root security policy: `SECURITY.md`
