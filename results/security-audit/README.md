# Security Audit Artifacts

Date: 2026-03-31
Project: Sovereign-Mohawk-Proto
Status: Initial audit handoff package ready

## Contents

- [Security audit handoff pack](./audit_handoff_certik_2026-03-31.md)
- [Security control-to-evidence matrix](./control_to_evidence_matrix_2026-03-31.md)
- [Auditor kickoff checklist](./auditor_kickoff_checklist_2026-03-31.md)
- [Audit baseline manifest (SHA-256)](./audit_baseline_manifest_2026-03-31.md)

## Quick Validation

Run from repository root:

```bash
sha256sum \
  results/go-live/evidence/security_audit_report_2026-03-26.md \
  results/go-live/evidence/security_audit_execution_plan_2026-03-26.md \
  results/go-live/attestations/security_audit.json
```

Expected checksums are documented in `audit_baseline_manifest_2026-03-31.md`.
