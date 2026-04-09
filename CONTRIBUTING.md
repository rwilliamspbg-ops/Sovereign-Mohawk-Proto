# Contributing to Sovereign Mohawk Protocol (SMP)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](https://discord.com/invite/raBz79CJ)

Thank you for your interest in the **Sovereign Mohawk Protocol**! We are building
a decentralized spatial operating system where data sovereignty is a right, not
a feature. By contributing, you are helping scale a coordinator-less,
privacy-preserving network to 10 million nodes.

---

## 🏆 The Audit Status & Points System

To incentivize high-integrity contributions, we use a merit-based **Audit Points** system. Earning points grants you "Audit Status" within the community and
determines eligibility for rewards within the
[Sovereign-Mohawk-Proto](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
ecosystem.

### Priority Tracks & Point Values

| Track | Role | Goal | Points |
| :--- | :--- | :--- | :--- |
| **🛡️ Audit & Verify** | Cryptographer | Verify Theorems 1-6 or audit zk-SNARK logic. | **100** |
| **🏗️ Hardware Port** | Edge Engineer | Port node-agent to NPUs (e.g., Jetson, Apple Silicon). | **50** |
| **🐍 SDK Expansion** | Python Dev | Build wrappers or [SDK Python examples](./sdk/python/examples). | **25** |
| **📝 Documentation** | Any | Fix typos, improve READMEs, or clarify technical specs. | **5** |

---

## 🛠️ How to Contribute

### 1. Claim a "Master Auditor" Task

Browse our [GitHub Issues](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
for the `Master Auditor` or `priority` labels. We are currently seeking:

* **Theorem 5 Verification:** Stress-test ZK-proofs against Round 45 logs.
* **NPU Optimization:** FFI bindings for **85+ TOPS** hardware.

### 2. Use Professional Templates

Your PR must include a completed template to be eligible for points:

* [Cryptographic Audit Template](./proofs/audit_verification.md)
* [Hardware Porting Template](./proofs/hardware_port.md)

### 3. Submission & Linting

1. **Fork** the repository and create a feature branch (`git checkout -b feat/your-contribution`).
2. **Implement** your changes following the [SGP-001 Privacy Standard](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto#trust--verification).
3. **Lint & Test**: Run `black`, `ruff`, and `mypy` on any Python changes to ensure they pass the [CI/CD Workflow](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions).
4. **Submit PR**: Tag your PR with `[AUDIT]` to trigger the verification runner.

### Local Run and Test Quickstart

Use these commands before opening a PR:

```bash
source scripts/ensure_go_toolchain.sh
make lint
make test
```

If you touched Python SDK code:

```bash
cd sdk/python
python -m pip install -e .[dev]
pytest -q
```

### Branch Naming Conventions

Use short, scoped branch names:

* `feat/<topic>` for new functionality
* `fix/<topic>` for bug fixes
* `perf/<topic>` for benchmark or latency work
* `docs/<topic>` for documentation only
* `ci/<topic>` for workflow and automation changes

### Go Toolchain Guard (Required)

This repository requires Go `1.25.9` from `go.mod`.

Before running `go`, `make lint`, `make verify`, or benchmark commands, source:

```bash
source scripts/ensure_go_toolchain.sh
```

Why:

* Prevents mixed `go`/`compile` toolchains.
* Enforces minimum required Go version.
* Automatically selects the cached repository-compatible toolchain path when available.

### 4. Optional Chat Notifications for Weekly Readiness Digest

Maintainers can wire the `Weekly Readiness Digest` workflow to Slack and/or Teams.

Configure repository secrets in **Settings → Secrets and variables → Actions**:

* `SLACK_WEBHOOK_URL`
* `TEAMS_WEBHOOK_URL`

If unset, the notification step is skipped and digest artifacts are still published.

### 5. Benchmark Workflow for Runtime Changes

If your PR changes aggregation, accelerator, or performance-critical paths, include benchmark evidence.

1. Run the Go FedAvg benchmark matrix locally:

```bash
TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.9.linux-amd64 \
GOROOT=$TOOLROOT PATH=$TOOLROOT/bin:$PATH GOTOOLCHAIN=local \
go test ./test -run '^$' -bench BenchmarkAggregateParallel -benchmem -benchtime=200ms
```

1. Generate base-vs-current benchmark comparison:

```bash
TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.9.linux-amd64 \
BASE_REF=origin/main BENCH_TIME=200ms BENCH_COUNT=10 \
USE_BENCHSTAT=always BENCHSTAT_ALPHA=0.01 \
REPORT_PATH=results/metrics/fedavg_benchmark_compare.md \
./scripts/benchmark_fedavg_compare.sh
```

1. Attach or reference benchmark evidence in your PR:

* Local report: `results/metrics/fedavg_benchmark_compare.md`
* CI artifact: `fedavg-benchmark-report` from workflow `FedAvg Benchmark Compare`

### 6. Run the Full 10-Node Stack Locally

Use this when validating swarm-scale behavior before opening a PR:

```bash
./genesis-launch.sh --all-nodes
docker compose -f docker-compose.full.yml up -d --scale node-agent=10
```

When scaling `node-agent`, set cert pool size to at least the replica count:

```bash
MOHAWK_TPM_CLIENT_CERT_POOL_SIZE=10 docker compose -f docker-compose.full.yml up -d --scale node-agent=10
```

The scaled profile is fail-fast: replicas exit if their per-replica cert/key is missing.

Common pitfalls and fixes:

* TPM secret material missing in Docker volume:
  * Run `docker compose run --rm runtime-secrets-init` before starting the stack.
* Port conflicts (`3000`, `8080`, `9090`, `9093`, `9102`, `9104`):
  * Run `docker compose down -v` and stop local processes already bound to those ports.
* Stale runtime secrets from previous runs:
  * Remove old files under `runtime-secrets/` and re-run `./genesis-launch.sh --all-nodes`.
* Low host UDP/socket buffers causing readiness warnings:
  * Run `scripts/validate_host_network_tuning.sh` and then apply via `sudo bash scripts/host_tuning.sh --persist`.
* Docker Desktop + TPM flow mismatch on non-Linux hosts:
  * Use `make strict-auth-smoke-container` to validate the glibc path in a reproducible container.

---

## 📜 Standards

* **Privacy First:** Never include raw data in logs. Use the [SGP-001](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto) scrubbers.
* **Complexity:** PRs must not increase the $O(d \log n)$ communication complexity verified in [PERFORMANCE.md](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/PERFORMANCE.md).

---

## ⚖️ Licensing & IP Notice for Contributors

Contributor recognition and point awards are tracked in [CONTRIBUTORS.md](CONTRIBUTORS.md) and mirrored in [DASHBOARD.md](DASHBOARD.md).

* **Project License:** Contributions to this repository are accepted under the Apache License 2.0. See [LICENSE.md](LICENSE.md).
* **Patent Context:** The protocol includes components marked as **Patent Pending** (U.S. provisional filing, March 2026).
* **No Additional IP Grant by Docs:** This notice is informational and does not modify Apache-2.0 terms in [LICENSE.md](LICENSE.md).
* **Canonical Legal Summary:** See [NOTICE.md](NOTICE.md) for consolidated licensing, IP disclosure, and trademark guidance.
* **By submitting a PR:** You confirm you have rights to submit the contribution and that submission is under repository license terms.

---

## 🔗 Connect with the Architects

* **Bitcointalk:** [Six-Theorem Formal Verification Thread](https://bitcointalk.org/index.php?topic=5575025.0)
* **Reddit:** [r/SovereignMap Community](https://www.reddit.com/user/Famous_Aardvark_8595/)
