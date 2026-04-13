# Scaled Swarm Benchmark Report

Router-enabled runtime swarm benchmark summary generated from CI matrix outputs.

- Router smoke: MISSING/FAIL
- Router metrics snapshot: missing

| Nodes | Profile | Count | Result | Elapsed (s) | Wall (s) | Iter/s | ms/iter |
| ---: | --- | ---: | --- | ---: | ---: | ---: | ---: |
| 1500 | edge | 200 | pass | 0.000 | 1.050 | 190.48 | 5.250 |
| 1500 | safe | 200 | pass | 0.000 | 1.034 | 193.42 | 5.170 |
| 10000 | edge | 200 | pass | 0.000 | 1.017 | 196.66 | 5.085 |
| 10000 | edge | 20 | pass | 0.000 | 1.173 | 17.05 | 58.650 |
| 10000 | safe | 20 | pass | 0.000 | 1.060 | 18.87 | 53.000 |
| 10000 | safe | 200 | pass | 0.000 | 0.975 | 205.13 | 4.875 |

## Throughput vs Nodes

| Nodes | Mean Iter/s (profiles) |
| ---: | ---: |
| 1500 | 191.95 |
| 10000 | 109.43 |
