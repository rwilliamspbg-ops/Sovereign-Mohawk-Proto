# Changelog

All notable changes to the Sovereign-Mohawk Protocol are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed - Claim/Artifact Drift (2026-05-11 → 2026-10-03)

This entry restores the changelog after a five-month gap. All items below are
derived from the commit history in the stated window; nothing here is new work.

#### Removed

- **Dead test scaffold**: deleted `test/attestation_test.go.disabled`, a disabled
  test carrying an unresolved `// adjust import if path differs` comment. It had
  never executed.

#### Security

- **Removed `MOHAWK_ALLOW_UNAUTH_ADMIN` backdoor** from the orchestrator
  (2026-05-24). This was a real authentication bypass, not a hardening nicety.
- **Closed a signature-bypass** in `MigrateWithDualSignatureCryptographic`
  (2026-07-27).
- **Removed a hardcoded default Grafana API token** from the ops-assistant
  `GrafanaClient` (2026-09-29 → 2026-10-01); the constructor now falls back to an
  empty string and requires an explicitly supplied token. Unit tests added.
- **Bounded Grafana 401 retry handling** in the ops-assistant client, and fixed a
  401 retry loop in the ops summary path.
- Dependency CVE remediation: `golang.org/x/crypto` v0.51.0 → v0.52.0 (HIGH CVEs,
  2026-06-25); `socket.io-parser` for CVE-2026-69185 (2026-08-04); npm
  dependencies via the trivy-fs gate (2026-06-16); Go toolchain 1.26.3 → 1.26.4
  for GO-2026-5037 / GO-2026-5039 (2026-06-15), then 1.26.5 → 1.26.6 for six
  disclosed stdlib CVEs (2026-08-15).

#### Formal Verification

The largest body of work in this window. Zero `sorry` remain across
`proofs/LeanFormalization`, `proofs/Specification`, and `proofs/Refinement`; the
eight remaining axioms are documented, CI-allowlisted IEEE-754 non-NaN comparison
facts in `proofs/Refinement/MultiKrum.lean`, not placeholders.

