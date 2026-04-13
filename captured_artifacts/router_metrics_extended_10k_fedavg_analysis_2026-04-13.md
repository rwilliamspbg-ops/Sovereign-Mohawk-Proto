# Extended Prometheus Analysis (10k FedAvg Round)

- Pre snapshot: `captured_artifacts/router_metrics_pre_extended_10k_fedavg_2026-04-13.prom`
- Post snapshot: `captured_artifacts/router_metrics_post_extended_10k_fedavg_2026-04-13.prom`

## Key Metric Deltas

| Metric | Labels | Pre | Post | Delta |
| --- | --- | ---: | ---: | ---: |
| go_memstats_heap_alloc_bytes | - | 4214664.000 | 2734920.000 | -1479744.000 |
| process_resident_memory_bytes | - | 17833984.000 | 16859136.000 | -974848.000 |

## Histogram Coverage

- Histogram bucket metric families present: 0
- No `_bucket` histogram series exposed in this snapshot.

## 10k Wall-Time Trend (Recent Commits)

| Date | Commit | Mode | Safe wall (s) | Edge wall (s) | Note |
| --- | --- | --- | ---: | ---: | --- |
| 2026-04-13 | 7bbb46c | distributed/router-on | 1.171 | 1.099 | test(scale): refresh distributed 10k router+bridge artifacts |
| 2026-04-13 | 9265b0e | in-process/router-off | 0.975 | 1.017 | docs(perf): refresh scaling evidence artifacts |
| 2026-04-13 | e7fc6dd | in-process/router-off | 0.999 | 1.108 | test(scale): add 10k runtime evaluation and verify CI workflow pins |
