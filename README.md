# 🦅 Sovereign Mohawk Proto

## Note on Naming

The "Sovereign Mohawk Protocol" name draws inspiration from principles of sovereignty, resilience, and decentralized governance—reflecting the protocol's design for edge/node self-determination and resistance to centralized control. It is **not** intended to appropriate, claim, or represent the cultural, intellectual, or traditional knowledge/property of the Kanienʼkehá꞉ka (Mohawk) people or any Indigenous nations.

We acknowledge and respect the ongoing sovereignty and self-determination of Indigenous peoples, including the Kanienʼkehá꞉ka as Keepers of the Eastern Door in the Haudenosaunee Confederacy. This project is a technical implementation in AI/privacy and makes no claims to Indigenous cultural IP, protocols, or heritage.

If this naming raises concerns or if you'd like to suggest alternatives, please open an issue or contact @RyanWill98382—we're open to dialogue and updates.

⚠️ Intellectual Property Notice: This project implements the Sovereign Mohawk Protocol. Portions of this technology are Patent Pending (U.S. Provisional Patent Application Filed March 2026).

## Sovereign-Mohawk-Proto

[![Build Status](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/build-test.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/build-test.yml)
[![Integrity Guard - Linter](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/lint.yml)
[![Performance Gate](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml)
[![Capability Sync](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/sync-check.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/sync-check.yml)
[![Security Audit](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/verify-proofs.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/verify-proofs.yml)
[![Pages Deployment](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/static.yml/badge.svg)](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/static.yml)

![Go Version](https://img.shields.io/github/go-mod/go-version/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
![Python SDK v2](https://img.shields.io/badge/SDK-2.0.0a2-blue?logo=python)
![Python Support](https://img.shields.io/badge/Python-3.8%2B-blue?logo=python)
![BFT Safety](https://img.shields.io/badge/BFT%20Resilience-55.5%25-green)
![Proof Verify Mean](https://img.shields.io/badge/Proof%20Verify-10.55ms-success)
![Gradient Compression Mean](https://img.shields.io/badge/Compression-0.996ms-informational)
![Genesis Testnet](https://img.shields.io/badge/Testnet-global--testnet-orange)
![WASM Hot Reload](https://img.shields.io/badge/WASM-Hot%20Reload-blueviolet)
![Tokenomics Dashboard](https://img.shields.io/badge/Grafana-Tokenomics%20Live-F46800?logo=grafana&logoColor=white)

---

**Sovereign-Mohawk** is a high-performance, formally verified federated learning architecture designed to scale to **10 million nodes**. The current platform ships a Python SDK v2, hybrid SNARK/STARK verification, route-policy bridge validation, utility coin ledger controls, libp2p transport, TPM-backed mTLS, and a runnable regional genesis testnet with Prometheus and Grafana observability.

---

## 🚀 Why Sovereign Mohawk?

Traditional federated learning protocols struggle with linear scaling bottlenecks, brittle trust models, and limited runtime interoperability. Sovereign-Mohawk combines formal verification with deployment-grade runtime components so the protocol can be tested, monitored, and integrated instead of staying paper-only.

### 📊 Comparative Analysis

| Feature | TensorFlow Federated | PySyft | **Sovereign-Mohawk** |
| :--- | :---: | :---: | :---: |
| **Max Scale** | 10k Nodes | 1k Nodes | **10M Nodes** |
| **Communication** | $O(dn)$ | $O(dn)$ | **$O(d \log n)$** |
| **BFT Proof** | None | Partial | **Full (Theorem 1)** |
| **Verification** | Re-execution | None | **10ms zk-SNARKs** |
| **Hybrid Proof Policy** | None | None | **SNARK/STARK** |
| **SDK Surface** | Python only | Python only | **Go + Python SDK v2** |
| **Testnet/Observability** | Limited | Limited | **Genesis stack + Grafana** |

---

## ✨ Key Capabilities

* 🛡️ **Byzantine Fault Tolerance:** 55.5% resilience via [Theorem 1](https://www.kimi.com/preview/19c56c2b-c9e2-85fa-8000-0518f5fdf88c#691).
* 🐌 **Straggler Resilience:** 99.99% success probability via [Theorem 4](https://www.kimi.com/preview/19c56c2b-c9e2-85fa-8000-0518f5fdf88c#469).
* ✅ **Instant Verifiability:** 200-byte zk-SNARK proofs with 10ms verification via [Theorem 5](https://www.kimi.com/preview/19c56c2b-c9e2-85fa-8000-0518f5fdf88c#399).
* 🐍 **Python SDK v2:** Accelerator, bridge, gradient, hybrid-proof, and utility-ledger helpers in the `mohawk` package.
* 🔀 **Hybrid Proof Policies:** Runtime selection for SNARK-only, STARK-backed, or hybrid verification modes.
* 🌉 **Bridge Policy Enforcement:** Cross-chain route policies with default manifests and typed EVM/Cosmos proof helpers.
* 💰 **Utility Coin Controls:** Persistent ledger snapshots, audit chaining, nonce replay protection, and role-gated admin operations.
* 🔁 **WASM Hash Registry + Hot Reload:** Content-addressed module loading with module-hash tracking in runtime status.
* 📊 **Tokenomics Monitoring:** Pre-provisioned Grafana dashboard for supply, holders, burn/mint dynamics, bridge settlement, and proof cost.
* 📡 **Genesis Testnet:** Regional shard bootstrap with orchestrator, node-agent, metrics exporter, Prometheus, Grafana, and IPFS.

---

## 🛠️ Installation

### Go Runtime

Sovereign-Mohawk is built with **Go 1.25+**.

```bash
git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
cd Sovereign-Mohawk-Proto
go mod tidy
go build ./...
```

### Python SDK

The Python SDK provides a high-level interface to the MOHAWK runtime:

```bash
make build-python-lib
cd sdk/python
pip install -e .[dev]
python -c "import mohawk; print(mohawk.__version__)"
```

**Quick Python Example:**

```python
from mohawk import MohawkNode

node = MohawkNode()
result = node.start(config_path="capabilities.json", node_id="node-001")

proof = {"proof": "0x1234", "public_inputs": []}
verification = node.verify_proof(proof)

updates = [{"node_id": "n1", "gradient": [0.1, 0.2]}]
aggregation = node.aggregate(updates)

devices = node.device_info()
compressed = node.compress_gradients([0.1, 0.2, 0.3], format="fp16")

hybrid = node.verify_hybrid_proof(
    snark_proof="s" * 128,
    stark_proof="t" * 64,
    mode="both",
)

receipt = node.bridge_transfer(
    source_chain="ethereum",
    target_chain="polygon",
    asset="USDC",
    amount=12.5,
    sender="0xabc",
    receiver="0xdef",
    nonce=1,
    proof="proof-bytes",
)

settled = node.bridge_transfer(
    source_chain="ethereum",
    target_chain="polygon",
    asset="MHC",
    amount=2.0,
    sender="0xabc",
    receiver="0xdef",
    nonce=2,
    proof="proof-bytes",
    settle=True,
)
```

See [sdk/python/README.md](sdk/python/README.md) for the complete API reference.

### Genesis Testnet

Launch the regional genesis testnet with the default `global-testnet` profile:

```bash
./genesis-launch.sh

# Equivalent Make target
make regional-shard
```

Default endpoints after startup:

* Grafana: `http://localhost:3000`
* Prometheus: `http://localhost:9090`
* TPM metrics exporter: `http://localhost:9102/metrics`
* Orchestrator control plane: `https://localhost:8080` (mTLS enforced)

Quick health checks:

```bash
curl -fsS http://localhost:3000/api/health
curl -fsS http://localhost:9090/-/healthy
curl -fsS http://localhost:9102/metrics | head
```

Grafana dashboard shortlist:

* `MOHAWK Tokenomics` (`mohawk-tokenomics-v1`)
* `MOHAWK Live Overview`
* `TPM Metrics`

Stop the stack with:

```bash
docker compose down
```

### Multi-Asset Bridge Settlement Configuration

Bridge settlement is optional and disabled by default. Set `settle=true` on `bridge_transfer(...)` requests to execute burn/release settlement after transfer verification.

Use these runtime environment variables to enable registry-backed multi-asset settlement routing:

```bash
# Comma-separated symbols allowed for settlement
export MOHAWK_BRIDGE_SETTLEMENT_ASSETS="MHC,USDX"

# Default utility coin ledger (MHC)
export MOHAWK_LEDGER_STATE_PATH="/var/lib/mohawk/mhc_state.json"
export MOHAWK_LEDGER_AUDIT_PATH="/var/lib/mohawk/mhc_audit.jsonl"
export MOHAWK_UTILITY_MINTER="protocol"

# Per-asset ledger overrides (USDX)
export MOHAWK_LEDGER_STATE_PATH_USDX="/var/lib/mohawk/usdx_state.json"
export MOHAWK_LEDGER_AUDIT_PATH_USDX="/var/lib/mohawk/usdx_audit.jsonl"
export MOHAWK_UTILITY_MINTER_USDX="protocol"
```

When configured, settlement enforces:

* Asset must be present in `MOHAWK_BRIDGE_SETTLEMENT_ASSETS`.
* Asset must have a configured settlement ledger.
* Burn on sender occurs before destination mint/release.
* Refund-to-sender executes if destination release fails.

---

## 🧪 Testing & Compliance

This repository maintains strict adherence to the MOHAWK runtime specifications.

### Go Runtime Tests

```bash
make test
make verify
go test ./...
```

### Python SDK Tests

```bash
make test-python-sdk
make demo-python-sdk
make python-all
```

### Production Readiness Check

Run the full production readiness gate (lint + tests + audit + strict auth/role smoke on host and container):

```bash
make production-readiness
```

---

## 📈 Benchmark Snapshot

Latest SDK benchmark snapshot from `sdk/python/tests/test_benchmarks.py` on March 14, 2026:

| Benchmark | Mean | Median | Throughput |
| --- | ---: | ---: | ---: |
| `test_verify_proof_performance` | 10.55 ms | 10.55 ms | 94.77 ops/s |
| `test_aggregate_nodes_performance` | 30.63 us | 25.20 us | 32,648 ops/s |
| `test_gradient_compression_performance` | 995.70 us | 944.57 us | 1,004 ops/s |

Reproduce locally:

```bash
cd sdk/python
python -m pytest tests/test_benchmarks.py --benchmark-only -q
```

---

## 🛡️ Verification & Monitoring

The system leverages a proof-driven monitoring strategy and production CI gates.

### GitHub Actions

All production-grade safety requirements are verified on every push:

* **Build and Test:** Go build/test, Wasm module build, capability validation, and Docker stack config.
* **Integrity Guard - Linter:** `golangci-lint`, `black --check`, and targeted `flake8` validation.
* **Performance Gate:** Benchmark regression checks for proof verification, aggregation, and gradient compression.
* **Proof-Driven Design Verification:** Capability and proof audit via `scripts/audit_proofs.sh`.
* **Capability Sync Check:** Runtime capability manifest validation.

### Observability Stack

* [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml)
* [monitoring/grafana/dashboards/](monitoring/grafana/dashboards/)
* [monitoring/grafana/dashboards/tokenomics.json](monitoring/grafana/dashboards/tokenomics.json)
* [cmd/tpm-metrics/main.go](cmd/tpm-metrics/main.go)

---

## 📦 Repository Structure

```text
Sovereign-Mohawk-Proto/
├── cmd/                    # Main application entry points
│   ├── orchestrator/      # Control plane + mTLS endpoint
│   ├── node-agent/        # Edge node runtime + libp2p transport
│   └── tpm-metrics/       # Prometheus exporter
├── internal/               # Core Go implementation
│   ├── accelerator/       # Device detection + quantization
│   ├── bridge/            # Route policy engine and typed proofs
│   ├── hva/               # Hierarchical planning logic
│   ├── hybrid/            # Hybrid SNARK/STARK verification
│   ├── ipfs/              # Checkpoint backend
│   ├── network/           # libp2p transport and gradient protocol
│   ├── pyapi/             # Python SDK C-shared library exports
│   ├── token/             # Utility coin ledger
│   ├── tpm/               # TPM attestation + mTLS
│   └── wasmhost/          # WebAssembly runtime
├── monitoring/            # Prometheus and Grafana assets
├── sdk/
│   └── python/
│       ├── mohawk/        # Python package
│       ├── examples/      # Usage examples
│       └── tests/         # Unit tests and benchmarks
├── proofs/                # Formal verification documents
├── scripts/               # Build, audit, and smoke-test scripts
├── wasm-modules/          # fl_task, flower_task, pytorch_task
└── README.md
```

---

## 🎯 What's New in This Release

### Platform Upgrade (v2.0.0a2)

✨ **New Features:**

* Python SDK v2 with accelerator, bridge, gradient, hybrid-proof, and utility-ledger APIs.
* libp2p gradient transport between node-agents and orchestrator.
* Route-policy bridge verification with default manifest fallback.
* TPM-backed mTLS control plane and strict auth smoke validation.
* Prometheus/Grafana observability stack and genesis testnet bootstrap.

🔧 **Technical Details:**

* Exported Go bridge now includes proof batching, hybrid verification, bridge transfer, device info, gradient compression, and utility-ledger operations.
* Python package version: `2.0.0a2`.
* Strict CI gates: build/test, linter, performance gate, capability sync, proof audit, and pages deploy.
* Benchmarked SDK mean latencies: 10.55 ms verify, 30.63 us aggregate, 995.70 us compression.

📚 **Documentation:**

* [sdk/python/README.md](sdk/python/README.md)
* [sdk/python/mohawk/client.py](sdk/python/mohawk/client.py)
* [sdk/python/examples/](sdk/python/examples/)
* [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml)
* [monitoring/grafana/dashboards/](monitoring/grafana/dashboards/)

See [CHANGELOG.md](CHANGELOG.md) for full release history.

---

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed feature timeline and development priorities.

### Current Phase: Platform Hardening & Testnet Operations (Q1 2026)

**Next Up:**

* CI-backed release packaging for the Python SDK
* Broader regional shard rollout beyond `local-us-east`
* Deeper hybrid-proof backend integrations
* Expanded testnet automation and dashboard coverage

---

## 📖 Documentation

* [WHITE_PAPER.md](WHITE_PAPER.md) - Protocol design and architecture
* [ACADEMIC_PAPER.md](ACADEMIC_PAPER.md) - Formal proofs and theorems
* [sdk/python/README.md](sdk/python/README.md) - Python SDK guide
* [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines
* [sdk/python/mohawk/client.py](sdk/python/mohawk/client.py) - Python client API reference

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

* Development setup
* Code style guidelines
* Testing requirements
* Pull request process

---

## 📜 License

This project is licensed under the **Apache License 2.0**. See the [LICENSE.md](LICENSE.md) file for details.

---

## 🔗 Links

* **GitHub:** [Sovereign-Mohawk-Proto](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
* **Twitter/X:** [@RyanWill98382](https://twitter.com/RyanWill98382)
* **Issues:** [Report a Bug](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
* **Discussions:** [Community Forum](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/discussions)

---

## Addendum: Human Impact & Governance Sovereignty

1. The Paradox of the Sovereign Protocol
While the Sovereign Mohawk Protocol is designed to be "Sovereign"—meaning it operates via decentralized consensus rather than centralized human authority—this creates a risk of Technological Determinism.

A system that answers to no one can inadvertently become a "Master" rather than a tool. We explicitly recognize that mathematical verification does not equal moral justification. A protocol may be "correct" in its execution of code while being "wrong" in its impact on human free will.

1. The "Seventh Theorem": Resistance to Commercial Capture
Current BFT (Byzantine Fault Tolerance) models focus on "liars" (adversarial nodes). We propose a transition toward defending against "owners" (economic consolidation).

Transparency of the Genesis Block: To prevent the Genesis Block from becoming a "Digital Board of Directors," the selection criteria for the initial 1,000 nodes must be publicly auditable, diverse in geography, and inclusive of non-commercial stakeholders.

The Anti-Greed Protocol: We must implement decay functions on node influence to ensure that "Health and Wealth" promises do not lead to a "lock-in" effect where users trade long-term agency for short-term convenience.

1. Protecting the "Thinker" over the "Consensus"
Standard Federated Learning prunes outliers to achieve accuracy. However, in human systems, the "outlier" is often the innovator or the dissenter.

Dissensus Preservation: The protocol shall include "Thinker Clauses" that prevent the automatic suppression of minority data paths, ensuring that "Sovereignty" includes the right to deviate from the planetary norm.

Legibility of the Sovereign Map: The "Sovereign Map" must not remain a black box. We commit to developing "Human-Readable Proofs" where the logic of the network is accessible to the average person, not just the cryptographer.

1. Accountability in Scaleless Systems
As the system scales toward 100M+ nodes, traditional regulation becomes functionally impossible.

Algorithmic Recourse: Every automated decision within the protocol must have a defined path for human appeal, ensuring that "messy" free will remains the final fail-safe against "perfect" algorithmic errors.

Privacy as Agency: Privacy in this network is not a "shield for owners" but a sanctuary for the individual. It must be architected to protect the user from the network owners, not the owners from public scrutiny.

### Final Declaration

We build this protocol to serve humanity, not to replace its judgment. The messiness of human choice is the only metric that cannot be optimized, and it is the only metric that matters.

---
*Built for the future of Sovereign AI.*

## Prior Art & Novelty Statement

This project publicly discloses (since [earliest commit date, e.g., early 2026]) a novel combination of hierarchical federated learning with zk-SNARK verifiable aggregation, 55.5% Byzantine resilience, 99.99% straggler tolerance, and extreme metadata compression at planetary scale. No prior systems combine these elements with formal verification across all dimensions. Public commits and X posts (@RyanWill98382) serve as timestamped evidence.
