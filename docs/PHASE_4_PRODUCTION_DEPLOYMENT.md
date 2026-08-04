# Phase 4: Production Deployment & Scale Validation

**Status:** Partially real. This document previously described a complete,
validated production deployment system (dedicated Docker Compose stack,
Kubernetes manifests, AWS/GCP/Azure templates, operational runbook scripts,
and specific throughput/latency numbers). None of that tooling exists in
this repository. This page has been rewritten to describe only what's
actually here and how to exercise it yourself.

For the canonical, up-to-date version of this correction see the
["Multi-Tier Transport & Federation"](../README.md#multi-tier-transport--federation-internal-packages)
section of the root README — this page mirrors it.

---

## What's real

- **`internal/transport`** — the MRC (multi-path spraying) transport
  adapter. `go test ./internal/transport/...` passes, including
  `BenchmarkMRCThroughput`.
- **`internal/streaming_aggregator.go`** — non-blocking chunk
  reassembly/buffering for streaming gradient ingestion. `go test -run
  TestStreamingAggregator ./internal/` passes (chunk reassembly,
  out-of-order chunks, multi-tensor buffering, stale-buffer eviction,
  overflow rejection), including `BenchmarkStreamingAggregatorIngest`.
- **`internal/federation`** — a Regional → Continental → Global gRPC-based
  aggregation hierarchy. `go test ./internal/federation/...` passes,
  including a simulated 100-node scenario (`TestFederationScenario100Nodes`
  in `internal/federation/federation_end_to_end_test.go`; there is no
  `TestTwoTierFederation`/`TestThreeTierFederation` as an earlier version of
  this doc claimed).
- **Byzantine filtering:** Multi-Krum, with real tests
  (`TestMultiKrumSelect`, `TestMultiKrumAggregate` in
  `internal/multikrum*_test.go`) and exercised live via the Genesis Testnet
  stack.
- **Local multi-node deployment:** `./scripts/genesis-launch.sh
  --all-nodes` brings up the full stack via the root `docker-compose.yml`
  (orchestrator, 3 node-agents, federated-router, TPM metrics, Prometheus,
  Grafana, Alertmanager, IPFS, ops-assistant) — see the
  [Genesis Testnet section](../README.md#genesis-testnet) of the README for
  the actual, runnable quickstart.
- **Monitoring:** Prometheus + Grafana are real and wired up by the same
  compose stack. Jaeger distributed tracing is not currently wired into the
  default compose stack, despite being described below in an earlier
  version of this doc.
- **Cloud bootstrap scaffolds:** `deploy/cloud-templates/` has real
  single-VM `aws-userdata.sh` / `gcp-startup.sh` scripts that install
  Docker, clone the repo, and launch the baseline stack — see
  [`deploy/cloud-templates/README.md`](../deploy/cloud-templates/README.md).
  These are explicitly scaffolds for one-node evaluation, not a
  multi-region production topology.
- **Kubernetes:** a single-service Helm chart at
  `helm/sovereign-mohawk/` (orchestrator deployment, RBAC, network policy).
  There is no multi-tier StatefulSet topology, service mesh, or
  Grafana/Loki monitoring stack manifest anywhere in this repo.

## What was fabricated in the previous version of this document

- A dedicated `docker-compose.phase4-prod.yml`, `deploy/kubernetes/phase4-prod/`
  (with 90 regional / 10 continental / 1 global replica StatefulSets, an
  Istio service mesh, and a Prometheus+Grafana+Loki monitoring stack), and
  AWS CloudFormation / GCP Terraform / Azure ARM templates for a
  "phase4-prod-federation" topology — none of these paths exist.
- `scripts/phase4/{health-check,validate-federation,test-byzantine-scenario,
  measure-e2e-latency,stress-test-federation,isolate-nodes,reinstate-nodes,
  validate-topology,validate-failover}.sh` — none of these scripts exist.
- Specific numbers ("2,525 chunks/sec", "99.3% success rate", "160K+
  ops/sec", "10K+ grad/sec", "<500ms TTL") were not backed by any benchmark
  result file in this repo. A real (if informal) local
  `go test -bench=BenchmarkMRCThroughput ./internal/transport` run measured
  **17-40 ops/sec** — nowhere near the previously claimed figures. Treat any
  specific throughput number as something to re-measure on your own
  hardware, not a guaranteed target. See [PERFORMANCE.md](../PERFORMANCE.md)
  for current methodology.
- The "Production Readiness Checklist" and "Success Criteria" sections
  claimed 16 items were all validated (Jaeger tracing enabled, failover
  mechanisms validated, Kubernetes manifests prepared, etc.) — most of
  these describe capabilities that don't exist in this repo, not completed
  work.
- The `TestTwoTierFederation` example test, and the "Byzantine Attack
  Mitigation" / "Tier Scaling" / "Failover & Recovery" runbooks referencing
  `kubectl patch`/`kubectl rollout`/`kubectl set` against resources this
  repo has no manifests for, were illustrative pseudocode, not something
  that runs against anything in this repository.

## Reproducing what's real

```bash
# Full local multi-node stack (real)
./scripts/genesis-launch.sh --all-nodes

# Transport layer tests + benchmark (real)
go test ./internal/transport/... -v
go test -bench=BenchmarkMRCThroughput ./internal/transport -benchtime=10s

# Streaming aggregator tests + benchmark (real)
go test -run TestStreamingAggregator ./internal/ -v
go test -bench=BenchmarkStreamingAggregatorIngest ./internal/ -benchtime=10s

# Federation hierarchy tests, including a 100-node scenario (real)
go test ./internal/federation/... -v

# Byzantine (Multi-Krum) filtering tests (real)
go test -run TestMultiKrum ./internal/ -v
```
