# Byzantine Forensics Rejection Report

- Generated at: 2026-04-17T02:18:31Z
- Log window: 15m
- Containers scanned: node-agent-1,node-agent-2,node-agent-3,orchestrator
- Total log lines scanned: 45
- Rejection/failure events: 0
- Event ratio of scanned lines: 0.00%

## Event Buckets

| Bucket | Count |
| --- | ---: |
| accepted=false | 0 |
| submission failed | 0 |
| KEX mismatch | 0 |
| unsupported KEX mode | 0 |
| KEX key size mismatch | 0 |

## Top Rejection Lines

No rejection lines found for selected window.

## Recommendations

1. Compare the rejection event count with the expected Byzantine budget for the round.
2. Cross-check with metric: mohawk_consensus_honest_ratio.
3. If KEX mismatch dominates, run scripts/quantum_kex_rotation_drill.sh to normalize modes.
4. Archive this report with incident artifacts for threat-intel follow-up.