- **Closed the RDP → (ε, δ)-DP conversion gap** (#174, 2026-08-15) via
  `proofs/Refinement/RDPLogBound.lean`, providing a computable two-sided rational
  bound on `Real.log` so the conversion does not require `Real.log` itself to be
  computable. Coarse-but-general rather than Taylor-tight, by design.
- **Wired the real Groth16/BN254 circuit** (#173, 2026-08-15) into `pyapi`'s
  `VerifyZKProof`/`BatchVerifyProofs` and `hybrid`'s `SNARKVerifier`/`VerifyHybrid`.
  Additive: legacy no-commitment callers are unaffected.
- Closed row 12's MultiKrum precondition/general-m gaps; closed
  `RDP_sequential_composition`, the last open `sorry`; closed adaptive RDP
  composition (Track C).
- Replaced vacuous or mislabeled theorems in Theorem 5 and 6 with grounded
  statements; grounded `chernoff_bound` in a real PMF probability.
- Added real Go correspondence models for `MultiKrum`, `RDPAccountant`, `Ledger`,
  and `Transport` in `proofs/Refinement/`.
- Removed unclaimed, vacuous `Specification/Byzantine.lean` and orphaned
  `Theorem2RDP_Enhanced`/`AdvancedRDP` modules.
- Moved two unsound Lean drafts to `proofs/quarantined/` with a README explaining
  why each fails to establish what its name claims.
- Added trace-verification CI for the RDP accountant and hierarchical BFT, a Lean
  structural replay validator, a machine-checked audit log for claim transitions,
  and a hierarchical BFT statistical sanity check (Technique B).
- Added property-based tests for Multi-Krum and the RDP accountant (ROADMAP P3.1).
- Made the required CI gate actually verify Lean proofs; replaced the blanket
  axiom ban with an explicit allowlist.
- Added a real circuit-derived Groth16 verifier (Track B1) and documented the
  Groth16/q-SDH feasibility finding (Track B2).

#### Performance

- Vectorized the SDK Python token-batch generator; corrected unrealistic
  performance thresholds.
- Optimized Go gradient aggregation and Multi-Krum; pre-allocated `PathHops` in
  `RPCClient`; concurrent Prometheus query fetching.

#### Testing & CI

- **Go coverage is now published as a README badge.** `go-test.yml` already
  computed `test-results/go-coverage-summary.txt` on every run and uploaded it as
  an artifact, but the figure was never surfaced. New
  `scripts/generate_coverage_badge.py` converts the summary into a shields.io
  endpoint payload, and `.github/workflows/update-go-coverage-badge.yml`
  publishes it to the `badges` branch after each successful `Go Test` run,
  following the existing `update-release-performance-badge.yml` pattern.
- **New `go-test-race` CI job** (`go-test.yml`): no workflow previously ran
  `go test -race`, so concurrent-access tests in `internal/cluster` (mutex) and
  `internal/federation` (`sync.RWMutex`) were never race-checked. The job pins
  `CGO_ENABLED=1`, preflights `command -v gcc`, and uploads a report artifact.
- **cgo-gated test files no longer vanish silently.** The four
  `internal/pyapi` test files (`api_aggregate_integration_test.go`,
  `api_security_test.go`, `api_zkproof_commitment_test.go`,
  `compress_benchmark_test.go`) all carry `//go:build cgo`. Where no C compiler
  is installed, `CGO_ENABLED` defaults to 0, Go excludes them, and reports
  `[no test files]` instead of failing — the whole Go↔Python bridge test suite
  could disappear with a green build and no error. `go-test.yml` now sets
  `CGO_ENABLED=1` explicitly and asserts that `internal/pyapi` reports passing
  results, failing the build if the tests are skipped. Verified against four
  report shapes, including a real cgo-disabled report.
- **Corrected per-package coverage reporting**: `go-test.yml` now passes
  `-coverpkg=./internal/...`. Most packages under `internal/` have no `_test.go`
  files of their own and are exercised from the separate top-level `test/`
  package, so Go previously attributed 0% to them regardless of actual coverage.
  Real total coverage is 68.6%, not the ~45% the old reporting implied.
- **New tests for `internal/cluster` and `internal/federation`'s per-tier DP
  tracking**, the two least-covered packages. `internal/cluster` went from 0% to
  100% statement coverage; `dp_tier_tracking.go` from 0% to 93–100% across 11 of
  14 functions.
- Added unit test coverage for `EnforceFIPSGate` (`internal/startup/fips_test.go`).
- Encapsulated stress-test options and `TransferWithControls` parameters into
  config/option structs.
- Added a local `kind` scale harness with boundary evidence.
- Fixed a Go version mismatch across `Dockerfile` and `Dockerfile.stress`
  (stale Alpine 3.21 → 3.24).

#### Fixed - Two Correctness Bugs Surfaced by the New Tests

- **`internal/federation` DP budget was ignored** (`dp_tier_tracking.go`).
  `RecordAggregation` compared cumulative epsilon against a hardcoded
  `globalEps > 100.0`, ignoring the `maxGlobalEpsilon` value passed to
  `NewDPTierTracker` entirely and bypassing the accountant's RDP → (ε, δ)
  conversion. A caller configuring a budget of 1000 got a hard failure on the
  first aggregation (ε≈185), and the documented default of 2.0 was effectively
  unenforced. It now calls `globalBudget.CheckBudget()`, which enforces the
  configured budget with the proper conversion.
- **`internal/cluster` slice aliasing** (`topology.go`). `AssignAggregator` stored
  a subslice of the caller's backing array, so mutating that array after the call
  would silently reroute an edge node's gradient paths. `GetAssignedAggregators`
  returned the topology's internal slice directly, letting callers mutate cluster
  routing without holding the lock. Both now copy.

### Fixed - PR Build/Test Split and Archive Navigation

- **Build/test workflow scoping** (`.github/workflows/build-test.yml`):
  - Excluded benchmark-heavy Python SDK test files from the default PR gate so the build job stays focused on correctness checks
  - Left benchmark and performance coverage in the dedicated `performance-gate.yml` workflow

- **Archived documentation index** (`docs/archive/root-cleanup-2026-04/README.md`, `docs/README.md`, `docs/INDEX.md`):
  - Added a dated archive landing page for the April 2026 root cleanup batch
  - Pointed the main docs navigation at the archive index instead of listing every historical file inline

### Added - Supply Chain Security & Verifiable Build Attestations

- **SLSA Build Type 1 Provenance** (`.github/workflows/slsa-provenance-and-signing.yml`):
  - Automated SLSA v1.0 provenance generation on every tagged release
  - Multi-platform binary builds (Linux amd64/arm64, macOS amd64/arm64)
  - Container image provenance with SBOM attestation
  - Build environment transparency (builder identity, git commit, dependencies)
  - Immutable signed attestation statements

- **Cosign/Sigstore Keyless Signing** (`.github/workflows/slsa-provenance-and-signing.yml`):
  - Keyless signing using GitHub Actions OIDC tokens
  - Container image signatures with `cosign verify`
  - Release binary signatures with cryptographic verification
  - Automatic certificate rotation per workflow run
  - No long-lived keys to manage

- **In-Toto Supply Chain Metadata** (`.github/workflows/in-toto-supply-chain.yml`):
  - Complete supply chain recording (material → build → verification)
  - In-toto layout definition with policy enforcement
  - Cryptographically signed link metadata for each supply chain step
  - Full audit trail from source code to release artifact
  - Supports in-toto verification framework compliance

- **Expanded Formal Verification Coverage** (`FORMAL_VERIFICATION_COVERAGE.md`):
  - Extended coverage matrix for Go runtime bounds
  - Python SDK type safety and input validation verification
  - Cryptographic primitive lemmas (in progress)
  - Runtime property verification (WASM limits, memory bounds)
  - Integrated into release attestations and CI gates

- **Release Asset Publishing with Full Attestations** (`.github/workflows/slsa-provenance-and-signing.yml`, `.github/workflows/in-toto-supply-chain.yml`):
  - SHA256/SHA512 checksums signed with cosign
  - SLSA provenance statement attached to release
  - In-toto supply chain metadata bundle
  - Comprehensive release body with verification instructions
  - All artifacts published to GitHub Releases

- **Verification Documentation** (`SUPPLY_CHAIN_SECURITY.md`):
  - Quick-start guides for signature verification
  - Container image verification procedures
  - Binary and checksum verification workflows
  - In-toto metadata inspection instructions
  - Auditor verification checklists

- **CI/CD Enhanced Pre-Release Gate**:
  - All formal proofs must pass before release
  - Static analysis (govulncheck, go vet) must be clean
  - Type verification (mypy strict) must pass
  - All runtime tests must pass
  - Violations block release artifacts publication

## [2.0.2.Alpha] - 2026-04-21

### Added - Flower-Compatible SDK Expansion

- **Flower-compatible client integration** (`sdk/python/mohawk/flower_client.py`, `sdk/python/mohawk/flower_strategy.py`):
  - Added a Flower-compatible client adapter that keeps local training logic in Python while Mohawk handles compression, proof-envelope generation, and Go-backed aggregation submission
  - Added a thin Flower strategy forwarder for optional server-side compatibility bridges

- **Flower-integrated example pack** (`sdk/python/examples/flower_integrated/`):
  - Added quickstart-PyTorch, Hugging Face, and LLM fine-tune smoke examples
  - Added shared example helpers plus a compatibility wrapper for the existing Flower smoke script

- **Verification and release updates** (`sdk/python/tests/test_flower_client.py`, `.github/workflows/flower-integration.yml`):
  - Added tests for the Flower adapter and strategy forwarder
  - Added Flower integration CI coverage and example smoke execution

- **Formal traceability update** (`proofs/FORMAL_TRACEABILITY_MATRIX.md`):
  - Linked Flower client compatibility paths back to the Lean theorem set and runtime evidence

- **Runtime verifier hardening** (`cmd/node-agent/main.go`, `cmd/node-agent/Dockerfile`, `docker-compose.yml`):
  - Node-agent proof verifier startup is now fail-closed by default
  - Silent verifier disable path removed
  - Added explicit CI/dev-only fallback gate via `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true`
  - Added default bundled `proof_verifier.wasm` artifact in node-agent image for strict startup parity

- **Constrained-runtime transport mitigation** (`internal/network/transport.go`, `docker-compose.yml`):
  - Added `MOHAWK_DISABLE_QUIC` support to disable QUIC listen addresses at runtime
  - Updated compose deployment profile to default `MOHAWK_DISABLE_QUIC=true` for orchestrator and node agents on environments where UDP socket sysctl tuning is unavailable

- **Map-parity CI/security/validation upgrade pack** (`.github/workflows/codeql-analysis.yml`, `.github/workflows/security-supply-chain.yml`, `.github/workflows/workflow-action-pin-check.yml`, `.github/workflows/full-validation-pr-gate.yml`, `.github/workflows/full-validation-scheduled-deep.yml`, `tests/scripts/python/run_full_validation_suite.py`, `tests/scripts/ci/check_validation_trends.py`, `tests/scripts/ci/write_validation_diff_summary.py`, `scripts/ci/check_workflow_action_pins.py`):
  - Added CodeQL analysis workflow for Go and Python security scanning on push/PR and scheduled runs
  - Added supply-chain workflow with `govulncheck` and dependency-review enforcement for PRs
  - Added workflow action pin policy enforcement to require full-SHA action references
  - Added profile-based full validation runner (`fast`, `deep`) with machine/human artifacts and history tracking
  - Added trend SLO checker and previous-vs-current diff summary generation for validation artifact governance

- **Release asset and image publication workflow** (`.github/workflows/release-assets.yml`):
  - Publishes pre-built tagged Docker images to GHCR using `docker/build-push-action`
  - Attaches OCI image archives, digest metadata, source/image SBOMs, benchmark reports, and `sovereign-map-testnet.tar.gz` to tagged releases
  - Packages npm artifacts when `package.json` files are present and attaches those tarballs to release assets

- **Artifacts Included (Stable Release Bundle)**:
  - Docker images: GHCR tags + downloadable OCI archives (`orchestrator`, `node-agent`, `fl-aggregator`, `api-dashboard`)
  - SBOMs: source SPDX JSON + per-image SPDX JSON
  - Runtime benchmark evidence: bridge compression, FedAvg compare, accelerator backend compare
  - Testnet package: `sovereign-map-testnet.tar.gz` (config + genesis + launch scripts)
  - npm package tarballs when applicable

- **Expanded CI artifact downloads** (`.github/workflows/build-test.yml`, `.github/workflows/fedavg-benchmark-compare.yml`):
  - Uploads `test-results/` outputs (Go JSON test stream, Python JUnit XML, monitoring smoke query output)
  - Uploads downloadable OCI image archives from CI runs for fast evaluator testing
  - Uploads swarm integration and accelerator benchmark artifacts tied to FedAvg benchmark workflow

- **Large-scale swarm integration + Byzantine edge-case suite** (`test/swarm_integration_large_scale_test.go`):
  - Adds 500 and 1000 node integration checks under safe Byzantine envelope
  - Adds edge-case rejection tests for malicious ratios above 55%
  - Adds hardware-agnostic backend profile checks for CPU/CUDA/NPU policy paths

- **CPU vs GPU vs NPU benchmark automation** (`scripts/benchmark_accelerator_backends.py`, `Makefile`):
  - Adds `make benchmark-gpu` target that generates side-by-side backend comparison markdown/json evidence
  - Integrates backend benchmark report generation into FedAvg benchmark CI

- **Pre-packaged dashboard JSONs and accelerator observability view** (`grafana/*.json`, `monitoring/grafana/dashboards/performance/accelerator-backend-compare.json`):
  - Adds quick-import dashboard bundles for node health, Byzantine detection, and tokenomics flow
  - Adds backend comparison dashboard for accelerator throughput/latency/error tracking

- **Alert coverage expansion for performance/resilience thresholds** (`monitoring/prometheus/alerting-rules.yml`):
  - Adds aggregation latency threshold alert (`MohawkAggregationLatencyHigh`)
  - Adds malicious-node-ratio alert (`MohawkMaliciousNodeRatioHigh`)

- **Versioned SLO/SLI baseline and failure-injection latency validator** (`results/go-live/evidence/slo_sli_baseline_2026-03-28.md`, `results/go-live/evidence/slo_sli_baseline_2026-03-28.json`, `scripts/validate_failure_injection_latency.py`, `results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md`, `results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json`):
  - Added formal SLO/SLI contract for readiness, chaos recovery latency thresholds, and proof-latency target
  - Added executable validator that consumes readiness + chaos artifacts and emits pass/fail release evidence

- **v1.0.0 release closure docs** (`RELEASE_CHECKLIST_v1.0.0_RC.md`, `DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`):
  - Added explicit RC sign-off checklist tied to gate evidence and TPM closure requirements
  - Added staged genesis-to-production rollout guide with preflight, validation, and rollback criteria

- **TPM closure-prep matrix and validator artifacts** (`results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.md`, `results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json`, `results/go-live/attestations/tpm_attestation_production_closure.json`, `scripts/validate_tpm_attestation_closure.py`, `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md`, `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json`, `results/go-live/evidence/tpm_attestation_linux_validation_2026-03-28.md`):
  - Added formal cross-platform closure matrix for TPM attestation production readiness
  - Added Linux execution evidence and machine/human closure validation reports
  - Added pending TPM closure attestation state to keep remaining blocker explicit

- **GA tag safety enforcement and TPM closure dashboard** (`.github/workflows/ga-tag-safety.yml`, `scripts/enforce_ga_tag_safety.py`, `scripts/generate_tpm_closure_summary.py`, `results/go-live/evidence/tpm_closure_summary_2026-03-28.md`, `results/go-live/evidence/tpm_closure_summary_2026-03-28.json`, `results/go-live/evidence/templates/windows_tpm_attestation_capture_guide.md`, `results/go-live/evidence/templates/macos_tpm_attestation_capture_guide.md`, `results/go-live/evidence/templates/tpm_platform_evidence_template.json`):
  - Added tag-triggered safety workflow to block final GA tags when TPM closure or strict gate evidence is not passing
  - Added consolidated TPM closure summary artifacts for release dashboarding and audit handoff
  - Added operator-ready Windows/macOS evidence capture packs with standardized schema

- **Monitoring smoke gate CI** (`.github/workflows/monitoring-smoke-gate.yml`):
  - Added compose-based Prometheus/Grafana smoke workflow for push/PR
  - Verifies `up` targets are healthy and theorem dashboard is registered via Grafana API
  - Publishes smoke query artifacts for incident/debug traces

- **Release performance evidence index automation** (`scripts/generate_release_performance_evidence.py`, `.github/workflows/release-performance-evidence.yml`, `results/metrics/release_performance_evidence.md`):
  - Added machine-generated release sign-off index for benchmark artifacts
  - Added CI workflow that regenerates benchmark reports and uploads consolidated evidence

- **Golden-path end-to-end evidence runner** (`scripts/golden_path_e2e.sh`, `results/go-live/golden-path-report.json`, `results/go-live/golden-path-report.md`):
  - Added one-command stack-up, readiness, integration-test, and metrics-assertion execution path
  - Produces machine and human-readable evidence artifacts under `results/go-live/`

- **Strict-host evidence artifact** (`results/go-live/strict-host-evidence.md`):
  - Added strict go-live validation evidence template/output for production-host sign-off
  - Documents expected strict failure behavior on non-tuned development hosts and remediation commands

- **Branch protection automation helper** (`scripts/apply_branch_protection.sh`):
  - Added admin-ready script to enforce required status checks and PR review baseline on `main`
  - Includes required contexts for Integrity Guard, monitoring smoke, readiness/chaos, and release evidence gates

- **Utility coin telemetry and lifecycle reporting**:
  - Added dashboard and recording-rule coverage for utility coin supply, holders, mint, burn, and transfer activity
  - Removed deprecated Ethereum bridge benchmark/reporting surfaces from the release stream

- **PyAPI aggregation integration test coverage** (`internal/pyapi/api_aggregate_integration_test.go`):
  - Added endpoint-style coverage for list and wrapped aggregate payloads
  - Added negative-path validation for malformed JSON and empty update batches
  - Added assertions for Multi-Krum selection behavior (`selected_count`, `multi_krum`)

- **FedAvg runtime benchmark comparison CI** (`.github/workflows/fedavg-benchmark-compare.yml`, `scripts/benchmark_fedavg_compare.sh`, `results/metrics/fedavg_benchmark_compare.md`):
  - Added PR/push benchmark comparison workflow with markdown artifact upload (`fedavg-benchmark-report`)
  - Added base-vs-current benchmark script using temporary git worktree execution
  - Added averaged benchmark row reporting and unmatched-row visibility (`NA`) for non-overlapping benchmark symbols

- **Observability v2 dashboards and recording rules** (`monitoring/prometheus/recording-rules.yml`, `monitoring/prometheus/prometheus.yml`, `docker-compose.yml`, `monitoring/grafana/dashboards/v2-*.json`, `monitoring/grafana/dashboards/README_DASHBOARD_V2.md`):
  - Added Prometheus recording rules for throughput, failure ratio, latency quantiles, and availability counts
  - Wired recording rules into compose-mounted Prometheus configuration
  - Added role-oriented v2 dashboard suite for operations, incidents, engineering drilldowns, and executive reporting
  - Added dashboard guide with metric map and verification checklist for identifiable metric navigation

- **PQC readiness overhaul release closure** (`internal/network/gradient.go`, `internal/tpm/tpm.go`, `internal/token/ledger.go`, `cmd/orchestrator/server.go`, `scripts/mainnet_readiness_gate.py`):
  - Hardened runtime hybrid transport negotiation and KEX metadata enforcement for `x25519-mlkem768-hybrid`
  - Completed XMSS-bound TPM quote metadata binding and attestation mode visibility in readiness checks
  - Added epoch-driven migration cutover with cryptographic dual-signature requirement after cutover
  - Added digest-first migration signing endpoint to support deterministic operator signing workflows
  - Added readiness validation coverage for TPM identity signature mode and migration policy defaults

- **Formal go-live gate framework** (`scripts/validate_go_live_gates.py`, `results/go-live/attestations/*.json`, `Makefile`):
  - Added machine-enforced go-live validator combining readiness, chaos, host network preflight, and attestation approvals
  - Added `make go-live-gate` target for one-command formal validation
  - Added structured attestation templates and generated status report artifact at `results/go-live/go-live-gate-report.json`

- **Host UDP/socket tuning preflight** (`scripts/validate_host_network_tuning.sh`, `scripts/mainnet_one_click.sh`):
  - Added strict kernel preflight gate for `net.core.rmem_*` and `net.core.wmem_*`
  - Wired preflight into one-click pipeline as first-stage hard gate

- **Operations runbook publication** (`OPERATIONS_RUNBOOK.md`):
  - Published incident response, escalation flow, readiness/chaos preflight sequence, and backup/restore drill procedures
  - Added evidence references to readiness/chaos artifacts and ledger backup/restore validation paths

- **GitHub SDK release packaging** (`.github/workflows/publish-python-sdk.yml`, `sdk/python/setup.py`):
  - Added a tag-driven workflow that builds the Python SDK source distribution and publishes it as a GitHub Release asset on `sdk-v*` tags
  - Enforces SDK tag/version alignment before publishing to avoid mismatched release artifacts
  - Packaging metadata now uses `mohawk.__version__` as the single SDK version source and prefers packaged shared-library lookup before repository-root fallback

- **Real BN254 Groth16 zk-SNARK verifier** (`internal/zksnark_verifier.go`):
  - Replaced simulation with full four-pairing Miller-loop check using `gnark-crypto v0.20.0`
  - Genesis VK uses canonical BN254 generator points (α=G1, β=G2, γ=G2, δ=G2, IC₀=G1)
  - Wire format: 128 bytes compressed — A[32] | B[64] | C[32] — matches existing buffer contract
  - `GenesisProofBytes()` helper produces a deterministic valid proof (A=G1gen, B=G2gen, C=−G1gen)
  - Infinity-point guard and O(1) 15 ms latency enforcement retained from Theorem 5
- **Real SHA256 Merkle-commitment STARK verifiers** (`internal/hybrid/verifier.go`):
  - `friVerifier` (backend: `simulated_fri`): verifies `proof[0:32] == SHA256(proof[32:])` — binding root to transcript
  - `winterfellVerifier` (backend: `winterfell_mock`): uses domain-separated commitment `SHA256("winterfell-v1:"+transcript)` to prevent cross-protocol replay
  - `GenFRIProof(content)` and `GenWinterfellProof(transcript)` constructor helpers for testing and SDK usage
- **Structured error codes in the Go↔Python bridge** (`internal/pyapi/api.go`):
  - `Result.ErrorCode` field: machine-readable code (`PROOF_TOO_SHORT`, `PROOF_POINT_INVALID`, `PROOF_DEGENERATE`, `PROOF_PAIRING_FAILED`, `PROOF_LATENCY_EXCEEDED`, `PROOF_INVALID`)
  - `classifyProofError()` maps Go error strings to codes; `marshalResultEC()` emits them in JSON
- **Base64/hex proof decoding in the bridge** (`internal/pyapi/api.go`):
  - `decodeProofString()` transparently handles 0x-hex, standard base64, URL-safe base64, and raw string bytes
  - Removed legacy zero-padding in `VerifyZKProof` and `BatchVerifyProofs` — invalid-size proofs now return `PROOF_TOO_SHORT`
- **Structured Python SDK exception hierarchy** (`sdk/python/mohawk/exceptions.py`, `__init__.py`):
  - `ProofTooShortError`, `ProofStructureError`, `ProofPairingError`, `ProofDegenerateError` as `VerificationError` subclasses
  - `verification_error_for_code(code, message)` mapper used by `MohawkNode.verify_proof()` to raise the most specific type
- **gnark-crypto** `v0.20.0` added as a direct dependency
- **Grafana tokenomics dashboard** (`monitoring/grafana/dashboards/finance/tokenomics.json`):
  - Supply, holder count, tx count, burn/mint rates
  - Bridge settlement volume/success tracking
  - Proof verification throughput and p50/p95/p99 latency views
- **WASM module registry + hot reload** (`internal/wasmhost/host.go`, `internal/pyapi/api.go`):
  - Content-hash keyed module registry (`Upsert`, `Get`, `Default`, `HotReload`, `Close`)
  - Runtime status includes active `wasm_module_hash`
  - `LoadWasmModule` supports path and inline `wasm_b64` payloads
- **Async hot-reload examples** (`sdk/python/examples/wasm_hot_reload_demo.py`, `sdk/python/examples/wasm_hot_reload_async_demo.py`)
- **Mainnet readiness gate** (`.github/workflows/mainnet-readiness-gate.yml`, `scripts/mainnet_readiness_gate.py`):
  - Boots core monitoring stack in CI and verifies Grafana/Prometheus readiness
  - Enforces orchestrator (`orchestrator:9091`) and TPM (`tpm-metrics:9102`) scrape target health
  - Validates tokenomics metric presence and supply invariant (`total_supply ~= minted - burned`)
  - Publishes structured readiness report artifact (`mainnet-readiness-report`)
- **Mainnet chaos gate** (`.github/workflows/mainnet-chaos-gate.yml`, `scripts/chaos_readiness_drill.sh`):
  - Runs outage/recovery drills for `tpm-metrics`, `orchestrator`, `prometheus`, and `grafana` in CI matrix jobs
  - Requires baseline readiness pass, expected failure during outage, and full readiness recovery post-restart
  - Enforces recovery-latency threshold and publishes per-scenario baseline/failure/recovery/summary reports
- **Weekly readiness digest** (`.github/workflows/weekly-readiness-digest.yml`, `scripts/generate_readiness_digest.py`):
  - Runs readiness + all chaos drills on a weekly schedule and on-demand
  - Produces a consolidated markdown digest and publishes it to job summary + artifacts
  - Supports optional Slack/Teams webhook notifications via `SLACK_WEBHOOK_URL` and `TEAMS_WEBHOOK_URL` repository secrets

### Changed

- **Commit Notes / Contribution Attribution:**
  - Security patch contribution credited to `@Eddie-Adams` (Apr 2026): fail-closed verifier startup hardening and constrained-runtime transport mitigation (`MOHAWK_DISABLE_QUIC` profile)
  - Contributor award updated: `+500` points (total `1000`)

- **Documentation alignment for security hardening** (`README.md`, `ROADMAP.md`, `SECURITY.md`, `DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`):
  - Updated operator guidance to reflect fail-closed verifier boot behavior
  - Added explicit CI/dev-only insecure fallback language
  - Updated deployment/runtime notes for QUIC-disabled constrained-host profile and QUIC re-enable path on tuned hosts

- **Roadmap/dashboard/readme Phase 3 status alignment** (`ROADMAP.md`, `DASHBOARD.md`, `README.md`, `results/go-live/README.md`, `Makefile`):
  - Marked SLO/SLI definition, failure-injection latency validation, RC checklist publication, and deployment-guide publication as complete
  - Updated critical-path messaging to focus remaining work on TPM attestation completion and GA tag cut
  - Added `make failure-injection-latency-check` for repeatable evidence generation
  - Added `make tpm-attestation-closure-check` for repeatable TPM closure-state validation

- **Formal go-live validator strict/advisory mode semantics** (`scripts/validate_go_live_gates.py`, `Makefile`, `README.md`, `results/go-live/README.md`):
  - Added explicit `--host-preflight-mode` (`strict` or `advisory`) with audited report metadata
  - Reports now include mode, warnings list, and host-tuning enforcement status
  - Added mode-specific make targets (`go-live-gate-strict`, `go-live-gate-advisory`)

- **Alert remediation linkage** (`monitoring/prometheus/alerting-rules.yml`, `OPERATIONS_RUNBOOK.md`):
  - Added `runbook_url` annotations for each resilience/liveness/attestation alert
  - Added explicit runbook playbooks for all alert names to reduce on-call triage latency

- **Prometheus to Alertmanager routing** (`monitoring/prometheus/prometheus.yml`, `monitoring/alertmanager/alertmanager.yml`, `docker-compose.yml`):
  - Added Alertmanager service and Prometheus alertmanager target wiring
  - Added severity-based routing for `critical` and `warning` alerts

- **FedAvg aggregation worker strategy and benchmark surface** (`internal/accelerator/aggregate.go`, `test/accelerator_test.go`, `README.md`, `PERFORMANCE.md`):
  - Added adaptive worker resolver (`ResolveAggregateWorkers`) with small-workload single-thread fallback and large-workload parallel selection
  - Expanded runtime benchmark matrix to include 4 workload shapes and 5 worker configurations
  - Added worker-resolution unit coverage and reproducible benchmark commands in project documentation

- **One-click host preflight policy tightened** (`scripts/mainnet_one_click.sh`, `README.md`, `OPERATIONS_RUNBOOK.md`):
  - Switched `MOHAWK_HOST_PREFLIGHT_MODE` default from advisory to strict for production-safe execution
  - Documented dev-container advisory override path and production sysctl persistence checklist
  - Added structured one-click report references for release evidence trails

- **SDK version baseline** (`sdk/python/mohawk/__init__.py`, `README.md`, `sdk/python/README.md`):
  - Bumped Python SDK release identifier and badge references to `2.0.1.Alpha`

- **Weekly digest workflow advisory trail** (`.github/workflows/weekly-readiness-digest.yml`):
  - Added advisory host-preflight marker handling and digest summary annotation path
- **Readiness/operations documentation alignment** (`README.md`, `ROADMAP.md`, `DASHBOARD.md`):
  - Updated program-stage language to reflect go-live formalization complete
  - Added formal artifact trails for go-live report and attestations
  - Marked completed operations/runbook/escalation roadmap items as complete
  - Synced formal gate status to `8/8` approved attestations with all required go-live evidences validated

- Documentation alignment: synchronized current phase and program-stage wording across `ROADMAP.md`, `README.md`, and `DASHBOARD.md` to reflect v1.0.0 GA closure under mainnet-readiness gated operations

- `TestVerifyProof_Valid` now uses `internal.GenesisProofBytes()` (real BN254 proof) instead of `make([]byte, 128)`
- `TestVerifyProof_TooSmall` behaviour unchanged; added `TestVerifyProof_InvalidPoint` and `TestVerifyProof_WrongProof`
- `TestHybridVerifyModes` updated to construct proofs via `hybrid.GenFRIProof` / `hybrid.GenWinterfellProof`
- Python bridge now deallocates Go-returned strings through exported `FreeString` (leak-safe ctypes boundary)
- Python SDK client lifecycle now supports `close()`, `with MohawkNode(...)`, and `async with AsyncMohawkNode(...)`
- Build workflow now installs SDK (`pip install -e ./sdk/python[dev]`) and runs Python tests directly in CI

- Python SDK roadmap integration milestones
- CI/CD pipeline for automated Python SDK builds
- Strict auth/role smoke runner at `scripts/strict_auth_smoke.py` for deterministic token/role validation (positive and negative paths)
- New Make targets: `strict-auth-smoke-host`, `strict-auth-smoke-container`, and `production-readiness`
- SDK docs for strict-auth smoke usage and Alpine/musl ctypes troubleshooting with glibc-container fallback
- README and SDK README refresh covering badges, genesis testnet usage, observability endpoints, and Python SDK v2 feature surface
- Utility coin lifecycle in `internal/token/ledger.go`, including mint, transfer, burn, deterministic replay protection, and persistent audit chaining
- Asset registry enforcement via the new `internal/token/registry.go`
- Utility coin ledger hardening in `internal/token/ledger.go` with integer base-unit accounting, `burn` transactions, and state migration support from legacy float-backed snapshots
- Utility coin controls in Python SDK and runtime API wiring in `internal/pyapi/api.go`
- Environment-driven utility ledger configuration for single-asset and per-asset deployments
- Compose rollout templates and operator guidance in `docker-compose.yml` for utility-ledger defaults and optional persistent audit mode
- Expanded automated coverage for utility coin authorization, env parsing/config loading, and ledger migration behavior (`internal/pyapi/api_security_test.go`, `test/utility_coin_durability_test.go`)
- Restored tokenomics dashboard ingestion by exposing orchestrator metrics on internal plaintext listener (`:9091`) while preserving mTLS on the control-plane API (`:8080`)
- Updated Prometheus orchestrator scrape target to `http://orchestrator:9091/metrics` for reliable in-network collection
- Added CI monitoring smoke check in `.github/workflows/build-test.yml` to assert `mohawk_utility_coin_total_supply` is queryable after stack startup
- Aligned containerized Go build/runtime toolchains to 1.25 (`Dockerfile`, `cmd/orchestrator/Dockerfile`, `cmd/node-agent/Dockerfile`, `cmd/api-dashboard/Dockerfile`, `cmd/fl-aggregator/Dockerfile`, `docker-compose.yml`)

### Benchmarks

- Published the latest SDK benchmark snapshot in project docs:
  - `test_verify_proof_performance`: 10.55 ms mean, 94.77 ops/s
  - `test_aggregate_nodes_performance`: 30.63 us mean, 32,648 ops/s
  - `test_gradient_compression_performance`: 995.70 us mean, 1,004 ops/s

- Added Go runtime FedAvg benchmark matrix and comparison reporting:
  - Benchmark symbol: `BenchmarkAggregateParallel`
  - Workloads: `clients32_dim2048`, `clients128_dim4096`, `clients256_dim8192`, `clients512_dim8192`
  - Worker profiles: `workers1`, `workers2`, `workers4`, `workers8`, `workersAuto`
  - Comparison report artifact: `results/metrics/fedavg_benchmark_compare.md`

- Added live 10-minute stress metrics capture artifacts from running stack scope:
  - JSON report: `results/metrics/stress_metrics_capture_10m.json`
  - Markdown summary: `results/metrics/stress_metrics_capture_10m.md`
  - Observed zero gradient submit failures during the capture window (`accel_gradient_submit_failure_total` delta = `0`)

## [0.1.0] - 2026-02-20

### Added - Python SDK Foundation

#### Core Components

- **Go C-Shared Library** (`internal/pyapi/api.go`)
  - Exported functions: `InitializeNode`, `VerifyZKProof`, `AggregateUpdates`, `GetNodeStatus`, `LoadWasmModule`, `AttestNode`
  - JSON-based communication protocol between Go and Python
  - Memory-safe string handling with `FreeString` function
  - Cross-platform support (Linux `.so`, macOS `.dylib`, Windows `.dll`)

- **Python Client Package** (`sdk/python/mohawk/`)
  - `MohawkNode` class with ctypes bindings to Go runtime
  - Pythonic API with type hints and comprehensive docstrings
  - Custom exception hierarchy: `MohawkError`, `InitializationError`, `VerificationError`, `AggregationError`, `AttestationError`
  - Automatic library path detection and loading

- **Build Automation**
  - `setup.py` with custom `BuildGoLibrary` command
  - Automatic Go library compilation during `pip install`
  - Platform detection and appropriate library extension selection
  - `pyproject.toml` for modern Python packaging standards

- **Example Scripts**
  - `examples/basic_usage.py`: Demonstrates all SDK features
  - `examples/federated_learning_demo.py`: Complete FL workflow simulation
  - Interactive demos with progress indicators and statistics

- **Testing Infrastructure**
  - `tests/test_client.py`: Pytest unit tests for all methods
  - Fixtures for node initialization
  - Exception handling test coverage

- **Makefile Extensions**
  - `build-python-lib`: Build Go C-shared library
  - `install-python-sdk`: Install Python package with dependencies
  - `test-python-sdk`: Run pytest suite
  - `demo-python-sdk`: Execute example demonstrations
  - `python-all`: Complete build/install/test workflow

- **Documentation**
  - Complete Python SDK README with API reference
  - Architecture diagrams showing Go↔Python bridge
  - Installation instructions and quick start guide
  - Performance benchmarks and usage examples

### Technical Specifications

#### Performance

- Node initialization: ~50ms
- zk-SNARK verification: 10ms (maintained from Go runtime)
- Aggregation complexity: O(d log n)
- Memory overhead: Minimal (ctypes zero-copy where possible)

#### API Coverage

| Function | Go Implementation | Python Binding | Status |
| --- | --- | --- | --- |
| InitializeNode | ✅ | ✅ | Stubbed |
| VerifyZKProof | ✅ | ✅ | Stubbed |
| AggregateUpdates | ✅ | ✅ | Stubbed |
| GetNodeStatus | ✅ | ✅ | Stubbed |
| LoadWasmModule | ✅ | ✅ | Stubbed |
| AttestNode | ✅ | ✅ | Stubbed |

*Note: "Stubbed" means the binding is complete but calls mock implementations. Next phase will connect to actual Go runtime logic.*

### Changed (0.1.0)

- Updated `README.md` with Python SDK section and examples
- Extended `Makefile` with Python-specific targets
- Added Python SDK badge to repository shields

### Developer Notes

#### Bridge Architecture

```text
Python (mohawk.client) → ctypes → libmohawk.so → CGO → Go Runtime (internal/)
```

#### Memory Management

- Go allocates strings with `C.CString()`
- Python receives via `ctypes.c_char_p`
- Python calls `FreeString()` to deallocate Go memory
- JSON is used for complex data structures

#### Next Steps for Full Integration

1. Replace TODO comments in `internal/pyapi/api.go` with actual module calls
1. Connect `VerifyZKProof` to `internal/zksnark_verifier.go`
1. Link `AggregateUpdates` to `internal/aggregator.go`
1. Integrate `LoadWasmModule` with `internal/wasmhost`
1. Connect `AttestNode` to `internal/tpm` attestation

## [0.0.1] - 2026-01-15

### Added - Initial Release

#### Core Protocol

- Hierarchical federated learning architecture (10M:1k:100:1)
- O(d log n) communication complexity
- 55.5% Byzantine fault tolerance (Theorem 1)
- 99.99% straggler resilience (Theorem 4)
- 10ms zk-SNARK proof verification (Theorem 5)
- 28 MB metadata for 10M nodes (700,000x compression)

#### Implementation

- Go 1.25.9 runtime with Wasmtime integration
- TPM attestation stub
- Batch verification system
- RDP (Rényi Differential Privacy) accountant
- Convergence guarantees with formal proofs
- WebAssembly module hosting

#### Documentation

- White Paper with complete protocol specification
- Academic Paper with formal proofs (Theorems 1-5)
- Proof-driven design verification system
- Security audit scripts

#### Testing

- Comprehensive test suite (`test_all.sh`)
- GitHub Actions CI/CD
- Proof verification automation
- Build and test workflows

---

## Version Numbering

- **Major (X.0.0)**: Breaking changes to protocol or API
- **Minor (0.X.0)**: New features, backwards compatible
- **Patch (0.0.X)**: Bug fixes, no new features

---

## Links

- [Repository](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
- [Releases](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases)
- [Issues](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
