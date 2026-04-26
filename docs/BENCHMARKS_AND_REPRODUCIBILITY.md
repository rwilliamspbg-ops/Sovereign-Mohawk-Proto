# Benchmarks and Reproducibility

This page is the single entrypoint for performance evidence and reproducible runs.

## Quick Repro (Local)

Run baseline reproducibility artifacts:

```bash
make benchmarks-reproducibility
```

This generates or refreshes:

- `results/metrics/fedavg_benchmark_compare.md`
- `test-results/swarm-runtime/scaled_swarm_benchmark_report.json`
- `test-results/swarm-runtime/scaled_swarm_benchmark_report.md`
- `results/metrics/fedavg_scale_gate_validation.json`
- `results/metrics/fedavg_scale_gate_validation.md`

## Simulator-First Repro (Laptop)

Run a zero-config local simulation with 1k+ virtual nodes:

```bash
make simulate-fl-1k
```

Or customize:

```bash
cd sdk/python
python examples/flower_integrated/local_simulator.py --virtual-nodes 1500 --rounds 5
```

## FedAvg Compare Against `main`

Run direct benchmark compare with configurable parameters:

```bash
BASE_REF=origin/main BENCH_TIME=300ms BENCH_COUNT=10 BENCH_CPU=2 \
  bash scripts/benchmark_fedavg_compare.sh
```

Output report:

- `results/metrics/fedavg_benchmark_compare.md`

## Swarm Runtime Report Build

Convert matrix JSONL outputs into normalized machine + markdown reports:

```bash
python3 scripts/publish_swarm_runtime_benchmarks.py
```

Output reports:

- `test-results/swarm-runtime/scaled_swarm_benchmark_report.json`
- `test-results/swarm-runtime/scaled_swarm_benchmark_report.md`

## Scale Gate Validation

Validate throughput floor and pre/post metric deltas:

```bash
python3 scripts/validate_fedavg_scale_gates.py
```

## Public Evidence Index

For externally shared evidence and artifacts, see:

- `PUBLIC_ARTIFACTS.md`
- `results/metrics/release_performance_evidence.md`
