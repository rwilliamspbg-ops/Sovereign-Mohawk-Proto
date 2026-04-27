# Sovereign Mohawk Upgrade Implementation Plan (2026-2027)

## Branch
- Working branch: feat/upgrade-roadmap-poc-dadp-fhe-pqc-scheduling
- Baseline branch: feat/planning-doc-and-validation-scripts

## Mission
Evolve Sovereign-Mohawk-Proto from advanced prototype to production-grade, trust-minimized federated learning protocol by delivering five strategic upgrades:
1. Zero-Knowledge Proof of Compute (PoC)
2. Dynamic Adaptive Differential Privacy (DADP)
3. Threshold FHE Aggregation
4. Lean 4 Formal Verification for PQC Migration Continuity
5. Incentivized Resource-Aware Scheduling

## Existing Anchors (Current Repository)
- ZK verification path: internal/zksnark_verifier.go, internal/batch_verifier.go
- RDP accounting: internal/rdp_accountant.go, internal/dp_config.go, proofs/LeanFormalization/Theorem2RDP.lean
- PQC migration logic: internal/token/ledger.go, internal/token/migration_signatures.go
- Utility coin controls: internal/token/ledger.go, internal/token/registry.go, internal/pyapi/api.go
- Scheduling/router controls: internal/router/policy.go, internal/router/router.go

## Incorporated Inputs From Existing Strategy Material
- Formal proof maturity gaps from STRATEGIC_PLAN_FORMAL_PROOFS.md are now explicit delivery items:
  - Increase proof depth beyond arithmetic tactics (probability, induction, hierarchy semantics).
  - Expand Mathlib usage for probabilistic and cryptographic reasoning.
  - Add formalized hierarchical structures and theorem-driven invariants.
- CI recommendations are carried into release gates using existing workflows:
  - .github/workflows/verify-proofs.yml
  - .github/workflows/verify-formal-proofs.yml
- Dependency and license posture from DEPENDENCIES.md is promoted to a tracked upgrade gate with explicit library adoption criteria.

## Program Timeline
- Phase 0 (Week 1-2): Design freeze, threat model, metrics baselining
- Phase 1 (Week 3-8): PoC + DADP MVPs behind feature flags
- Phase 2 (Week 9-14): TFHE aggregation pilot + auction scheduler MVP
- Phase 3 (Week 15-18): Lean formal continuity proofs + adversarial testing
- Phase 4 (Week 19-22): Hardening, benchmarks, docs, go/no-go release gate

## Dependency and Toolchain Plan

### Current Baseline (Verified in go.mod)
- Go runtime: 1.25.9
- Core cryptography backend: github.com/consensys/gnark-crypto v0.20.1
- WASM runtime for execution path: github.com/tetratelabs/wazero v1.11.0
- Network and telemetry core remain unchanged during Phase 0-1 unless benchmark results force upgrades.

### Planned Upgrade Dependencies (By Workstream)
- Workstream 1 PoC:
  - Keep gnark-crypto as baseline verifier path.
  - Add proof-system adapter interface first; introduce any new proving backend only behind feature flags after benchmark sign-off.
- Workstream 2 DADP:
  - No mandatory new external dependency for MVP; extend internal/rdp_accountant.go first.
  - Optional analytics dependency only if simulation throughput requires it.
- Workstream 3 Threshold FHE:
  - Introduce TFHE/threshold-capable library only in pilot phase with capability negotiation and fallback path.
  - Enforce security review, license review, and reproducible benchmark gates before making it default.
- Workstream 4 Lean migration continuity:
  - Keep lean-toolchain pinned and continue Mathlib cache strategy already used in CI.
  - Add theorem files without broad toolchain churn during the migration-proof window.
- Workstream 5 Auction scheduler:
  - Prefer internal implementations for allocator logic first.
  - Add optimization libraries only if deterministic scheduling and auditability remain intact.

### Dependency Approval Gate
- Any new dependency must pass all checks:
  - Security posture (known CVEs and update cadence)
  - License compatibility with Apache-2.0 distribution goals
  - Deterministic/reproducible behavior for formal and regulatory audits
  - Performance budget impact within phase thresholds

