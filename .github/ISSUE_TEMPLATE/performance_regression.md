---
name: Performance regression
about: Report benchmark regressions or latency/throughput drift
title: "[PERF] "
labels: performance
assignees: ''
---

## Regression summary
Describe what regressed (latency, throughput, allocs, or error ratio).

## Benchmark command
Paste the exact command used.

## Baseline vs current
- Baseline ref:
- Current ref:
- Workload/config:
- Significant delta(s):

## Attached evidence
- [ ] results/metrics/fedavg_benchmark_compare.md
- [ ] Raw benchmark output files
- [ ] Other artifacts (bridge, accelerator, chaos):

## Suspected scope
List packages/files likely related to the regression.

## Acceptance criteria
What metric threshold should be restored?
