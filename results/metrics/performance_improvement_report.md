# 3-Node Metrics Capture & Improvement Report

Generated: 2026-03-25

## Captured Artifacts

- `results/metrics/prom_targets.json`
- `results/metrics/prom_metric_names.json`
- `results/metrics/mohawk_metric_names.txt`
- `results/metrics/mohawk_series_values.json`
- `results/metrics/key_prom_queries.json`
- `results/metrics/orchestrator_metrics.prom`
- `results/metrics/tpm_metrics.prom`
- `results/metrics/container_stats.tsv`
- `results/metrics/log_error_counts.txt`
- `results/metrics/udp_buffer_warning_counts.tsv`
- `results/metrics/sprint1_node_agents_up.json`
- `results/metrics/sprint1_accel_latency_count.json`
- `results/metrics/sprint1_proof_verifications_total.json`
- `results/metrics/sprint1_pyapi_metrics.prom`
- `results/metrics/sprint1_pyapi_selected_metrics.txt`
- `results/metrics/sprint1_pyapi_traffic_results.json`
- `results/metrics/sprint1_post_pyapi_up.json`
- `results/metrics/sprint1_post_pyapi_bridge_latency_count.json`
- `results/metrics/sprint1_post_pyapi_bridge_transfers_total.json`
- `results/metrics/sprint1_post_pyapi_hybrid_proof_total.json`

## Current State (Observed)

- Prometheus targets healthy:
  - `orchestrator:9091` = up
  - `tpm-metrics:9102` = up
   - `node-agent-1:9100` = up
   - `node-agent-2:9100` = up
   - `node-agent-3:9100` = up
   - `pyapi-metrics-exporter:9104` = up
- Total metric names in Prometheus: `119`
- MOHAWK metric names present: `12`
- Active MOHAWK series observed: `22`
- Utility coin series all currently `0` (expected under low transaction load)
- TPM verification counter increments (`mohawk_tpm_verifications_total` observed at non-zero value)
- Container resource footprint is low (node agents ~9-11MiB each, orchestrator ~17MiB)
- UDP socket buffer warning appears once per node-agent at startup
- Node-agent accelerator/proof telemetry now present in Prometheus:
   - `mohawk_accelerator_op_latency_ms_count` (gradient_submit, proof_verify)
   - `mohawk_proof_verifications_total{scheme="groth16"}`
- Synthetic pyapi traffic confirms bridge/hybrid telemetry emission in-process:
   - `mohawk_bridge_transfers_total{source_chain="ethereum",target_chain="polygon",result="success"} = 8`
   - `mohawk_bridge_transfer_latency_ms_count{...} = 8`
   - `mohawk_proof_verifications_total{scheme="hybrid",result="failure"} = 8`
- Central Prometheus now observes bridge/hybrid telemetry via `pyapi-exporter` scrape target:
   - `mohawk_bridge_transfer_latency_ms_count{job="pyapi-exporter"} > 0`
   - `mohawk_bridge_transfers_total{job="pyapi-exporter"} > 0`
   - `mohawk_proof_verifications_total{job="pyapi-exporter",scheme="hybrid"} > 0`

## FedAvg Scaling Progress

- FedAvg runtime instrumentation now covers round duration, participation, stragglers, gradient throughput, and latency quantiles.
- Semi-async, hierarchical, weighted-trim, and adaptive-quorum controls are implemented behind the aggregation API and exercised by regression tests.
- 10k-node runtime smoke evaluation is captured in `captured_artifacts/fedavg_10k_node_runtime_evaluation_2026-04-13.md`.
- FedAvg scale-gate validation is available locally via `results/metrics/fedavg_scale_gate_validation.md` and `results/metrics/fedavg_scale_gate_validation.json`.
- Macro benchmark output is published in `test-results/swarm-runtime/scaled_swarm_benchmark_report.md` and `.json`.

## Gaps / Bottlenecks

1. **Accelerator telemetry gap**
   - `mohawk_accelerator_ops_total` not present in current scrape results.
   - `mohawk_gradient_compression_ratio_*` not present in current scrape results.
   - Impact: cannot quantify auto-tuner effectiveness or backend utilization.

2. **Bridge/hybrid readiness policy recently upgraded to required**
   - Readiness now requires bridge/proof/hybrid metric series presence and non-negative counters.
   - Follow-up: add explicit minimum activity thresholds for traffic-enabled validation runs.

4. **Kernel UDP buffer tuning needed**
   - Warning count: one per node-agent startup (`failed to sufficiently increase receive buffer size`).
   - Impact: potential QUIC throughput/packet-loss penalties under higher traffic.

5. **Metrics scope duplication risk**
   - Utility metrics appear on both orchestrator and tpm-metrics targets with same zero values.
   - Impact: potential confusion/overcount risk when dashboards aggregate without `instance` labels.

## Recommended Improvements (Priority Order)

### P0 (Immediate)

1. **Guarantee accelerator/proof/bridge metrics emission in hot paths**
   - Ensure every path that performs compression, proof verify, bridge transfer records a metric regardless of success/failure.
   - Add counter + latency histogram pairs:
     - `mohawk_proof_verify_total{result,...}`
     - `mohawk_proof_verify_latency_ms_bucket`
     - `mohawk_bridge_transfer_total{result,source_chain,target_chain}`
     - `mohawk_bridge_transfer_latency_ms_bucket`

2. **Enforce minimum traffic thresholds in readiness assertions**
   - Existing gate now requires bridge/hybrid series; extend this to fail when counters remain below expected minimums in traffic-enabled runs.

3. **Fix UDP buffer startup warning**
   - Apply host-level sysctl tuning before node startup:
     - `net.core.rmem_max`, `net.core.rmem_default`, `net.core.wmem_max`, `net.core.wmem_default`.

### P1 (Short-term)

4. **Split or scope metrics by service responsibility**
   - Avoid exporting utility-ledger counters from `tpm-metrics` unless intended.
   - Keep service-specific registries to reduce duplication and ambiguity.

5. **Add synthetic load stage to one-click readiness**
   - Run a short bridge/proof/gradient workload before readiness gate so optional metrics become populated and validated as required.

6. **Dashboard SLO panels for 3-node/scale tests**
   - Add panels for:
     - proof verify success rate
     - bridge transfer success rate
     - gradient compression ratio by format
     - accelerator backend mix (`cpu/cuda/metal/npu`)

### P2 (Mid-term)

7. **Auto-tuner feedback loop**
   - Use observed latency/throughput to adapt `recommended_workers` over time (EMA-based controller).
   - Persist per-backend tuning profile for warm starts.

8. **Per-node gradient pipeline timing metrics**
   - Instrument each node round:
     - quote generation
     - attestation submit latency
     - p2p gradient submit latency
     - ack success rate

## Success Criteria for Next Iteration

- `mohawk_accelerator_ops_total` and `mohawk_gradient_compression_ratio_*` visible in Prometheus.
- Node-agent targets present in Prometheus and healthy. ✅
- Bridge/hybrid telemetry visible in central Prometheus targets (not only local pyapi snapshot artifacts). ✅
- UDP buffer warnings reduced to zero after host tuning.
- Readiness gate enforces proof/bridge/hybrid metrics as required. ✅
