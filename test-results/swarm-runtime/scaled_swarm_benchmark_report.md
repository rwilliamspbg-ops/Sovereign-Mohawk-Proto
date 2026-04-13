# Scaled Swarm Benchmark Report

Router-enabled runtime swarm benchmark summary generated from CI matrix outputs.

- Router smoke: MISSING/FAIL
- Router metrics snapshot: missing

| Nodes | Profile | Count | Result | Elapsed (s) | Wall (s) | Iter/s | ms/iter |
| ---: | --- | ---: | --- | ---: | ---: | ---: | ---: |
| 1500 | edge | 200 | pass | 0.000 | 1.113 | 179.69 | 5.565 |
| 1500 | safe | 200 | pass | 0.000 | 1.545 | 129.45 | 7.725 |
| 10000 | edge | 200 | pass | 0.000 | 1.108 | 180.51 | 5.540 |
| 10000 | edge | 20 | pass | 0.000 | 1.173 | 17.05 | 58.650 |
| 10000 | safe | 20 | pass | 0.000 | 1.060 | 18.87 | 53.000 |
| 10000 | safe | 200 | pass | 0.000 | 0.999 | 200.20 | 4.995 |

## Throughput vs Nodes

| Nodes | Mean Iter/s (profiles) |
| ---: | ---: |
| 1500 | 154.57 |
| 10000 | 104.16 |
