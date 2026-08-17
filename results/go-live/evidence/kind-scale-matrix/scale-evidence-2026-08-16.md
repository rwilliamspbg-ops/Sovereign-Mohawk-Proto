# Local kind scale evidence - 2026-08-16

## Environment

- Runtime: one-node kind cluster in the current codespace.
- Node capacity and allocatable CPU: 4 cores.
- Pod CIDR: `10.244.0.0/20`; kubelet maximum pods: 2000.
- Node-agent resource request: 5m CPU and 16Mi memory.

## Completed readiness tiers

| Requested node-agent replicas | Ready replicas | Result | Evidence |
| --- | --- | --- | --- |
| 100 | 100 | Pass | `pods_100.txt`, `statefulset_100.yaml` |
| 300 | 300 | Pass | `pods_300.txt`, `statefulset_300.yaml` |
| 500 | 500 | Pass | `pods_500.txt`, `statefulset_500.yaml` |

## 700-replica boundary

The 700-replica run did not reach full readiness within the harness's 600-second rollout timeout. At diagnostic capture, 566 node-agent pods were running and 134 were pending. Kubernetes reported `FailedScheduling` for the pending pods because the sole kind node had insufficient CPU. No node-agent pods had restarted, so this is host scheduler capacity pressure rather than an application crash.

Captured diagnostics:

- `statefulset_700_timeout.yaml`
- `pods_700_timeout.txt`
- `pods_700_timeout.json`
- `pending_700_timeout.txt`
- `events_700_timeout.txt`
- `node_700_timeout.txt`

This validates 500 ready node-agent replicas as the largest completed real workload tier in this codespace. The 700-replica attempt establishes the next observed single-host limit; it is not evidence of a distributed or multi-host ceiling.