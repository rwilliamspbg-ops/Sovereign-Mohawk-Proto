# Security Audit Execution Plan (2026-03-26)

## Scope

- Runtime control plane (`cmd/orchestrator`, `internal/network`, `internal/tpm`)
- Python bridge and API surface (`internal/pyapi`, `sdk/python/mohawk`)
- Settlement and bridge flows (`internal/bridge`, `internal/token`)

## Required Deliverables

- Third-party audit report (full findings with severities)
- Remediation matrix (owner, ETA, status)
- Re-test confirmation for critical/high findings

## Acceptance Criteria

- Zero unresolved critical findings
- Any high findings must be remediated or have explicit risk sign-off
- Final audit sign-off attached to `results/go-live/attestations/security_audit.json`
