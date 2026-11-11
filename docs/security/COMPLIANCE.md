# Compliance — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.
**Note**: Engineering matrix, not legal advice.

## 1. Scope

Regulatory alignment tracking for the Sovereign Mohawk runtime. The detailed
EU AI Act (Articles 8-15) control matrix lives in the repository root:
[`COMPLIANCE.md`](../../COMPLIANCE.md). This document is the security-set
index and points to the underlying evidence.

## 2. Frameworks addressed

- **EU AI Act (high-risk profile)**: full matrix in root `COMPLIANCE.md`,
  with technical control and test evidence pointers per article.
- **FedRAMP-style controls**: `docs/COMPLIANCE_MAPPING.md`,
  `docs/CERTIFICATE_SECURITY_INFRA.md`.
- **FIPS profile scope**: `docs/FIPS_PROFILE_SCOPE.md`.
- **DoD alignment**: `docs/DoD_Alignment_Addendum.md`.
- **Conformity assessment / CE path**: `docs/CONFORMITY_ASSESSMENT_AND_CE_PATH.md`.
- **QMS system manual**: `docs/QMS_SYSTEM_MANUAL.md`.
- **Post-market monitoring**: `docs/POST_MARKET_MONITORING_AND_INCIDENT_REPORTING.md`.

## 3. Evidence model

Every compliance claim maps to:
- Technical control implementation (`internal/`).
- Test and CI evidence (`.github/workflows/`, `test/`).
- Operations / post-market evidence (`results/`, `docs/OPERATIONS_RUNBOOK.md`).

## 4. Key control families

- **Risk management**: QMS + risk governance + release gates (Article 8).
- **Ongoing risk management**: runtime liveness, Byzantine, privacy controls,
  incident escalation (Article 9).
- **Data governance**: DP accounting, bounded policy controls (Article 10).
- **Technical documentation**: structured TDF sections (Article 11).
- **Record-keeping**: tamper-evident chained event bundles with retention
  (Article 12) — `internal/token/ledger.go`,
  `scripts/export_tamper_evident_events.py`.
- **Transparency**: deployment guides, runbooks, policy defaults (Article 13).
- **Human oversight**: operator approvals, escalation, recovery drills,
  oversight alert hooks (Article 14).
- **Accuracy/robustness/cybersecurity**: Byzantine filtering, proof
  verification, secure transport, supply-chain CI gates (Article 15).

## 5. Formal verification as compliance evidence

- Lean 4 proofs + refinement bridges provide **machine-checked evidence about
  stated models** for the BFT, privacy, and ZK claims cited above — not
  evidence about the deployed runtime. Each claim carries a status label and a
  recorded scope in `proofs/FORMAL_TRACEABILITY_MATRIX.md`; several are
  surrogates or empirical correspondences, and the deterministic hierarchical
  BFT composition claim is disproven.
- CI gates (`verify-lean-formalization`, `proof-traceability`) keep claims
  honest.
- External audit scope: `docs/EXTERNAL_AUDIT_SCOPE.md`.

## 6. Cross-references

- Root compliance matrix: `COMPLIANCE.md`
- Compliance mapping: `docs/COMPLIANCE_MAPPING.md`
- Incident response: `docs/security/INCIDENT_RESPONSE.md`
- Threat model: `docs/security/THREAT_MODEL.md`
- Security overview: `docs/security/SECURITY.md`
