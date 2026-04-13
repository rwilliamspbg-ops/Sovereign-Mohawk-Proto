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
- `loaded_1500node_stress_capture_2026-04-13.md` – Initial 40-cycle and 1500-node profile validation
- `extended_stress_200cycle_2026-04-13.md` – Extended 200-cycle sustained router load analysis
- `extended_stress_analysis_2026-04-13.json` – Raw metrics and calculations from extended stress test
- `scaled_swarm_benchmark_report_1500_2026-04-13.md`
- `v2_dashboard_validation_report.md`

### FedAvg Scaling Initiative (2026-04-13)

- `fedavg_scaling_enhancement_plan_2026-04-13.md` – Comprehensive 5-phase roadmap for pushing FedAvg limits to 5k–10k nodes
	- Phase 1: Instrumentation & metrics enhancement
	- Phase 2: Bottleneck mitigation (async/hierarchical aggregation, weighted trimming)
	- Phase 3: Large-scale test harness design
	- Phase 4: Benchmark extensions (variants, convergence curves)
	- Phase 5: 5k–10k node evaluation targets
	- Status update: async/semi-async controls, admission controls, and scale-gate validation are now implemented in code and captured in the current runtime evaluation artifacts.

- `fedavg_scaling_phase1_implementation_2026-04-13.md` – Phase 1 implementation complete
	- 13 new Prometheus metrics for FedAvg round execution, participation, stragglers, gradient flow
	- 10 observer functions for integration
	- Design rationale and usage examples
	- Integration roadmap
- `fedavg_10k_node_runtime_evaluation_2026-04-13.md` – Executed 10k-node profile validation run with timing-based scaling assessment and next optimization steps
### Session and attestation records

- `session_manifest.json`
- `tpm_*_commit_record.json`

## Maintenance policy

- Keep this directory append-only for auditability.
- Prefer generated outputs under `results/` for active CI artifacts.
- When adding a new captured artifact, include date/time and generator command in the file body where possible.
