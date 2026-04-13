# Captured Artifacts Index

This directory stores point-in-time evidence captured during sprint execution.

## Layout intent

- Benchmark evidence: performance and microbenchmark comparison outputs.
- Sprint reports: narrative summaries and execution manifests.
- TPM and session records: attestation and stress run commit records.

## File categories

### Benchmark evidence

- `fedavg_benchmark_compare.md`
- `bridge_compression_benchmark_compare.md`
- `bridge_compression_speedup_trend_2026-04-13.md`
- `release_performance_evidence.md`
- `500node_scale_test_manifest.json`

### Sprint and operational reports

- `performance_improvement_report.md`
- `stress_metrics_capture_10m.md`
- `loaded_1500node_stress_capture_2026-04-13.md`
- `scaled_swarm_benchmark_report_1500_2026-04-13.md`
- `v2_dashboard_validation_report.md`

### Session and attestation records

- `session_manifest.json`
- `tpm_*_commit_record.json`

## Maintenance policy

- Keep this directory append-only for auditability.
- Prefer generated outputs under `results/` for active CI artifacts.
- When adding a new captured artifact, include date/time and generator command in the file body where possible.
