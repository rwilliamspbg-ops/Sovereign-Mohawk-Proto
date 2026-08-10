# Kubernetes Scale Deployment Test (2026-08-10)

- Generated (UTC): `2026-08-10`
- Environment: single-node `kind` cluster on Docker Desktop, one laptop (16 CPUs, 13.46GiB allocated to the Docker Desktop VM)
- Overall result: **500 real pods stable and healthy; 700 destabilizes the control plane under this host's disk I/O**

## Why this exists

`ROADMAP.md`'s "1M+ node aggregation rehearsal" and "1M-scale rehearsal passed with documented SLO results" items were corrected on 2026-08-10 (see that file's revision history) after an audit found no artifact anywhere in this repository substantiating a 1M-node claim. This document is the honest replacement: a real, reproducible deployment test at the actual scale this hardware can support, run against the unmodified `cmd/orchestrator` and `cmd/node-agent` binaries — not a simulation, not a dashboard fixture.

**This is not 1M-node evidence and does not claim to be.** It is evidence at a genuinely smaller, real scale, with an honestly-reported ceiling and root cause for why that ceiling exists on this class of hardware.

## Setup

- Real container images built from this repo's own `cmd/orchestrator/Dockerfile` and `cmd/node-agent/Dockerfile` (not pulled from a registry — see "Real bug found" below)
- Real `kind` cluster (`kubeadmConfigPatches` raising `--max-pods` to 2000 and the per-node pod-CIDR mask to `/20`, since kind's defaults cap a single node at 254 pod IPs)
- Real mTLS: a CA plus a 500-entry per-replica client certificate pool, generated with the exact `openssl` logic from `docker-compose.yml`'s `runtime-secrets-init` service, adapted only to 0-indexed cert filenames to match Kubernetes `StatefulSet` ordinal pod names (`node-agent-0`, `node-agent-1`, ...)
- `node-agent` deployed as a `StatefulSet` (not a `Deployment`) specifically so each replica's stable ordinal hostname can select its own unique certificate from the pool, mirroring the `HOSTNAME`-index logic already in `docker-compose.full.yml`'s node-agent `command:` block
- Real `orchestrator` (1 replica) and real `ipfs/kubo:v0.28.0` (1 replica) backing the fleet
- Manifests, kind config, and the cert-pool generation script are checked in under `deploy/kubernetes/scale-test/` for reproduction

## Real bug found and worked around

`helm/sovereign-mohawk/values.yaml` references `ghcr.io/rwilliamspbg-ops/node-agent:2.0.1-alpha`, but `.github/workflows/publish-docker-images-ci.yml` actually publishes to `ghcr.io/rwilliamspbg-ops/sovereign-mohawk-<image>:<main|sha-*|tag>` — a different repository name and tag scheme entirely. No `2.0.1-alpha` tag was ever pushed (confirmed against `git tag -l`). As configured, `make deploy-to-kind` would fail with `ImagePullBackOff`. Fixed in this same change (see `helm/sovereign-mohawk/values.yaml` diff) — this test itself worked around it by building images locally and `kind load docker-image`-ing them in, which is also documented in `deploy/kubernetes/scale-test/README.md` as a viable path when registry images aren't available.

## Scale results

| Replicas | Result | Memory (of 13.46GiB) | Notes |
| --- | --- | --- | --- |
| 3 | Stable | ~5% | Baseline correctness check |
| 200 | Stable | 29.6% | |
| 500 | **Stable**, 500/500 Ready | 65.7-68.9% | Confirmed stable across two independent runs |
| 700 | **Unstable** | 84%+ | See root cause below |

Real per-pod memory footprint (via `crictl stats` inside the node, not `kubectl top`, which needs a metrics-server this cluster doesn't have installed): **~8.6MB RSS per `node-agent` container** at idle-plus-light-load — far below the Helm chart's default request of 768Mi. The default chart resources were sized for production headroom, not laptop-scale testing; this test overrode `node-agent` requests to `5m`/`16Mi` to let the scheduler pack realistically.

### Root cause of the 700-replica failure

Not memory or CPU exhaustion (both had headroom at the point of failure). `etcd`'s own logs showed it repeatedly failing to reach its own client port (`127.0.0.1:2379`, `i/o timeout`), and `kube-apiserver` crash-looped (8 restart attempts observed) unable to complete its etcd storage-factory handshake within its deadline. Docker's block I/O counter climbed past 7GB written and kept climbing under the crash-loop's own retry load. This is consistent with `etcd`'s fsync-heavy WAL write pattern exceeding what Docker Desktop's virtualized disk backend can sustain at this container density — an I/O throughput/latency ceiling, not a disk-space ceiling (`df` inside the VM showed 929.9GB free of 1006.9GB at the time). Recovery required a clean cluster recreation; waiting for self-recovery did not resolve it within the observation window. Separately, 20.75GB of accumulated Docker build cache (`docker system df`) was cleaned up as a contributing factor, though the underlying disk was never actually full.

**This is a laptop/Docker-Desktop infrastructure ceiling, not a defect in the orchestrator or node-agent code.** Real production Kubernetes (dedicated nodes, non-virtualized or better-provisioned block storage) would not be expected to hit this specific wall at this container count.

## Security tests (run against the live orchestrator, from inside the cluster network)

| # | Test | Result |
| --- | --- | --- |
| 1 | Connect with no client certificate | Rejected at TLS handshake (curl exit 56, no HTTP response) |
| 2 | Connect with a valid pool certificate (real CA-signed) | TLS handshake succeeds; reaches the HTTP layer |
| 3 | Connect with an untrusted self-signed certificate (not signed by the real CA) | Rejected at TLS handshake, identical to test 1 |
| 4 | Valid cert, wrong bearer token, `POST /ledger/migration/migrate` (mutating endpoint) | `401 unauthorized` |
| 5 | Valid cert, real admin token, same endpoint | Auth passed; reached real business-logic validation (`400`, malformed test payload) |

Orchestrator-side `mohawk_tpm_verifications_total{result="success"}` reached **5544** with zero recorded failures across the test run.

## Performance data (sampled 20 of 500 `node-agent` pods)

- 421 real gradient-submission rounds observed across the sample (accelerator backend: CPU)
- Mean gradient-submission latency: **~31ms** (`mohawk_accelerator_op_latency_ms_sum` / `_count`, aggregated across the sample), under real contention from 500 concurrent pods sharing 16 physical cores — not an idle-single-node number
- **`mohawk_proof_verifications_total{result="failure"}` = 100% of attempts, consistently across every one of the 20 sampled nodes** (e.g. 23/23, 19/19, 20/20, 24/24 — always failure count equals total count). This is not a defect: `cmd/node-agent/Dockerfile` intentionally bakes in a minimal WASM verifier stub that always returns 0 (reject) as the fail-closed default for strict runtime startup. This test is a genuine, live confirmation that the fail-closed posture documented in `ROADMAP.md`'s A1 section ("Runtime proof-verifier fail-closed boot enforcement") actually holds under real deployed load, not just at the unit-test level.

## What this does and does not establish

- **Does establish**: the orchestrator and node-agent binaries, unmodified, run correctly as several hundred independent real Kubernetes pods with real mTLS identity, real TPM verification, real gradient submission, and correctly-enforced fail-closed proof verification.
- **Does not establish**: behavior at 10K, 100K, 1M, or 10M node scale. Nothing about this test extrapolates to those scales — the bottleneck found (single-node etcd I/O) is specific to this test's single-`kind`-node topology and would not exist in the same form in a real multi-node production cluster, but that only means the *ceiling* wouldn't be at 700; it says nothing about where a real ceiling would be at far larger scale.
- **Does not establish**: multi-region, multi-tier hierarchical aggregation behavior (this test used a flat topology — one orchestrator, no regional/continental tiers).
