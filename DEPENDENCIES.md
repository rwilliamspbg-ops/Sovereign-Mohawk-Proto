# License

This project is licensed under the **Apache License 2.0** (unless otherwise noted for third-party components).  
See the [LICENSE.md](LICENSE.md) file for the full text.

Portions of protocol implementation are marked **Patent Pending** (U.S. provisional filing, March 2026). This notice is informational and does not modify third-party or Apache-2.0 license terms.

For consolidated legal context, see [NOTICE.md](NOTICE.md).

Apache 2.0 is permissive: it allows broad use, modification, and distribution (including commercial), with patent grants from contributors and a requirement to preserve copyright notices.

## Third-Party Dependencies and License Implications

We rely on several open-source libraries and tools. Their licenses are compatible with Apache 2.0 in our usage (dynamic linking, no static bundling of GPL code into binaries for distribution). Key ones:

- **ORB-SLAM3** (from UZ-SLAMLab/ORB_SLAM3): GPLv3 (copyleft).  
  Used for on-device visual SLAM in Sovereign Map. We integrate via separate module / API boundary (e.g., subprocess or wrapped calls) to avoid creating a single derivative work under GPLv3 virality. If you build/distribute binaries that statically link or closely derive from ORB-SLAM3 code, your distribution must comply with GPLv3 (source release required). For our reference implementation, we treat it as a runtime dependency—users must install ORB-SLAM3 separately under its terms.  
  → Recommendation: If commercial/proprietary use is a future goal, consider permissive SLAM alternatives (e.g., open-vSLAM, DSO) in later versions.

- **Wasmtime** (WebAssembly runtime): Apache 2.0 / MIT dual. Fully compatible.

- **Go standard library & Wasmtime Go bindings**: BSD-3-Clause or similar permissive.

- **zk-SNARK libraries** (e.g., if using arkworks, gnark, or similar Rust/Go impls): Mostly MIT/Apache 2.0.

- Other (e.g., Helm charts, React dashboard deps, gRPC): Standard permissive (MIT, Apache 2.0).

**Full list of dependencies** (generated via go mod graph / npm list where applicable):  
[Insert output here, e.g., from `go list -m all` or a requirements.txt equivalent]

We make no claims of originality over third-party components. All usage follows their respective licenses. If you fork or extend this project, please preserve notices and comply with copyleft requirements where applicable.

Questions on licensing? Feel free to open an issue or DM @RyanWill98382.

## Runtime Dependency Baseline (Go Module)

Direct dependencies currently pinned in go.mod:

- github.com/consensys/gnark-crypto v0.20.1
- github.com/libp2p/go-libp2p v0.48.0
- github.com/multiformats/go-multiaddr v0.16.1
- github.com/prometheus/client_golang v1.23.2
- github.com/prometheus/client_model v0.6.2
- github.com/prometheus/common v0.67.5
- github.com/tetratelabs/wazero v1.11.0

Toolchain baseline:

- Go 1.25.9
- Lean 4 + Mathlib (pinned by proofs/lean-toolchain and Lake files)

## Upgrade Dependency Matrix (2026-2027)

This section maps dependency posture to the five strategic upgrades.

### 1) Zero-Knowledge Proof of Compute (PoC)
- Baseline: keep gnark-crypto verifier path for proof verification integration.
- Planned: add optional proving backend adapters only behind feature flags.
- Policy: no proving backend becomes default unless benchmark and security gates pass.

### 2) Dynamic Adaptive Differential Privacy (DADP)
- Baseline: use internal RDP accountant and policy modules.
- Planned: no mandatory external dependency for MVP phase.
- Policy: external analytics/simulation libraries are optional and must remain deterministic for audit replay.

### 3) Threshold FHE Aggregation
- Baseline: no FHE library is currently linked in core runtime.
- Planned: introduce threshold-capable FHE library in pilot phase only.
- Policy: requires security review, license review, and reproducible performance report before production enablement.

### 4) Formal Verification of PQC Migration Logic
- Baseline: Lean/Mathlib pipeline and CI proof workflows already present.
- Planned: targeted Mathlib module expansion for migration continuity theorems.
- Policy: zero-placeholder rule for release branches (no sorry, admit, or new axioms).

### 5) Incentivized Resource-Aware Scheduling
- Baseline: implement auction logic in internal scheduler modules first.
- Planned: optional optimization libraries only if deterministic scheduling and reproducible settlement remain intact.
- Policy: maintain auditable outcomes over raw optimization speed.

## Dependency Governance Rules

Any new dependency (runtime or build-time) must pass all of the following:

- Security: no unmitigated high-severity CVEs at adoption time.
- License: compatible with Apache-2.0 distribution strategy.
- Reproducibility: deterministic or replayable behavior for regulated audits.
- Maintainability: active upstream maintenance and pinned versions.
- Performance: validated against phase-specific latency and throughput budgets.

## Operational Commands

Use these to keep dependency inventories current:

```bash
go list -m all
go mod graph
go mod verify
```

For Lean proof dependencies:

```bash
cd proofs
lake update
lake build LeanFormalization
```