## Workstream 1: Zero-Knowledge Proof of Compute (PoC)

### Objective
Prove each participant executed assigned local training steps, not merely submitted plausible gradients.

### Architecture Additions
- Add deterministic training trace schema (round_id, task_hash, step_count, dataset_commitment, model_commitment_before_after).
- Add Wasmtime execution trace hooks to emit bounded trace commitments.
- Add proof generation service (initially STARK-friendly trace commitment, optionally SNARK wrap for succinct verification).
- Extend existing verifier interfaces so PoC proof validation is checked before gradient acceptance.

### Concrete Repo Changes
- New: internal/computeproof/types.go (trace format, commitments, domain separators)
- New: internal/computeproof/collector.go (Wasmtime hook ingestion and transcript building)
- New: internal/computeproof/prover.go (proof generation adapters)
- New: internal/computeproof/verifier.go (verification API integrated with round pipeline)
- Update: internal/batch_verifier.go (batch verify gradient proof + compute proof)
- Update: internal/router/router.go (reject updates missing valid compute proof)

### Acceptance Criteria
- Invalid or replayed compute traces are rejected in < 20 ms verification overhead per update.
- Round-level audit log includes proof IDs and challenge seeds.
- Lazy-participant simulation shows >= 99% detection in adversarial test harness.

## Workstream 2: Dynamic Adaptive Differential Privacy (DADP)

### Objective
Replace fixed epsilon allocation with adaptive, sensitivity-aware privacy budgets while preserving global guarantees.

### Architecture Additions
- Privacy Orchestrator computes per-shard epsilon based on sensitivity class and observed drift.
- Budget ledger extends RDP accountant with per-tier, per-shard budget subaccounts.
- Policy engine enforces lower/upper epsilon bands and emergency floor controls.

### Concrete Repo Changes
- New: internal/privacy/orchestrator.go (adaptive allocation strategy)
- New: internal/privacy/sensitivity_classifier.go (healthcare/finance/public profiles)
- Update: internal/rdp_accountant.go (hierarchical sub-ledgers + global invariant checks)
- Update: internal/dp_config.go (band constraints, adaptive mode flags)
- New tests: internal/privacy/orchestrator_test.go with 10M-node synthetic profiles

### Acceptance Criteria
- Global epsilon guard remains mathematically bounded (never exceeds configured cap).
- Convergence speed improves >= 12% over fixed epsilon baseline on benchmark datasets.
- Privacy violations trigger deterministic circuit breaker and round rollback.

## Workstream 3: Threshold FHE Aggregation

### Objective
Prevent orchestrator plaintext visibility of model updates by aggregating encrypted updates only.

### Architecture Additions
- Add threshold FHE key ceremony and key-share custody workflow.
- Encrypt local updates client-side; aggregate ciphertexts server-side.
- Decrypt only threshold aggregate with quorum key shares, never individual updates.

### Concrete Repo Changes
- New: internal/fhe/keys.go (threshold key lifecycle)
- New: internal/fhe/aggregate.go (ciphertext aggregation operations)
- New: internal/fhe/serialization.go (wire-safe ciphertext bundles)
- Update: internal/network/transport.go (capability negotiation for fhe_threshold_v1)
- Update: internal/router/router.go (aggregation path switch based on negotiated capabilities)
- New docs: docs/fhe-threat-model.md (trust assumptions, side-channel boundaries)

### Acceptance Criteria
- No plaintext individual updates are observable by orchestrator in integration tests.
- Aggregate decryption succeeds with quorum and fails safely below threshold.
- Throughput penalty stays <= 1.8x compared with plaintext secure aggregation baseline.

## Workstream 4: Lean 4 Proofs for PQC Migration Continuity

### Objective
Formally prove a compromised legacy key cannot hijack migration during epoch cutover.

### Architecture Additions
- Formal state machine for migration epochs (pre-epoch, transition, post-epoch).
- Dual-signature continuity theorem and non-hijack theorem.
- Runtime assertions mapped directly to theorem preconditions.
- Mathematical strengthening from strategy backlog:
  - Integrate targeted Mathlib modules for probability/analysis where required.
  - Avoid placeholder-driven proofs in final branch (zero sorry/axiom tolerance).

