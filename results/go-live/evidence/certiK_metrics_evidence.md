# certiK Metrics Evidence

Generated: 2026-04-01 (UTC)

- Stress window start (UTC): 2026-04-01T00:31:17.285815+00:00
- Stress window end (UTC): 2026-04-01T00:41:17.285940+00:00

## Scope

This evidence bundle captures reruns for:

- Bridge compression benchmark comparison
- FedAvg benchmark comparison
- 10-minute stress metrics capture
- v2 dashboard validation

It also records that readiness telemetry assertions now include accelerator and gradient-compression activity checks.

## Executed Commands

```bash
TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.8.linux-amd64 \
BASE_REF=origin/main BENCH_TIME=200ms BENCH_COUNT=10 BENCH_CPU=2 \
USE_BENCHSTAT=always BENCHSTAT_ALPHA=0.01 \
REPORT_PATH=results/metrics/fedavg_benchmark_compare.md \
./scripts/benchmark_fedavg_compare.sh

BENCH_TIME=200ms REPORT_PATH=results/metrics/bridge_compression_benchmark_compare.md \
BENCH_COUNT=5 BENCH_CPU=2 BENCHSTAT_ALPHA=0.01 \
./scripts/benchmark_bridge_compression_compare.sh

python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 \
  > results/readiness/readiness-report.json
```

Additional live evidence generation:

- 10-minute metrics capture written to `results/metrics/stress_metrics_capture_10m.md`
- v2 dashboard validation report written to `results/metrics/v2_dashboard_validation_report.md`

## Evidence Artifacts

- `results/metrics/fedavg_benchmark_compare.md`
- `results/metrics/bridge_compression_benchmark_compare.md`
- `results/metrics/bridge_compression_benchmark_raw.txt`
- `results/metrics/stress_metrics_capture_10m.md`
- `results/metrics/v2_dashboard_validation_report.md`
- `results/readiness/readiness-report.json`

## Readiness Assertion Confirmation

Current readiness report includes pass/fail checks for:

- `accelerator_ops_series_present`
- `accelerator_ops_min_activity`
- `gradient_compression_series_present`
- `gradient_compression_min_activity`

These checks were validated as passing in the generated readiness report.

## Validation Summary

- Readiness gate status: pass (`results/readiness/readiness-report.json` has `"ok": true`)
- FedAvg comparison report regenerated successfully
- Bridge compression comparison report regenerated successfully
- 10-minute stress capture and v2 dashboard validation reports regenerated successfully