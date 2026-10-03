# 🗺️ Sovereign-Mohawk Development Roadmap

## Last Updated

Aug 15, 2026

---

## Current Program Status

Sovereign-Mohawk has moved from early SDK bring-up into **mainnet-readiness gated operations**:

- [x] Core FL protocol, theorem-backed resilience, and baseline runtime complete
- [x] Real BN254 Groth16 verifier integrated
- [x] Hybrid SNARK/STARK verification paths integrated
- [x] WASM hash registry + hot reload integrated
- [x] Python SDK v2 surface and structured error-code mapping in place
- [x] Readiness gate, chaos gate, and weekly digest CI workflows active
- [x] Tokenomics + operational monitoring dashboards provisioned
- [x] **PQC Major Release:** Hybrid KEX + XMSS attestation + cryptographic migration epoch enforcement release complete

### Phase Tracker

- [x] **Phase 1 — Core Runtime & Verification:** COMPLETE
- [x] **Phase 2 — Mainnet-Readiness Gating:** COMPLETE
- [ ] **Phase 3 — v1.0.0 GA Closure:** IN PROGRESS

---

## What Is Left to Complete

### Current Phase: Phase 3 — v1.0.0 GA Closure 🚧 **IN PROGRESS**

**Program Stage:** Go-Live Formalization Complete

**Target:** Q2 2026

### A0. Mainnet-Readiness CI Gates (Merged)

- [x] Mainnet readiness gate workflow (`.github/workflows/mainnet-readiness-gate.yml`) active
- [x] Mainnet chaos gate workflow (`.github/workflows/mainnet-chaos-gate.yml`) active
- [x] Weekly readiness digest workflow (`.github/workflows/weekly-readiness-digest.yml`) active
- [x] CI monitoring smoke check in build/test workflow (`.github/workflows/build-test.yml`) active
- [x] PR build/test workflow narrowed to correctness-only Python SDK tests; benchmark-heavy suites run in `performance-gate.yml`

### A1. Security & Assurance (Critical Path)

- [ ] External security audit (runtime + SDK + bridge) — **corrected 2026-08-10, was incorrectly checked**: the CertiK engagement was scoped (`results/security-audit/audit_handoff_certik_2026-03-31.md`, `control_to_evidence_matrix_2026-03-31.md`) but never completed. `results/security-audit/audit_closure_report_2026-03-31.md` and `docs/CERTIK_AUDIT_SUMMARY.md` both record it in their own words: "Final auditor findings received: Pending" / "Formal remediation closure signed off: Pending" — no later evidence exists anywhere that this changed. What's real and complete instead: an internal code/configuration review with zero findings (`results/go-live/evidence/security_audit_report_2026-03-26.md`) — a materially weaker claim than "external security audit," since its own Method section describes review + smoke-test validation, not independent third-party testing.
- [ ] Penetration test across orchestrator/API and bridge settlement paths — **corrected 2026-08-10, was incorrectly checked**, same caveat as above: `results/go-live/evidence/penetration_test_report_2026-03-26.md` is real and complete, but its own Method section describes automated AuthN/AuthZ smoke validation (`scripts/strict_auth_smoke.py`, readiness/chaos gate output), not independent third-party penetration testing.
- [x] Threat-model refresh for mTLS control plane + internal metrics plane
- [x] Dependency vulnerability baseline and patch SLA policy
- [x] Runtime proof-verifier fail-closed boot enforcement (no silent disable path)
- [x] WASM verifier fallback moved to explicit CI/dev opt-in only

#### A1a. FIPS Compliance Hardening (Gap Alignment)

- [x] Publish FIPS profile target and scope (FIPS 140-2 transitional baseline, FIPS 140-3 target state)
- [x] Add cryptographic module inventory with boundary mapping and algorithm usage table
- [x] Add Go `crypto/fips140` runtime self-check in startup and CI evidence artifacts
- [x] Add FIPS mode regression tests for TLS/keygen/signing flows used by orchestrator and node-agent
- [x] Add operator runbook section for FIPS deployment posture, exceptions, and audit evidence capture
- [x] Add release-gate checklist item requiring FIPS evidence bundle before GA tag cut

### A2. TPM Attestation Completion

- [x] Replace remaining TPM stubs with full TPM 2.0 quote/verify flow
- [x] Remote attestation evidence format hardening and replay protection checks
- [x] Cross-platform validation matrix for attestation paths (Linux/Windows/macOS)

Automation now in place:

- Workflow: [.github/workflows/tpm-production-signoff.yml](.github/workflows/tpm-production-signoff.yml)
- Bundle generator: [scripts/build_tpm_signoff_bundle.py](scripts/build_tpm_signoff_bundle.py)
- Closure validator: [scripts/validate_tpm_attestation_closure.py](scripts/validate_tpm_attestation_closure.py)
- Closure summary generator: [scripts/generate_tpm_closure_summary.py](scripts/generate_tpm_closure_summary.py)

Current closure-prep evidence:

