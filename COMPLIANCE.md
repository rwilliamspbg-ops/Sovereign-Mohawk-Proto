# EU AI Compliance Matrix (Articles 8-15)

This document maps Sovereign Mohawk controls to AI Act Articles 8-15 with implementation and test evidence pointers.

This engineering matrix is not legal advice.

## Scope

Target profile:

- high-risk and safety-adjacent deployments
- healthcare/geospatial-adjacent use contexts

Evidence model:

- Technical control implementation references
- Test and CI evidence references
- Operations/post-market evidence references

## Matrix: Articles 8-15

| Article | Requirement Summary | Technical Implementation | Test and Evidence Links |
| --- | --- | --- | --- |
| 8 | Risk management system | QMS and risk governance controls, release gates, and CAPA process | QMS_SYSTEM_MANUAL.md, TECHNICAL_DOCUMENTATION_FILE.md, RELEASE_CHECKLIST_v1.0.0_RC.md |
| 9 | Ongoing risk management process | Runtime liveness/Byzantine/privacy controls and incident escalation workflow | internal/aggregator.go, internal/rdp_accountant.go, OPERATIONS_RUNBOOK.md, test/tpm_test.go, test/rdp_accountant_test.go |
| 10 | Data and data governance | Privacy-by-design FL model updates, DP accounting, and bounded policy controls | internal/dp_config.go, internal/rdp_accountant.go, COMPLIANCE_MAPPING.md, test/rdp_accountant_test.go |
| 11 | Technical documentation | Structured TDF sections and conformity evidence index maintained in-repo | TECHNICAL_DOCUMENTATION_FILE.md, docs/tdf/TECHNICAL_FILE_TEMPLATE.md |
| 12 | Record-keeping / logging | Append-only tamper-evident utility ledger audit chain and exportable chained event bundles with explicit retention and minimum event fields for deployers | internal/token/ledger.go, scripts/export_tamper_evident_events.py, scripts/ci/check_tamper_evident_bundle.py, tests/scripts/ci/test_tamper_evident_bundle_e2e.py, POST_MARKET_MONITORING_AND_INCIDENT_REPORTING.md |
| 13 | Transparency and information to deployers | Deployment guides, runbook procedures, and policy defaults documented for operators | README.md, DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md, OPERATIONS_RUNBOOK.md |
| 14 | Human oversight | Explicit operator approvals, escalation paths, recovery drills, and runbooked interventions with oversight alert hooks | OPERATIONS_RUNBOOK.md, monitoring/prometheus/alerting-rules.yml, POST_MARKET_MONITORING_AND_INCIDENT_REPORTING.md, scripts/chaos_readiness_drill.sh |
| 15 | Accuracy, robustness, cybersecurity | Byzantine filtering, proof verification, secure transport policy, and supply-chain/security CI gates | internal/multikrum.go, internal/zksnark_verifier.go, internal/metrics/metrics.go, .github/workflows/security-supply-chain.yml, test/zksnark_verifier_test.go, test/accelerator_test.go |

## Required Event Auditability (Deployer-Facing)

The following key events are exported as tamper-evident chained records using scripts/export_tamper_evident_events.py:

- gradient aggregation event snapshot
- zk verification event snapshot
- Byzantine resilience event snapshot
- privacy budget configuration/spend guard snapshot

Minimum event granularity for deployers (high-risk profile):

- event timestamp (`observed_at`, UTC)
- event type and source (`event_type`, `source`)
- input context where relevant (metric query, policy source, or request metadata)
- output/result where relevant (metric response, success/failure outcome, chain status)
- human oversight action references where applicable (approval, deny, override, escalation)
- tamper-evident chain linkage (`prev_hash`, `hash` in chained file)

Minimum retention baseline (deployer guidance):

- retain tamper-evident bundle exports for at least 6 months for high-risk operations
- retain incident-associated bundles through full incident lifecycle and legal hold requirements
- retain release-signoff bundles with release evidence package for audit retrieval

Output bundle:

- events.ndjson
- events_chained.ndjson
- bundle_manifest.json
- tamper_evident_events_bundle.tar.gz

Validation path:

- `python3 scripts/ci/check_tamper_evident_bundle.py --bundle-dir <bundle-dir>`
- `python3 tests/scripts/ci/test_tamper_evident_bundle_e2e.py`

## Conformity Preparation Notes

- Conformity route and CE planning: CONFORMITY_ASSESSMENT_AND_CE_PATH.md
- Technical file template package: docs/tdf/TECHNICAL_FILE_TEMPLATE.md
- Early notified body engagement checklist: docs/tdf/NOTIFIED_BODY_EARLY_ENGAGEMENT.md

If targeting EU healthcare/geospatial high-risk deployment, engage notified body review early during architecture freeze rather than after release candidate.

## PQC Positioning (Differentiator)

Sovereign Mohawk includes production-facing migration controls that exceed baseline market posture:

- hybrid transport KEX mode support and policy enforcement
- XMSS identity path support and migration controls
- crypto-after-epoch cutover policy controls and observability

Pitch framing guidance:

- position as operational crypto-agility with measurable policy enforcement
- show evidence via policy metrics and migration gate artifacts
- tie roadmap to long-horizon cybersecurity expectations

## EU Regulatory Sandbox Strategy (by Aug 2026)

Recommended validation approach:

1. Select at least one Member State AI regulatory sandbox with relevant healthcare/geospatial profile.
2. Run constrained pilots using synthetic/de-identified datasets and strict monitoring thresholds.
3. Collect sandbox evidence package:
   - risk logs and mitigations
   - model and control performance deltas
   - incident/CAPA records
   - operator oversight decisions
4. Feed outcomes into TDF updates and conformity dossier revisions.

Operational artifacts should be archived under results/readiness/ and results/security-audit/ for assessor-ready retrieval.
