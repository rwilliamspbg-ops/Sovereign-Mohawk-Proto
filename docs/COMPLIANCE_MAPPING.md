# Compliance Mapping (HIPAA / GDPR)

This document translates core Sovereign-Mohawk controls into healthcare-oriented legal and operational controls.

It is an engineering mapping aid, not legal advice.

## HIPAA Technical Safeguards Mapping

| Sovereign-Mohawk Feature | HIPAA Reference | Implementation Mapping |
| --- | --- | --- |
| mTLS control plane + TPM-attested identity (`/attest`, TPM quote verification) | 45 CFR 164.312(d) Person or Entity Authentication | Device identity and quote-backed attestation establish authenticated node identity before trust decisions. |
| API token + role-gated ledger/bridge/hybrid endpoints | 45 CFR 164.312(a)(1) Access Control | Role-based controls and token enforcement restrict sensitive utility and migration operations. |
| Audit chain on utility ledger (`audit.jsonl`) | 45 CFR 164.312(b) Audit Controls | Immutable transaction/audit trails support review of security-relevant actions and administrative operations. |
| Transport PQC hybrid KEX policy (`x25519-mlkem768-hybrid`) | 45 CFR 164.312(e)(1) Transmission Security | Encrypted transport with modern KEX policy protects ePHI-bearing model updates in transit. |
| Differential privacy and bounded minority retention controls | 45 CFR 164.312(c)(1) Integrity | Reduces sensitive signal leakage and helps preserve data integrity constraints during aggregation. |

## GDPR Security Mapping

| Sovereign-Mohawk Feature | GDPR Reference | Implementation Mapping |
| --- | --- | --- |
| Differential privacy and local gradient controls | Article 25 Data Protection by Design and by Default | Privacy-preserving defaults reduce exposure of raw personal data in federated flows. |
| TPM attestation and cryptographic migration controls | Article 32 Security of Processing | Cryptographic controls, attestation, and key policy enforcement provide state-of-the-art safeguards. |
| Audit evidence and runbooked incident workflow | Articles 5(2), 24 Accountability | Captured readiness, chaos, and attestation artifacts support demonstrable operational accountability. |
| Role-scoped operational endpoints | Article 32(4) Access Governance | Limits processing actions to authorized operators and service roles. |

## Thinker Clauses: Legal Translation

Thinker Clauses in `capabilities.json` can be represented to compliance teams as:

- Fairness and minority-signal preservation controls.
- Human-review escalation when outlier confidence exceeds policy caps.
- Governance metadata enabling documented recourse decisions.

Reference schema:

- `proofs/THINKER_CLAUSES_CAPABILITIES.md`

## Evidence to Keep for Audits

For each release or major policy change, retain:

1. `results/go-live/go-live-gate-report.json`
2. `results/go-live/strict-host-evidence.md`
3. `results/go-live/evidence/tpm_attestation_*.md`
4. `results/readiness/readiness-report.json`
5. `chaos-reports/*-summary.json`

These files give auditors concrete artifacts for control effectiveness reviews.

## Artifact Retention Policy

Minimum operational guidance:

1. Weekly and daily forensics artifacts:
   - Retain at least 30 days for trend and incident reconstruction.
2. Go-live and release evidence bundles:
   - Retain at least 1 year (or longer if contractual/regulatory controls require it).
3. Incident-associated artifacts:
   - Retain for full incident lifecycle and legal hold requirements.

Recommended controls:

- Store final evidence in immutable/object-lock capable storage.
- Preserve checksums and generation timestamps.
- Link archived artifact URIs in incident tickets and release records.
