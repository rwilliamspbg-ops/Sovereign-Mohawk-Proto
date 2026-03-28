# Capability-to-Dashboard Verification Matrix

Release evidence artifact mapping protocol capabilities to observable dashboard panels.

| Capability | Source | Metric / Recording Rule | Dashboard | Verification Panel |
| --- | --- | --- | --- | --- |
| PQC transport enforcement | MOHAWK_TRANSPORT_KEX_MODE + runtime mode metrics | mohawk_pqc_policy_mode_info{policy="transport_kex"} | v2-12-security-pqc-compliance.json | Panel: PQC Mode and Epoch Controls |
| TPM identity signature mode | MOHAWK_TPM_IDENTITY_SIG_MODE | mohawk_pqc_policy_mode_info{policy="tpm_identity_sig_mode"} | v2-12-security-pqc-compliance.json | Panel: PQC Mode and Epoch Controls |
| Migration enable/lock/epoch controls | MOHAWK_PQC_MIGRATION_* | mohawk_pqc_policy_enabled + mohawk_pqc_policy_epoch_unix | v2-12-security-pqc-compliance.json | Panels: PQC Enforcement Composite, PQC Policy States |
| Migration API reliability | Orchestrator /ledger/migration/* handlers | mohawk_migration_requests_total + mohawk_migration_request_latency_ms | v2-22-eng-migration-control-plane.json | Panels: Requests by Endpoint, Latency by Endpoint |
| Migration signature path integrity | Dual-crypto vs legacy control migration flow | mohawk_migration_signature_path_total | v2-22-eng-migration-control-plane.json | Panel: Signature Path Reliability |
| Admin endpoint auth hardening | Bearer token enforcement for protected endpoints | mohawk_authz_denials_total | v2-12-security-pqc-compliance.json, v2-22-eng-migration-control-plane.json | Panels: Authz Denials by Endpoint |
| Thinker-clause governance policy | capabilities.json thinker_clauses | mohawk_thinker_clause_config | v2-12-security-pqc-compliance.json | Panel: Thinker Manual Review Threshold |
| Proof and bridge performance SLOs | Runtime proof/bridge verification paths | mohawk:proof_latency_ms:p95, mohawk:bridge_latency_ms:p95 | v2-10-ops-overview.json, v2-20-eng-latency-drilldown.json | Panels: Latency Percentiles, Proof/Bridge Quantile Drilldown |
| Byzantine and liveness resilience | Consensus + straggler runtime conditions | mohawk_consensus_honest_ratio, mohawk:gradient_submit:failure_rate_5m | byzantine-resilience-theorem1.json, v2-11-ops-incidents.json | Panels: theorem threshold and incident timeline |

## Validation Notes

1. Ensure Prometheus rules are loaded and dashboard JSONs provisioned.
2. Validate each listed metric has non-empty data during synthetic or live traffic.
3. Treat missing series for critical capabilities as release blockers until resolved.