- Matrix (md): [results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.md](results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.md)
- Matrix (json): [results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json](results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json)
- Linux validation evidence: [results/go-live/evidence/tpm_attestation_linux_validation_2026-03-28.md](results/go-live/evidence/tpm_attestation_linux_validation_2026-03-28.md)
- Closure validator report (md): [results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md](results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md)
- Closure validator report (json): [results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json](results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json)

TPM production closure sign-off (2026-04-11):

- Matrix (md): [results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.md](results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.md)
- Matrix (json): [results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.json](results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.json)
- Closure validator report (md): [results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.md](results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.md)
- Closure validator report (json): [results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.json](results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.json)
- Closure summary (md): [results/go-live/evidence/tpm_closure_summary_2026-04-11.md](results/go-live/evidence/tpm_closure_summary_2026-04-11.md)
- Attestation state: [results/go-live/attestations/tpm_attestation_production_closure.json](results/go-live/attestations/tpm_attestation_production_closure.json)
- Workflow run: [TPM Production Sign-Off #24285287716](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/runs/24285287716)

### A3. Readiness-to-Production Operations

- [x] Publish operator runbook for incident response + recovery drills
- [x] Define and version SLO/SLI set (readiness, recovery latency, proof latency)
- [x] Add alert routing/escalation playbook for readiness and chaos failures
- [x] Add per-alert runbook links for fail-fast remediation
- [x] Constrained-runtime transport profile documented (`MOHAWK_DISABLE_QUIC=true`) to avoid UDP buffer instability where host sysctl tuning is unavailable

### A4. Performance and Scale Sign-off (Critical Path)

- [ ] 1M+ node aggregation rehearsal with reproducible benchmark artifacts — **corrected 2026-08-10, was incorrectly checked**: no artifact substantiating a 1M-node rehearsal exists anywhere in this repository (verified via a full-repo search for any "1M node"/"million node" reference). This item previously contradicted "2026 Success Metrics" below, which correctly lists the same 1M+ node exercise as not yet done. Real, CI-verified scale evidence in this repo tops out at 500-1,500 nodes (`.github/workflows/swarm-runtime-matrix.yml`, `captured_artifacts/500node_scale_test_manifest.json`) and a separate 10k-node run (`captured_artifacts/fedavg_10k_node_runtime_evaluation_2026-04-13.md`). Still open at 1M scale; see the next item for a real (not 1M-scale) replacement of what this repo can currently prove. — **refined 2026-08-15**: the "500-1,500 nodes" framing above conflates two different kinds of evidence and should not be read as a graduated scale ladder. The 500-node figure is the real deployment test below. The 1,500-node figure (`captured_artifacts/loaded_1500node_stress_capture_2026-04-13.md`) and the 10k-node figure are both Go unit-test profile-validation runs completing in near-zero elapsed time — explicitly disclaimed in their own text as "not a long-running distributed soak test," not deployment evidence. Don't cite them alongside the 500-pod test as comparable real-world scale points.
- [x] Real multi-hundred-node Kubernetes deployment test (2026-08-10) — see [results/go-live/evidence/k8s_scale_deployment_test_2026-08-10.md](results/go-live/evidence/k8s_scale_deployment_test_2026-08-10.md), reproducible via [deploy/kubernetes/scale-test/README.md](deploy/kubernetes/scale-test/README.md). 500 real Kubernetes pods (unmodified orchestrator/node-agent binaries, real mTLS identity per replica, real gradient submissions) stable and healthy; 700 destabilizes the control plane due to Docker Desktop disk I/O, not memory/CPU (root-caused, not just observed). Includes real security tests (mTLS enforcement, wrong-token rejection) and real performance data (~31ms mean gradient-submit latency under contention, 5544/5544 TPM verifications successful). Explicitly **does not** claim 1M-node evidence — see the item above and the doc's own "What this does and does not establish" section.
- [ ] **Added 2026-08-15**: real multi-host / WAN distributed evidence at any scale. Every real deployment artifact in this repo to date, including the 500-pod test above, ran on a **single host** (one laptop's `kind` cluster, per the evidence doc's own environment description). No multi-node or WAN run exists anywhere in the repo (verified: zero "WAN" references repo-wide). This is a sharper near-term gap than the 1M-node target — a single real multi-host run, even at modest node counts, would establish something the current evidence base cannot: that the control/data planes work at all across host boundaries, not just across pods sharing one kernel.
- [x] End-to-end latency validation under failure injection scenarios
- [x] Single-host libp2p relay/hole-punch transport evidence captured for the real transport code paths in [results/go-live/evidence/distributed_systems_transport_evidence_2026-08-10.md](results/go-live/evidence/distributed_systems_transport_evidence_2026-08-10.md) — this is real transport-path evidence on one host and explicitly does not claim WAN/geographic distribution or TPM attestation
- [x] Python-vs-Go bridge compression overhead profiling report with optimization decisions
- [x] CI automation for bridge compression benchmark artifact publishing
- [x] Release benchmark evidence index automation
- [x] Golden-path end-to-end execution artifact generation

### A5. Release Packaging

- [x] Finalize v1.0.0 release candidate checklist
- [ ] Cut GA tag
- [x] Publish deployment guide for genesis-to-production rollout path

### A6. Documentation Completeness (Gap Alignment, added 2026-08-15)

- [ ] Replace placeholder scaffolds under `docs/architecture/`, `docs/guides/`, `docs/api/`, `docs/security/`, and `docs/performance/` with real content. Verified 2026-08-15 and re-verified 2026-10-03: **31 of the 38 markdown files** in these directories (e.g. `docs/architecture/BYZANTINE_RESILIENCE.md`, `docs/guides/OPERATIONS.md`, `docs/security/INCIDENT_RESPONSE.md`, `docs/API_REFERENCE.md`, `docs/ARCHITECTURE.md`, `docs/DEPLOYMENT.md`) contain only the identical stub text "Scaffold document created to preserve canonical documentation links. See docs/INDEX.md..." — not thin drafts, but non-content. `docs/guides/GETTING_STARTED.md` is the one real exception. Note the irony worth fixing first: `docs/security/INCIDENT_RESPONSE.md` is a scaffold in a repo whose single GA blocker is an external security audit.
- [ ] Publish a rendered gRPC/REST API reference. Currently only the raw `api/federation/federation.proto` exists; there is no generated or hand-written reference doc.
- [ ] Note: README, the Flower-compatible quickstart, `make` targets, `genesis-launch.sh`, and the Helm/Kind deployment docs (`helm/sovereign-mohawk/README.md`, `deploy/kubernetes/scale-test/README.md`) were verified 2026-08-15 as genuinely substantive — this gap is specifically the `docs/` subdirectory scaffolds and API reference, not the top-level onboarding path.

### A7. Formal Verification Remaining Gaps (Gap Alignment, added 2026-08-15)

Verified against `proofs/FORMAL_TRACEABILITY_MATRIX.md` as of the 2026-08-10 commit touching `proofs/`: zero `sorry`s remain across `proofs/LeanFormalization`/`Specification`/`Refinement`, and the eight axioms present (`Refinement/MultiKrum.lean`) are documented, CI-allowlisted IEEE-754 non-NaN comparison facts, not placeholders. Two concrete gaps were tracked here rather than as a general "formalization incomplete" note. **Split into three items on 2026-10-03** — the original two-item framing checked both boxes `[x]` while the second item's own text said part of it stayed open, which made the checkbox unreadable.

- [x] Close the full RDP → (ε, δ)-DP conversion proof. **Merged 2026-08-15**: [#174](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/pull/174) adds `proofs/Refinement/RDPLogBound.lean` (`rdpLog_sandwich`/`rdpToApproxDP_bound`), a computable two-sided rational bound on `Real.log` closing this gap without needing `Real.log` itself to be computable — see the PR and `proofs/FORMAL_TRACEABILITY_MATRIX.md` row 13 for the full technical reasoning, including the deliberate precision tradeoff (a coarse-but-general bound, not Taylor-tight).
- [x] Wire the real Groth16/BN254 circuit (`internal/zksnark_circuit_verifier.go`, genuine trusted setup) into production call sites. **Merged 2026-08-15**: [#173](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/pull/173) wires it additively into `pyapi`'s `VerifyZKProof`/`BatchVerifyProofs` and `hybrid`'s `SNARKVerifier`/`VerifyHybrid` (legacy no-commitment callers unaffected). Confirmed during that work that `internal/batch/aggregator.go` was never actually a third call site needing this (it doesn't call the affected verify functions at all).
- [ ] **Open (split out 2026-10-03).** Formalize the circuit itself in Lean. `Theorem5Cryptography.lean` still describes only an abstract constant-operation cost model — it does not formalize the compiled R1CS circuit, its `groth16.Setup`, or MiMC's collision resistance. Two sub-gaps, both still open:
  - **Trusted setup is not a production ceremony.** The setup is a single in-process `groth16.Setup` call, so the toxic waste is momentarily held by whichever process runs the initialization. It is lazy-loaded (`sync.Once`) so the cost is paid only by callers that use it, but that is a performance fix, not a ceremony.
  - **Lean cryptography model.** Assessed 2026-08-15 against pinned Mathlib: real elliptic-curve group law and generic bilinear-map machinery exist, but there is **zero pairing/Tate-Weil machinery and zero computational-hardness (q-SDH) formalization anywhere in Mathlib**. Those two carry Groth16's actual security content, and building either is a multi-month from-scratch effort, not a bounded PR. An explicit-extractor knowledge-soundness restatement was assessed and rejected as content-free (the existing witness is already, in effect, a constructive extractor). Decision of record: keep this claim scoped as the abstract constant-operation model and revisit only if Mathlib gains pairing/hardness infrastructure upstream. See `proofs/FORMAL_TRACEABILITY_MATRIX.md` row 5, "Scope, explicitly not closed by this pass" items (1) and (3).

### Phase 3 Closure Checklist (Current Evidence)

- [x] Release performance evidence automation active:
  - Evidence generator: [scripts/generate_release_performance_evidence.py](scripts/generate_release_performance_evidence.py)
  - Evidence index: [results/metrics/release_performance_evidence.md](results/metrics/release_performance_evidence.md)
- [x] Bridge compression profiling report published:
  - Report: [results/metrics/bridge_compression_benchmark_compare.md](results/metrics/bridge_compression_benchmark_compare.md)
- [x] Aggregate endpoint-style integration coverage in place:
  - Tests: [internal/pyapi/api_aggregate_integration_test.go](internal/pyapi/api_aggregate_integration_test.go)
- [x] Multi-Krum internal runtime enforcement in aggregation path:
  - Runtime: [internal/aggregator.go](internal/aggregator.go)
  - Bridge usage: [internal/pyapi/api.go](internal/pyapi/api.go)
- [x] Versioned SLO/SLI baseline published:
  - Baseline (md): [results/go-live/evidence/slo_sli_baseline_2026-03-28.md](results/go-live/evidence/slo_sli_baseline_2026-03-28.md)
  - Baseline (json): [results/go-live/evidence/slo_sli_baseline_2026-03-28.json](results/go-live/evidence/slo_sli_baseline_2026-03-28.json)
- [x] Failure-injection latency validation artifacts published:
  - Validator: [scripts/validate_failure_injection_latency.py](scripts/validate_failure_injection_latency.py)
  - Report (md): [results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md](results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md)
  - Report (json): [results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json](results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json)
- [x] v1.0.0 RC checklist and rollout guide published:
  - Checklist: [RELEASE_CHECKLIST_v1.0.0_RC.md](docs/archive/root-cleanup-2026-07/RELEASE_CHECKLIST_v1.0.0_RC.md)
  - Deployment guide: [DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md](docs/archive/root-cleanup-2026-07/DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md)

**Exit Criteria for v1.0.0 GA:**

- [ ] Security audit completed with no unresolved critical findings — **corrected 2026-08-10, was incorrectly checked**; see A1 above, the external audit engagement remains pending, not completed
- [x] TPM attestation path fully enabled in production mode
- [ ] 1M-scale rehearsal passed with documented SLO results — **corrected 2026-08-10, was incorrectly checked**; see A4 above, no 1M-scale evidence exists in this repository. A real, honestly-scoped 500-node deployment test now exists (A4, added 2026-08-10) with genuine security/performance data, but 500 nodes does not satisfy a "1M-scale" claim and this item stays unchecked on that basis.
- [x] Operations runbook published and exercised in drills

**As of this correction, GA is not actually exit-criteria-complete**: 1 of 4 criteria above requires real work still not done (an actual completed external audit) before the "Cut GA tag" item in A5 should be considered unblocked on that ground. The scale criterion now has a real, honestly-scoped substitute (see A4) rather than an unsubstantiated number, but remains formally unchecked here since it doesn't reach the "1M-scale" bar as originally written — whether that bar itself should be revised is a scope decision, not something resolved by this update.

---

## Phase 4: Blockchain & Incentive Layer ⏭️ **UPCOMING**

**Target:** Q3 2026

- [ ] Smart-contract proof verification flow (initial chain set)
- [ ] Incentive/staking design and validation for node participation
- [ ] Dispute and slashing/reputation policy implementation
- [ ] Multi-chain bridge expansion beyond current route-policy baseline

---

## Phase 5: Ecosystem Expansion 🔮 **FUTURE**

**Target:** Q4 2026+

- [ ] Additional SDKs (JavaScript/TypeScript first, then Rust/Swift/Java)
- [ ] Enterprise/reference deployments and case studies
- [ ] Research partnerships and reproducibility toolkit maturation
- [ ] Developer ecosystem growth programs

---

## Deferred / Optional Backlog

- [ ] Sphinx docs pipeline + hosted API site
- [ ] Type stubs (`.pyi`) completeness pass for SDK ergonomics
- [ ] Notebook pack refresh with end-to-end production scenarios
- [ ] Fuzzing expansion for C bridge + serialization boundaries
- [ ] Optional OpenTelemetry distributed tracing rollout
- [ ] Flower-compatible client integration plan and example ports (see [docs/flower-integration.md](docs/flower-integration.md))

---

## Concrete Execution Plan

This plan turns the roadmap priorities into the next execution sprints so contributors can pick up a scoped task and finish it with clear acceptance criteria.

> **Rewritten 2026-10-03.** Sprint 1 and Sprint 2 (below, retained for history) both completed in April 2026. They stayed in this section as the routing target for `CONTRIBUTING.md`, which meant new contributors were directed at finished work. Sprints 3–5 below come from a full-repo audit run 2026-10-03 (build, vet, `go test ./...`, `go mod tidy`, `govulncheck`, per-package coverage, workflow and roadmap claim verification).

### Sprint 3: Claim Integrity (week 1) — ✅ COMPLETE

No new engineering; making the docs match artifacts. Cheap, and it makes every later claim defensible.

- [x] S3.1 Split A7 into three items so the Lean cryptography model reads as open rather than buried inside a `[x]` checkbox (done 2026-10-03)
- [x] S3.2 Rebuild `CHANGELOG.md` for the 2026-05-11 → 2026-10-03 gap; 321 commits had gone unrecorded (done 2026-10-03)
- [x] S3.3 Delete `test/attestation_test.go.disabled` — disabled test with an unresolved `// adjust import if path differs` comment that had never run (done 2026-10-03)
- [x] S3.4 Correct the "High-Impact Areas" list, which still advertised two A7 items as remaining after they were closed (done 2026-10-03)
- [ ] S3.5 Decide `internal/thresholdagg` (open, needs a maintainer call): the package sums **plaintext `int64`** and says so in its own doc comment, but compiles into no binary — it has zero production importers, only its own tests. Two viable options, both defensible: (a) delete it and `test/threshold_aggregation_test.go` alongside it, or (b) keep it but move it under a build tag so it is unambiguously not a shipped primitive. Leaving it as-is is the one option that isn't — 100% coverage makes it look load-bearing when it provides zero confidentiality, in a security protocol.
- [x] S3.6 Squash the 6 duplicate cherry-picks of the Grafana token fix and 4 of the `TransferWithControls` refactor in the 2026-09-29 → 2026-10-01 window before GA — 29 commits there carry only 18 distinct changes (deferred to pre-GA cleanup)

### Sprint 4: Coverage Blind Spot (week 2)

**S4.1 done 2026-10-03.** Added `-coverpkg=./internal/...` to `go-test.yml`. This immediately corrected a wrong number: total coverage is **68.6%**, not the 45.3% first reported. The 11 packages that appeared to contribute 0% were not uncovered — Go simply wasn't attributing the `test/` package's coverage to them. They are individually well covered (`internal/accelerator` functions at 83–100%, `internal/metrics` at 55–90%).

- [x] S4.1 Add `-coverpkg=./internal/...` to `go-test.yml` so per-package numbers are honest (done 2026-10-03)
- [x] S4.2 Cover the genuinely thin packages the corrected numbers exposed. **Done 2026-10-03 for the two worst:** `internal/cluster` 0.0% → **100%** (all 8 functions) and `internal/federation`'s `dp_tier_tracking.go` 0.0% → 93–100% across 11 of 14 functions. Two real bugs found and fixed in the process (below). Total coverage 64.1% → 68.6%. Still thin: `internal/hybrid` (2.5%), `internal/ipfs` (4.4%), `internal/network` (4.5%), and `CoordinatorWithDP`'s `Start`/`Stop`/`GetDPStats`/`NewCoordinatorWithDP`, which need a live coordinator.
- [x] S4.4 Publish the coverage badge. **Done 2026-10-03.** `go-test.yml` already generated `test-results/go-coverage-summary.txt` on every run and uploaded it as an artifact, but nothing surfaced it. Added `scripts/generate_coverage_badge.py` (tested against a real summary plus five adversarial inputs: missing file, no total line, empty file, multiple totals, threshold boundaries) and `.github/workflows/update-go-coverage-badge.yml`, which downloads the `go-test-report` artifact from the triggering `Go Test` run and publishes a shields.io endpoint badge to the existing `badges` branch, following the `update-release-performance-badge.yml` pattern. README badge added. **The badge renders nothing until the workflow first runs** — the `badges` branch exists but has no `go_coverage_badge.json` yet.
- [ ] S4.5 Review the 43-workflow CI surface (5,775 lines of YAML, 18,308 lines of `scripts/`) against 19,649 lines of Go. Measure per-workflow runtime via `gh run list` and drop gates that no longer gate anything real. **Blocked 2026-10-03:** `gh` is not installed on this machine, so per-workflow runtimes cannot be retrieved without installing and authenticating it. Note this session also *added* workflows, so the count is now 45, not 43.
- [x] S4.6 Add `go test -race` to CI. **Added 2026-10-03** as a second job (`go-test-race`) in `go-test.yml`, with `CGO_ENABLED: "1"` and a `command -v gcc` preflight. No workflow previously ran the race detector, so the concurrent-access tests in `internal/cluster` and `internal/federation` were never race-checked. **Not verified locally** — this machine has no C compiler (no gcc/clang, and WSL has neither gcc nor Go), so the job's runtime behavior is untested; it depends on `ubuntu-latest` shipping gcc as documented.

#### S4.3 rescoped: cgo-gated tests were vanishing silently (2026-10-03)

The original S4.3 read "cover `internal/pyapi`". That was based on a wrong premise: `internal/pyapi` already has **four** test files. They all carry `//go:build cgo`, so with `CGO_ENABLED=0` (the default wherever no C compiler is installed) Go reports `[no test files]` instead of failing. The entire Go↔Python bridge test suite can disappear with **no error and a green build**.

The four affected files: `api_aggregate_integration_test.go`, `api_security_test.go`, `api_zkproof_commitment_test.go`, `compress_benchmark_test.go`.

CI is *not* currently affected — `ubuntu-latest` ships gcc, so `CGO_ENABLED` defaults to 1 there and those tests do run. The exposure is developer machines and any future runner without a C toolchain. Hardened anyway, because "silently skipped" is the failure mode most likely to go unnoticed for years:

- `go-test.yml` now sets `CGO_ENABLED=1` explicitly rather than relying on the runner default.
- Added an **assertion step** that fails the build if `internal/pyapi` reports `skip`/`[no test files]` or has no passing results. Verified against four scenarios: the real cgo-disabled report from this machine (correctly fails), a healthy cgo report (passes), the package absent (fails), and the package failing (fails).

Actual pyapi coverage can therefore only be measured on a cgo-enabled toolchain — worth doing on a Linux runner before drawing conclusions about that package.

#### Bugs found and fixed while adding coverage (2026-10-03)

Both were found by writing tests that assert correct behavior first, watching them fail against the existing code, then fixing — so each fix is evidence-backed rather than speculative.

1. **`internal/cluster` slice aliasing** (`topology.go`). `AssignAggregator` stored `aggregators[:numPaths]`, sharing the caller's backing array — a later mutation of the caller's slice would silently reroute an edge node's gradients. `GetAssignedAggregators` returned the topology's internal slice, letting callers mutate cluster routing without holding the lock. Both now copy. Found via `TestAssignAggregatorCopiesCallerSlice` and `TestGetAssignedAggregatorsReturnsDefensiveCopy`.
2. **`internal/federation` DP budget ignored its own configuration** (`dp_tier_tracking.go`). `RecordAggregation` compared against a hardcoded `globalEps > 100.0`, ignoring the `maxGlobalEpsilon` passed to `NewDPTierTracker` entirely, and using a raw float comparison rather than the accountant's proper RDP → (ε, δ) conversion. Now calls `globalBudget.CheckBudget()`, which enforces the configured budget with the correct conversion. Found via `TestRecordAggregationEnforcesConfiguredGlobalBudget` — with a configured budget of 1000, a *single* aggregation tripped the hardcoded limit (ε≈185).

### Sprint 5: Real Distributed Evidence (weeks 3–5)

The actual GA blocker, and the only sprint that changes what the project can claim. Every real deployment artifact in this repo to date ran on a single host.

- [ ] S5.1 Stand up ≥3 hosts (or cheap VMs), deploy unmodified orchestrator/node-agent binaries via `deploy/kubernetes/scale-test/` with real mTLS identity. Any node count ≥3 across real host boundaries — this closes A4's WAN gap at an achievable scope and establishes something single-host evidence cannot.
- [ ] S5.2 Root-cause the 700-pod control-plane destabilization (A4 attributes it to Docker Desktop disk I/O). A real single-host limit worth understanding before scaling out.

### Sprint 6: Documentation (parallel, weeks 3–6)

31 of 38 markdown files across `docs/{architecture,guides,api,security,performance}` are the identical stub string "Scaffold document created to preserve canonical documentation links." Not thin drafts — non-content.

- [ ] S6.1 Write the highest-traffic six: `docs/security/INCIDENT_RESPONSE.md`, `docs/architecture/ARCHITECTURE.md`, `docs/guides/OPERATIONS.md`, `docs/API_REFERENCE.md`, `docs/DEPLOYMENT.md`, `docs/security/BYZANTINE_RESILIENCE.md`.
- [ ] S6.2 Render the gRPC reference from `api/federation/federation.proto` (A6).

### Sprint 1: Documentation and Telemetry Foundation — ✅ COMPLETE (2026-04-28)

- [x] QW1: Add strategy docstrings to the six Lean theorem files in `proofs/LeanFormalization/`
- [x] QW2: Export the five runtime health metrics from the aggregator, accountant, and orchestrator paths
- [x] QW3: Publish the Lean contributor playbook at `docs/CONTRIBUTING_LEAN_PROOFS.md`
- [x] Exit criteria: docstrings merged, metrics visible at `/metrics`, and the playbook reviewed by a contributor

### Sprint 2: Proof Hardening and Test Coverage — ✅ COMPLETE (2026-04-28)

- [x] P1.1: Formalize Chernoff bounds in a new Lean module and wire it into the traceability matrix
- [x] P2.1: Implement Lean proof metrics extraction for baseline analysis
- [x] P2.2: Add proof regression detection to CI with non-blocking PR comments
- [x] P3.1: Add property-based tests for the core formal claims
- [x] Exit criteria: new proof module compiles, metrics pipeline runs on current proofs, and the new test layer is green

### Dependencies And Ordering

- **S4.1 gates S4.2 and S4.3** — without `-coverpkg`, per-package numbers stay blind. Done 2026-10-03, and it immediately changed the target list: `internal/metrics` and `internal/accelerator` turned out to be well covered, while `internal/cluster` (0.0%) and `internal/federation` (2.9%) are the real gaps.
- **Sprint 3 gates everything.** Claim integrity is a day of work that makes Sprints 4–6 defensible.
- **Sprint 5 is the long pole** and the only genuine differentiator; start host provisioning early even though the deploy work lands later.
- **Sprint 6 runs parallel** — independent prose, no dependency on the others.
- Historical ordering, retained from Sprints 1–2: QW1/QW2/QW3 were the fastest path to contributor velocity and operator visibility; P1.1 before P1.2 (real-valued convergence depends on the probabilistic extension); P2.1 before P2.2 (the CI workflow compares extracted metrics); P3.1 before the fuzzing and large-scale simulation work (the property suite serves as the first regression net).

### Blocked, Not Actionable by Engineering

The **external security audit and penetration test** (A1) are the one true GA blocker. They require budget and a signed engagement, not a PR — no code change closes them. GA exit criteria cannot be met without this.

---

## 2026 Success Metrics (Remaining)

### v1.0.0 GA Metrics

- [ ] 99.99% service uptime over rolling 30-day production window
- [ ] Zero unresolved critical security vulnerabilities
- [ ] <100ms end-to-end critical-path latency target under normal load
- [ ] Successful 1M+ node aggregation exercise with published evidence

### Ecosystem Metrics

- [ ] Public release cadence sustained post-v1.0.0
- [ ] Community contributions trend upward quarter-over-quarter
- [ ] Initial production adopters running documented deployments

---

## How to Contribute

We welcome contributions at every phase. Start with the [Concrete Execution Plan](#concrete-execution-plan) above, then see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Current priority issues
- Development setup
- Pull request process
- Coding standards

**High-Impact Areas:**

- Security hardening and audit remediation (Phase 3) — TPM, FIPS, threat-model, and WASM hardening are done; the external audit/pentest itself is the one remaining item
- Multi-host/WAN deployment evidence at any scale (Phase 3, A4)
- Documentation completeness for `docs/architecture/`, `docs/guides/`, `docs/api/`, `docs/security/`, `docs/performance/` (Phase 3, A6)
- Remaining formal-verification gaps: Lean cryptography model for the Groth16 circuit, and a production trusted-setup ceremony (Phase 3, A7 — the RDP→(ε,δ) conversion and Groth16 production wiring are closed as of 2026-08-15)
- Blockchain incentive and verification layer work (Phase 4)

---

## Revision History

| Date | Version | Changes |
| ---- | ------- | ------- |
| 2026-10-03 | 4.0 | Independent full-repo audit pass (`go build`, `go vet`, `go test ./...`, `go mod tidy`, `govulncheck`, per-package coverage, roadmap claim re-verification). Build/vet/tests/tidy all clean; `govulncheck` reports 0 vulnerabilities in reachable code; 8 Lean axioms confirmed as documented IEEE-754 non-NaN facts, all in `Refinement/MultiKrum.lean`. Changes made: **A7 restructured** from 2 items to 3 — it previously checked both boxes `[x]` while the second item's own text said the Lean cryptography model stayed open, making the checkbox unreadable; the open item is now a separate `[ ]` with both sub-gaps spelled out (non-ceremony trusted setup, and the Mathlib pairing/q-SDH absence that makes the Lean model a multi-month effort). **"High-Impact Areas" corrected** — it still advertised the RDP conversion and Groth16 wiring as remaining work 18 days after both were closed. **A6 sharpened** with the re-verified figure (31 of 38 files are scaffolds, not "nearly every"). **Concrete Execution Plan rewritten**: Sprints 1 and 2 both completed in April 2026 but remained the section `CONTRIBUTING.md` routes contributors to, so new contributors were being pointed at finished work; Sprints 3–6 added from audit findings, with Sprint 3 (claim integrity) marked complete. Added an explicit "Blocked, Not Actionable by Engineering" note that the external security audit and pentest — the one true GA blocker — cannot be closed by any code change. Noted that the 2026-09-29→2026-10-01 window carries 29 commits for only 18 distinct changes (6 duplicate cherry-picks of the Grafana token fix), which should be squashed before GA. |
| 2026-08-15 | 3.9 | Folded in an independent gap-analysis verification pass (four parallel research agents against current repo state). Refined A4's "500-1,500 nodes" framing: the 1,500/10k-node figures are Go unit-test profile runs, not deployment evidence, and should not be cited alongside the real 500-pod test. Added a new A4 item: zero multi-host/WAN evidence exists at any scale (every real artifact to date ran on one laptop). Added new A6 (Documentation Completeness) tracking the placeholder scaffolds under `docs/architecture/`, `docs/guides/`, `docs/api/`, `docs/security/`, `docs/performance/` and the missing rendered API reference — confirmed the top-level README/quickstart/Helm docs are NOT part of this gap. Added new A7 (Formal Verification Remaining Gaps): confirmed zero sorries and all eight `Refinement/MultiKrum.lean` axioms are documented/justified, with two genuine open items — the RDP→(ε,δ)-DP conversion proof and wiring the real Groth16/BN254 circuit into production call sites, both since closed via [#174](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/pull/174) and [#173](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/pull/173) respectively (merged 2026-08-15). Also confirmed TPM cross-platform evidence, FIPS hardening, threat-model refresh, and WASM verifier restrictions are all already complete as tracked above (no roadmap change needed there, just independent confirmation) and that the ops runbook (A3) is substantively real, not thin. |
| 2026-08-10 | 3.8 | Added single-host libp2p relay/hole-punch evidence for the actual transport code paths in `internal/network/transport.go` via `go run ./cmd/transport-probe` (local echo + relay-flow), and documented the scope explicitly: this is real transport-path evidence on one host, not WAN/geographically distributed evidence. Also documented that TPM attestation was scoped out because no `/dev/tpm*` device was present in this Codespace. See `results/go-live/evidence/distributed_systems_transport_evidence_2026-08-10.md`. |
| 2026-08-10 | 3.7 | Added real, reproducible evidence at A4: a 500-real-pod Kubernetes deployment test (unmodified orchestrator/node-agent binaries, real mTLS identity, real gradient submissions and security tests) as an honestly-scoped, real replacement for the still-corrected "1M+ node" claim -- explicitly not claiming 1M-node evidence. See `results/go-live/evidence/k8s_scale_deployment_test_2026-08-10.md` and `deploy/kubernetes/scale-test/`. Along the way, found and fixed a real bug: `helm/sovereign-mohawk/values.yaml`'s node-agent/orchestrator image references didn't match what CI actually publishes, so `make deploy-to-kind` would have failed with `ImagePullBackOff`. |
| 2026-08-10 | 3.6 | GA-readiness audit against real evidence (not just the checkmarks): corrected 4 checkboxes across A1 and A4 and the v1.0.0 GA Exit Criteria that were marked complete but weren't. External security audit and penetration test: the CertiK engagement was scoped but never completed (its own closure report says findings are still "Pending"); what's real instead is a weaker internal code/config review. 1M+ node aggregation rehearsal: no artifact anywhere in this repo substantiates it (real scale evidence tops out at 500-1,500 nodes); this item previously contradicted the still-correctly-unchecked "2026 Success Metrics" entry for the same claim. TPM attestation and operations-runbook drills were verified genuine and left checked. |
| 2026-08-10 | 3.5 | Closed Sprint 2's P3.1: added property-based tests for rows 12 (`internal/multikrum_property_test.go`) and 13 (`test/rdp_accountant_property_test.go`) of the formal traceability matrix, generating random inputs rather than fixed vectors to check the invariants already established by Refinement/MultiKrum.lean and Refinement/RDPAccountant.lean; marked Sprint 2's exit criteria complete |
| 2026-04-28 | 3.4 | Completed Sprint 1 and Phase 2 hardening deliverables: Lean proof metrics extraction, theorem dependency audit, proof-regression CI workflow, and traceability expansion for Theorem4ChernoffBounds/Theorem6ConvergenceReals |
| 2026-04-28 | 3.3 | Added a concrete two-sprint execution plan with explicit dependencies, exit criteria, and contributor routing for the next roadmap slice |
| 2026-04-11 | 3.2 | TPM production closure signed off: cross-platform matrix PASS, closure validation PASS, production attestation set to approved, and CI workflow evidence linked |
| 2026-04-09 | 3.1 | Closed runtime hardening docs gap: verifier fail-closed startup and constrained-runtime QUIC disable profile captured across deployment/security/readme guidance |
| 2026-04-05 | 3.0 | Closed FIPS governance hardening items: profile scope/boundary inventory, regression tests, operator runbook guidance, and release-gate evidence requirement |
| 2026-04-05 | 2.9 | Added A1a FIPS compliance hardening TODOs to align roadmap with ecosystem compliance tracking |
| 2026-03-28 | 2.8 | Added TPM attestation closure-prep artifacts: cross-platform matrix, Linux validation evidence, closure attestation state, and validator reports |
| 2026-03-28 | 2.7 | Added versioned SLO/SLI baseline, failure-injection latency validation artifacts, v1.0.0 RC checklist, and genesis-to-production deployment guide; marked related Phase 3 items complete |
| 2026-03-28 | 2.6 | Added strict/advisory go-live mode reporting, monitoring smoke CI, release performance evidence workflow, and golden-path E2E artifact generation |
| 2026-03-28 | 2.5 | Added Phase 3 closure checklist with direct evidence links for benchmark CI/report and aggregate integration coverage |
| 2026-03-28 | 2.4 | Added bridge compression benchmark CI + artifact publication and marked profiling/reporting milestones complete |
| 2026-03-26 | 2.3 | Added PQC Major Release completion marker and mirrored executive-status language |
| 2026-03-26 | 2.2 | Formal go-live gate artifacts introduced; runbook publication and escalation-playbook tasks marked complete |
| 2026-03-15 | 2.1 | Maintenance refresh: explicit Phase 2 COMPLETE / Phase 3 IN PROGRESS markers and merged CI gates tracked under current phase |
| 2026-03-15 | 2.0 | Roadmap refocused on remaining work from current mainnet-readiness state |
| 2026-02-20 | 1.0 | Initial roadmap published |

---

## Questions or Feedback?

- **GitHub Discussions:** [Community Forum](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/discussions)
- **Twitter/X:** [@RyanWill98382](https://twitter.com/RyanWill98382)
- **Email:** [Create an issue](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues/new)

---

*Built for the future of Sovereign AI.*