### Concrete Repo Changes
- New: proofs/LeanFormalization/Theorem7PQCMigrationContinuity.lean
- New: proofs/LeanFormalization/Theorem8DualSignatureNonHijack.lean
- Update: internal/token/ledger.go (explicit invariant checks and epoch transition guards)
- Update: internal/token/migration_signatures.go (canonical signed payload versioning and anti-replay domains)
- New: proofs/test-results/pqc_migration_formal_report.txt

### Acceptance Criteria
- Lean build passes with zero placeholders for new migration theorems.
- Runtime migration checks are traceable to theorem assumptions in a mapping table.
- Red-team scenario (legacy key compromise at cutover) is blocked in deterministic tests.

## Workstream 5: Incentivized Resource-Aware Scheduling

### Objective
Create a compute marketplace where nodes bid utility coin rates for WASM workloads based on available capacity.

### Architecture Additions
- Auction allocator ranks bids by price-performance and trust score.
- Resource profiles include GPU/NPU/CPU/memory telemetry with attested freshness.
- Settlement pipeline mints/transfers utility coins by completed and proven task units.

### Concrete Repo Changes
- New: internal/scheduler/auction.go (sealed-bid and clearing strategy)
- New: internal/scheduler/resource_profile.go (normalized capability vector)
- Update: internal/router/policy.go (resource constraints + placement policy checks)
- Update: internal/token/ledger.go (task-linked settlement primitives)
- Update: internal/pyapi/api.go (bid submission and market status endpoints)

### Acceptance Criteria
- Scheduler places >= 95% tasks within target latency SLO in stress tests.
- Settlement is reproducible and auditable from task receipt to payout.
- Market simulation shows reduced straggler impact and positive node participation economics.

## Cross-Cutting Security and Verification Gates
- Threat modeling: update STRIDE + cryptographic misuse cases per workstream.
- Fuzzing: add protocol fuzzers for proof bundles, ciphertext envelopes, and migration payload parsing.
- Reproducibility: deterministic test vectors for PoC, DADP, FHE, and migration signatures.
- CI gates:
  - Unit + integration + stress test suites
  - Lean theorem checks for migration continuity (verify-proofs.yml and verify-formal-proofs.yml)
  - Performance budget checks (latency and overhead thresholds)
  - Placeholder regression gates (no sorry/axiom/admit in target formal modules)

## Delivery Milestones and Exit Criteria
1. M1 (End Week 8): PoC + DADP MVP merged behind flags with passing integration tests.
2. M2 (End Week 14): Threshold FHE pilot and auction scheduler MVP functional in sandbox.
3. M3 (End Week 18): Lean continuity proofs complete; migration exploit scenarios blocked.
4. M4 (End Week 22): Hardening complete; release candidate tagged for external validation.

## Risks and Mitigations
- Cryptographic complexity risk: stage FHE rollout in pilot mode and enforce capability fallback.
- Performance regression risk: profile-guided optimization and strict overhead budgets per stage.
- Proof/implementation drift risk: maintain theorem-to-runtime traceability matrix as a release blocker.
- Economic manipulation risk: anti-sybil scoring, stake-weighted reputation, and payout rate-limits.

## Immediate Next 10 Actions
1. Finalize ADRs for PoC trace format, adaptive epsilon policy, and threshold FHE selection.
2. Add feature flags: poc_enabled, dadp_enabled, fhe_enabled, auction_scheduler_enabled.
3. Implement PoC transcript type definitions and deterministic hashing.
4. Extend RDP accountant with per-shard sub-ledger accounting.
5. Draft FHE key ceremony and custody runbook.
6. Encode migration state machine in Lean and draft theorem statements.
7. Add migration payload versioning and anti-replay domain separation tags.
8. Build auction simulator with synthetic 10M-node capacity/bid distributions.
9. Add CI jobs for formal migration proofs and performance budgets.
10. Produce external readiness package (threat model, benchmark report, formal proof report).
