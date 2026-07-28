# Conformity Assessment and CE Path

This document provides a practical conformity workflow for high-risk deployment contexts, including medical-adjacent scenarios.

This document is not legal advice. Confirm obligations with qualified counsel and applicable notified bodies.

## Goal

Define a repeatable process to determine when internal assessment is sufficient and when third-party assessment is required, then prepare CE-related evidence artifacts where applicable.

## Scope Triggers

Assess this path when the system is intended for:

- high-risk operational decisions
- healthcare or oncology-adjacent workflows
- regulated environments requiring formal conformity evidence

## Assessment Decision Workflow

1. Define intended purpose and deployment context
2. Perform risk classification against applicable regulatory framework
3. Determine conformity route:
   - internal assessment route
   - third-party/notified-body route
4. Build conformity evidence package
5. Approve release only after route-specific criteria are met

## Internal Assessment Package (Minimum)

- technical documentation file completeness check
- risk management file and residual risk approval
- verification and validation evidence bundle
- cybersecurity and incident response evidence
- post-market monitoring plan signoff

## Third-Party Assessment Package (Minimum)

- all internal package items
- assessor-facing summary dossier
- traceability matrix with requirement mappings
- design and testing evidence export set
- issue and CAPA log extracts

## CE-Related Readiness Checklist

- intended purpose statement finalized
- risk classification approved
- conformity route documented
- declaration draft prepared
- technical file completeness verified
- residual risk and benefit-risk conclusion approved
- post-market monitoring and incident workflow approved
- registration prerequisites checklist complete

## Release Gates for High-Risk Profiles

Do not release for high-risk use until:

- conformity route decision approved by designated owner
- all required evidence linked in release package
- open major findings are closed or accepted with documented rationale

## Artifact Locations

- results/security-audit/
- results/go-live/
- results/metrics/
- RELEASE_CHECKLIST_v1.0.0_RC.md

## Ownership

- Compliance Lead: conformity route and dossier quality
- Engineering Lead: technical evidence correctness
- Security Lead: cybersecurity control evidence
- Release Manager: release block enforcement
