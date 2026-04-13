# Scaled Swarm Benchmark Report

Router-enabled runtime swarm benchmark summary generated from CI matrix outputs.

- Router smoke: PASS
- Router metrics snapshot: present

| Nodes | Profile | Count | Result | Elapsed (s) | Wall (s) | Iter/s | ms/iter |
| ---: | --- | ---: | --- | ---: | ---: | ---: | ---: |
| 1500 | edge | 200 | pass | 0.000 | 1.050 | 190.48 | 5.250 |
| 1500 | safe | 200 | pass | 0.000 | 1.034 | 193.42 | 5.170 |
| 10000 | edge | 200 | pass | 0.000 | 1.099 | 181.98 | 5.495 |
| 10000 | safe | 200 | pass | 0.000 | 1.171 | 170.79 | 5.855 |

## Throughput vs Nodes

| Nodes | Mean Iter/s (profiles) |
| ---: | ---: |
| 1500 | 191.95 |
| 10000 | 176.39 |
