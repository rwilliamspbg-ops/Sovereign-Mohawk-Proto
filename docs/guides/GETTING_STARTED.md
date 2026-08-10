# Getting Started

This guide covers three real, runnable ways to get Sovereign-Mohawk running
locally, from fastest/lightest to most complete. Everything below was
verified against the actual scripts, Makefile targets, and Docker Compose
files in this repository as of this writing — nothing here is aspirational.
For what's still a placeholder elsewhere in the docs tree, see
[docs/INDEX.md](../INDEX.md#documentation-status).

## Prerequisites

- **Go** — version pinned in [go.mod](../../go.mod) (`go 1.26.5` as of this
  writing). Only needed if you're building the Go runtime or the Python
  SDK's native library.
- **A working C compiler, with `CGO_ENABLED=1`** — required specifically
  for `make build-python-lib` in Path 1 below (it builds
  `internal/pyapi/api.go`, which uses `import "C"`). On Linux/macOS a C
  toolchain is normally already present and `CGO_ENABLED` defaults to `1`
  automatically. **On Windows there is no C compiler by default** — without
  one, `go build -buildmode=c-shared` silently excludes the cgo file from
  the build and fails with the confusing error `go: no Go source files`
  (this is a build-constraint exclusion, not a "file not found" — it
  reproduces on a clean checkout with only the standard Go toolchain
  installed). Install a MinGW-w64 toolchain (e.g. `choco install mingw`,
  then confirm with `where gcc`) and ensure `go env CGO_ENABLED` reports
  `1` before running Path 1. This prerequisite does not affect Paths 2/3 —
  `cmd/node-agent/Dockerfile` builds the same `libmohawk.so` with
  `CGO_ENABLED=1`, but inside the Docker build image, which already
  includes its own C toolchain regardless of your host.
- **Python** — 3.8+ (per [sdk/python/pyproject.toml](../../sdk/python/pyproject.toml)).
  Only needed for the Python SDK path.
- **Docker + Docker Compose v2** (the `docker compose` subcommand, not the
  standalone `docker-compose` binary) — needed for the Genesis Testnet and
  Sandbox paths below.
- **git**

No manual `.env` setup is required to start the stack: `scripts/genesis-launch.sh`
auto-creates `.env` from [.env.example](../../.env.example) with a generated
local Grafana admin password on first run if one doesn't already exist.

## Path 1: Python SDK + Flower quickstart (fastest)

This is the fastest way to see the runtime do something — no Docker
required.

```bash
git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
cd Sovereign-Mohawk-Proto
make build-python-lib
cd sdk/python
pip install -e .[flower]
python examples/flower_integrated/quickstart_pytorch.py --ci
```

`make build-python-lib` compiles `internal/pyapi/api.go` into a C-shared
library (`libmohawk.so`) that the Python SDK loads via `ctypes` — this step
is why Go is a prerequisite even for the Python-only path.

This gives you a Flower-compatible client flow using Mohawk's security
primitives end-to-end locally. The `--ci` flag runs it as a smoke test; drop
it and set `submit_updates=True` on your `MohawkFlowerClient` for a live run
that actually submits updates to aggregation. See
[sdk/python/README.md](../../sdk/python/README.md) for the full API surface.

Prefer installing from PyPI instead of building from source:

```bash
pip install mohawk[flower]
```

**Larger local simulation** (1024 virtual nodes, no Docker):

```bash
make simulate-fl-1k
```

## Path 2: Genesis Testnet (multi-node Docker stack)

This is the real, runnable multi-node path — orchestrator, sharding,
node agents, Multi-Krum Byzantine filtering, Prometheus/Grafana monitoring,
IPFS.

```bash
git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
cd Sovereign-Mohawk-Proto

# Regional profile: orchestrator + shard + node-agent-1
./scripts/genesis-launch.sh

# Or the full local 3-node stack: orchestrator + shard + node-agent-1..3
./scripts/launch_full_stack_3_nodes.sh --no-build
```

On Windows, use native PowerShell instead:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./scripts/launch_full_stack_3_nodes.ps1 -NoBuild
```

Check it's running:

```bash
docker compose ps
```

Default endpoints once up:

- Grafana: `http://localhost:3000` (login: `admin` / see `GRAFANA_ADMIN_PASSWORD` in `.env`)
- Prometheus: `http://localhost:9090`
- TPM metrics exporter: `http://localhost:9102/metrics`
- Orchestrator control plane: `https://localhost:8080` (mTLS enforced)

Add more node agents after startup:

```bash
./scripts/docker-compose-wrapper.sh up -d node-agent-2 node-agent-3
```

**Windows/Git Bash note:** always call the wrapper with its `./scripts/`
path (`./scripts/docker-compose-wrapper.sh ...`). Running
`docker-compose-wrapper.sh ...` without the path fails with
`command not found`.

Stop the stack:

```bash
docker compose down
```

To scale a single `node-agent` service with replicas instead of named
services, use `docker-compose.full.yml` directly; if you need per-replica
mTLS identities, make sure the cert pool is at least as large as the
replica count:

```bash
MOHAWK_TPM_CLIENT_CERT_POOL_SIZE=10 docker compose -f docker-compose.full.yml up -d --scale node-agent=10
```

## Path 3: Sandbox (lightest Docker on-ramp)

A smaller topology (1 orchestrator, 1 shard, 2 node agents, a bundled
"Hello World" FL WASM task) for quick research/dev iteration:

```bash
docker compose -f docker-compose.sandbox.yml up -d --build

# equivalent:
./scripts/launch_sandbox.sh
make sandbox-up
```

Check it:

```bash
docker compose -f docker-compose.sandbox.yml ps
docker logs --tail=100 node-agent-1
docker logs --tail=100 node-agent-2
```

Stop it:

```bash
docker compose -f docker-compose.sandbox.yml down
```

## What's not covered here

- **Kubernetes/cloud deployment** — `docs/guides/DEPLOYMENT.md` and the
  `docs/guides/KUBERNETES_DEPLOYMENT.md` / `CLOUD_DEPLOYMENT.md` paths
  linked from [docs/INDEX.md](../INDEX.md) are still placeholder scaffolds
  as of this writing. `deploy/cloud-templates/README.md` and
  `./scripts/helm-install.sh` / `make deploy-to-kind` exist in this repo,
  but are not walked through step-by-step anywhere yet.
- **Performance numbers** — don't trust any throughput/latency figure you
  see elsewhere in the docs as a guarantee; see
  [PERFORMANCE.md](../../PERFORMANCE.md) for how to measure your own.
- **Production/Phase 4 deployment claims** — see
  [docs/PHASE_4_PRODUCTION_DEPLOYMENT.md](../PHASE_4_PRODUCTION_DEPLOYMENT.md)
  for what's real versus what was previously fabricated in that area.

## Where to go next

- Full documentation navigation: [docs/INDEX.md](../INDEX.md)
- Formal verification status (start here for any resilience/privacy claim):
  [proofs/FORMAL_TRACEABILITY_MATRIX.md](../../proofs/FORMAL_TRACEABILITY_MATRIX.md)
- Python SDK full API reference: [sdk/python/README.md](../../sdk/python/README.md)
- Benchmarks and reproducibility: [docs/BENCHMARKS_AND_REPRODUCIBILITY.md](../BENCHMARKS_AND_REPRODUCIBILITY.md)
