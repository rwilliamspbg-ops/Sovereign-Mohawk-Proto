# Distributed Router Soak (1000 Iterations)

- Iterations: 1000
- Requests total: 5000
- Elapsed (s): 5.051
- Average requests/sec: 989.85
- Mean latency all requests (ms): 0.975
- p95 latency all requests (ms): 2.425

| Endpoint | Count | Mean (ms) | p95 (ms) |
| --- | ---: | ---: | ---: |
| publish | 1000 | 0.515 | 0.561 |
| subscribe | 1000 | 0.405 | 0.496 |
| discover | 1000 | 1.860 | 3.115 |
| provenance_post | 1000 | 0.491 | 0.917 |
| provenance_get | 1000 | 1.603 | 2.646 |
