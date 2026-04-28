<!-- markdownlint-disable MD022 MD031 MD032 MD036 MD040 MD056 MD058 MD060 -->

# Action Items Tracker
## Sovereign-Mohawk Next Improvements

**Generated:** 2026-04-19  
**Review Cadence:** Weekly (Friday EOD)

---

## QUICK WINS (Start This Week)

### [START NOW] QW1: Proof Strategy Docstrings
- **Owner:** Lean expert
- **Status:** NOT STARTED
- **Effort:** 1 day
- **Description:** Add high-level strategy docstrings to each theorem Lean file
- **Files to Update:**
  - `proofs/LeanFormalization/Theorem1BFT.lean`
  - `proofs/LeanFormalization/Theorem2RDP.lean`
  - `proofs/LeanFormalization/Theorem3Communication.lean`
  - `proofs/LeanFormalization/Theorem4Liveness.lean`
  - `proofs/LeanFormalization/Theorem5Cryptography.lean`
  - `proofs/LeanFormalization/Theorem6Convergence.lean`
- **PR Template:** Add comment block with "Strategy:", "Tactics used:", "Future work:" sections
- **Done Criteria:** All 6 files have docstrings, PR approved

---

### [START NOW] QW2: Runtime Health Metrics
- **Owner:** Backend engineer
- **Status:** NOT STARTED
- **Effort:** 1 day
- **Description:** Add Prometheus exports for formal claim validation
- **Metrics to Add:**
  - `mohawk_bft_resilience_estimate` (gauge)
  - `mohawk_rdp_composition_current` (gauge)
  - `mohawk_communication_cost_observed` (histogram)
  - `mohawk_liveness_success_prob` (gauge)
  - `mohawk_proof_verification_p99` (histogram)
- **Files to Modify:**
  - `internal/aggregator.go` (add resilience calculation)
  - `internal/rdp_accountant.go` (expose composition)
  - `cmd/orchestrator/main.go` (register metrics)
- **Testing:** Curl `http://localhost:9090/metrics | grep mohawk_*` after `docker compose up`
- **Done Criteria:** All 5 metrics exported, visible in Prometheus

---

### [START NOW] QW3: Contributing to Lean Proofs Playbook
- **Owner:** Documentation
- **Status:** NOT STARTED
- **Effort:** 1 day
- **Description:** Write step-by-step guide for contributors to add a theorem
- **Output File:** `docs/CONTRIBUTING_LEAN_PROOFS.md`
- **Sections:**
  1. Theorem statement → Lean signature (template)
  2. Common tactic patterns (omega, linarith, norm_num)
  3. Local testing workflow (`lake build`)
  4. Integration with traceability matrix
  5. Runtime test setup
  6. Full example: Add a simple convergence lemma
- **Review:** Pair with external contributor for feedback
- **Done Criteria:** Document published, tested on 1 external contributor

---

## PRIORITY 1: Phase 3b Formalization (8-10 Days)

### [MILESTONE] P1.1: Chernoff Bounds Formalization
- **Owner:** Lean expert (high complexity)
- **Status:** NOT STARTED
- **Timeline:** Start week 1, complete week 2
- **Description:** Extend Theorem 4 with probabilistic Chernoff bounds
- **Deliverables:**
  - [ ] Define `chernoff_bound : ℚ → ℚ → ℚ` (lambda, k, result)
  - [ ] Prove `chernoff_monotone`: tighter as k increases
  - [ ] Instance: `k=12, α=0.9 → P[failure] < 10^-12`
  - [ ] Integration: `lake build` passes + no placeholders
- **File:** `proofs/LeanFormalization/Theorem4ChernoffBounds.lean` (new)
- **Tests:** `test/straggler_test.go::TestChernoffBound_*` (new)
- **Matrix Update:** Add theorem to `proofs/FORMAL_TRACEABILITY_MATRIX.md`
- **Done Criteria:**
  - [ ] Proof compiles with `lake build`
  - [ ] 2+ test functions exercise bounds
  - [ ] Matrix updated with new theorem-test mapping
  - [ ] CI passes with new proof integrated

---

### [MILESTONE] P1.2: Real-Valued Convergence (Phase 3b Stretch)
- **Owner:** Lean expert
- **Status:** NOT STARTED
- **Timeline:** Start week 3 (after P1.1 complete)
- **Effort:** 5-7 days (can parallelize with others)
- **Description:** Extend Theorem 6 with ℝ-valued convergence rate
- **Deliverables:**
  - [ ] Define envelope over ℝ (not ℕ)
  - [ ] Prove O(1/√KT) + O(ζ²) rate
  - [ ] Validate with concrete SSGD parameters
  - [ ] Integration: `lake build` passes
- **File:** `proofs/LeanFormalization/Theorem6ConvergenceReals.lean` (or extend existing)
- **Dependencies:** Mathlib.Analysis.SpecialFunctions.Sqrt (verify availability)
- **Stretch Goal:** Integrate with Mathlib.Probability (defer to Phase 3c)
- **Done Criteria:** Proof compiles, passes CI, matrix updated

---

### [CHECKPOINT] P1.3: Update Matrix + Test Coverage
- **Owner:** QA + Lean expert
- **Status:** BLOCKED on P1.1, P1.2
- **Timeline:** Week 2 (after P1.1) + Week 4 (after P1.2)
- **Description:** Integrate new theorems into traceability matrix
- **Changes:**
  - [ ] Add rows to `proofs/FORMAL_TRACEABILITY_MATRIX.md` for new theorems
  - [ ] Create test functions for each new theorem
  - [ ] Validate regex extraction still works
  - [ ] Run `proofs/validate_formalization.py` to confirm
- **Matrix Template:**
  ```
  | # | Claim | Source | Module | Theorems | Tests | Status | Notes |
  | 7 | Chernoff tail bounds for 12-redundancy | internal/straggler_resilience.md | LeanFormalization/Theorem4ChernoffBounds.lean | chernoff_bound, chernoff_monotone | test/straggler_test.go::TestChernoffBound_* | Verified | Probabilistic phase 3b |
  ```
- **Done Criteria:** Matrix valid + validate script passes + CI integration OK

---

## PRIORITY 2: Proof CI/CD Hardening (5-7 Days)

### [MILESTONE] P2.1: Lean Proof Metrics Extraction
- **Owner:** DevOps
- **Status:** COMPLETE
- **Timeline:** Start week 1, complete week 2
- **Description:** Parse Lean AST and extract proof complexity metrics
- **Deliverables:**
  - [x] Script: `scripts/extract_lean_proof_metrics.py` (new)
  - [x] Metrics: proof depth, tactic frequency, module imports, theorem DAG
  - [x] Output: JSON artifact with per-theorem metrics
  - [x] Validation: Run on current proofs/, generate baseline
- **Metrics Definition:**
  ```json
  {
    "theorem_name": "theorem1_half_bound_of_forall",
    "proof_depth": 3,
    "tactic_count": 2,
    "tactics": ["omega"],
    "module_imports": ["Mathlib.Tactic.Omega"],
    "file": "proofs/LeanFormalization/Theorem1BFT.lean"
  }
  ```
- **Testing:** Run on 54 current theorems, validate JSON schema
- **Done Criteria:** Script runs without error, generates valid JSON for all theorems

---

### [MILESTONE] P2.2: Proof Regression Detection in CI
- **Owner:** DevOps
- **Status:** COMPLETE
- **Timeline:** Start week 2 (after P2.1 complete)
- **Description:** Add CI workflow to detect proof complexity regressions
- **Deliverables:**
  - [x] Workflow: `.github/workflows/proof-regression-check.yml` (new)
  - [x] Logic:
    - Extract metrics from base branch (cached)
    - Extract metrics from PR branch
    - Compare: flag if proof depth +20% OR tactic count +50%
  - [x] Output: PR comment with recommendations
- **Workflow Steps:**
  1. Checkout base branch, run P2.1 script, cache result
  2. Checkout PR branch, run P2.1 script
  3. Compare JSONs, generate diff markdown
  4. Post comment on PR if regressions detected (non-blocking)
- **Example Comment:**
  ```
  ⚠️ Proof regression detected:
  - theorem1_half_bound_of_forall: depth 3→5 (+67%)
  Suggestion: Consider using `decide` for arithmetic bounds.
  ```
- **Done Criteria:** Workflow runs on PR, detects +20% depth increase, comments posted

---

### [CHECKPOINT] P2.3: Theorem Dependency Audit
- **Owner:** DevOps
- **Status:** COMPLETE
- **Timeline:** Week 2 (can run in parallel with P2.2)
- **Description:** Detect circular imports and orphaned proofs
- **Deliverables:**
  - [x] Script: `scripts/audit_theorem_dependencies.py` (new)
  - [x] Checks: no circular imports, no dead code, all public theorems used
  - [x] CI integration: fail if cycles found
- **Script Output:**
  ```
  Circular imports: PASS
  Orphaned theorems: PASS (all 54 theorems used)
  Module graph: proofs/theorem_dependency_graph.json (generated)
  ```
- **Visualization (optional stretch):** Mermaid diagram in CI artifact
- **Done Criteria:** Script runs, no cycles found in current proofs, CI check integrated

---

## PRIORITY 3: Test Coverage Expansion (7-10 Days)

### [MILESTONE] P3.1: Property-Based Testing Layer
- **Owner:** QA
- **Status:** NOT STARTED
- **Timeline:** Start week 2, complete week 3
- **Description:** Add property-based tests for formal claims
- **Deliverables:**
  - [ ] New file: `test/property_based_test.go`
  - [ ] Properties (using `gopter` or `testing/quick`):
    1. Multi-Krum always selects f < n/2 honest
    2. RDP composition monotonic (ε_sum ≥ max(ε_i))
    3. Communication ≤ O(d * log n) bound
    4. Convergence envelope decreases with rounds
  - [ ] Test generation: 1000+ random inputs per property
  - [ ] CI integration: run on every PR
- **Learning curve:** 1-2 days for Go property-based testing (new framework)
- **Done Criteria:**
  - All 4 properties pass 1000+ random inputs
  - CI integration complete
  - Passes on current main branch

---

### [MILESTONE] P3.2: Adversarial Fuzzing for Aggregation
- **Owner:** QA
- **Status:** BLOCKED on P3.1 completion
- **Timeline:** Start week 3 (after P3.1)
- **Description:** Fuzz aggregation with Byzantine injections
- **Deliverables:**
  - [ ] Fuzz targets in `test/fuzz_aggregation_test.go`
  - [ ] Scenarios:
    - Byzantine rate 45%, 55%, 70%
    - Gradient overflow/underflow edge cases
    - Repeated compression cycles (artifact accumulation)
  - [ ] Fuzz time: 1 hour per PR (or opt-in for speed)
  - [ ] Corpus: GitHub-stored seeds for reproducibility
- **CI Option:** Run on `main` pushes only (long execution)
- **Done Criteria:** Fuzzer runs without panic, finds no new crashes in current code

---

### [CHECKPOINT] P3.3: 10M-Node Integration Simulation
- **Owner:** QA
- **Status:** NOT STARTED
- **Timeline:** Week 4 (after P3.1, P3.2 stabilize)
- **Description:** Synthetic 10M-node aggregation with Byzantine behavior
- **Deliverables:**
  - [ ] New test: `TestIntegration10MNodeSimulation` (long-running)
  - [ ] Validation:
    - Resilience holds at 55.5% Byzantine
    - Latency distribution captured
    - Forensics of rejected gradients
  - [ ] Artifact: `results/integration/10m-node-simulation.json`
  - [ ] CI: run on `main` + tags only (expensive)
- **Reuse:** Existing aggregator, random Byzantine injection
- **Performance:** Target <30 min execution (profile + optimize)
- **Done Criteria:** Test completes, resilience verified, artifact generated

---

## PRIORITY 4: Production Observability (6-8 Days)

### [MILESTONE] P4.1: Per-Theorem Runtime Metrics
- **Owner:** Backend
- **Status:** BLOCKED on QW2 (quick win)
- **Timeline:** Start week 3 (after QW2 done)
- **Description:** Instrument all formal claims in live runtime
- **Deliverables:**
  - [ ] Expand QW2 metrics + add comprehensive set
  - [ ] Dashboard: "Formal Properties Live" in Grafana
  - [ ] Alerting: breach rules for each claim
- **Metrics Details:**
  | Metric | Type | Update Freq | Threshold |
  | --- | --- | --- | --- |
  | `mohawk_bft_resilience_estimate` | Gauge | 1/round | 0.555 ±0.05 |
  | `mohawk_rdp_composition_current` | Gauge | 1/tier | ≤2.0 |
  | `mohawk_communication_cost_observed` | Histogram | 1/round | ≤O(d*log n) |
  | `mohawk_liveness_success_prob` | Gauge | 1/epoch | ≥0.9999 |
  | `mohawk_proof_verification_p99` | Histogram | 1/10s | ≤100ms |
  | `mohawk_convergence_trend` | Gauge | 1/epoch | trend ↓ |
- **Done Criteria:** All metrics exported, Grafana dashboard created, thresholds defined

---

### [CHECKPOINT] P4.2: Formal Proof Validation Endpoint
- **Owner:** Backend
- **Status:** BLOCKED on P4.1
- **Timeline:** Week 3 (can run parallel with P4.1)
- **Description:** Runtime endpoint to validate formal claims
- **Deliverables:**
  - [ ] Endpoint: `GET /proofs/validate?theorem=1&claim=0.555`
  - [ ] Response: status (passing/warning/breach), observed vs claimed
  - [ ] Operator dashboard polls every 60s
- **Example Response:**
  ```json
  {
    "theorem": 1,
    "claim": 0.555,
    "observed": 0.552,
    "status": "passing",
    "confidence": 0.98,
    "last_update": "2026-04-19T14:32:00Z"
  }
  ```
- **Done Criteria:** Endpoint responds, passes validation checks, integrated with dashboards

---

### [DELIVERABLE] P4.3: Deployment Playbooks
- **Owner:** Operations
- **Status:** NOT STARTED
- **Timeline:** Week 4
- **Description:** Runbooks for theorem claim breaches
- **Deliverables:**
  - [ ] File: `docs/operations/playbooks/theorem-bft-breach.md`
  - [ ] File: `docs/operations/playbooks/theorem-rdp-breach.md`
  - [ ] File: `docs/operations/playbooks/theorem-liveness-breach.md`
  - [ ] File: `docs/operations/playbooks/theorem-convergence-breach.md`
  - [ ] Runbook content: symptoms, diagnostics, remediation steps
  - [ ] AlertManager integration: breach alerts link to playbook URL
- **Example Playbook Structure:**
  ```markdown
  # BFT Resilience Breach Playbook
  
  ## Trigger
  `mohawk_bft_resilience_estimate > 0.60` (above 55.5% + margin)
  
  ## Diagnostics
  1. Check rejected gradient forensics: `grep "rejected_reason" logs/*`
  2. Verify Byzantine detector: `curl /metrics | grep byzantine_count`
  3. Review network health: `docker logs orchestrator | grep "connection"`
  
  ## Remediation
  - If Byzantine rate legitimate: increase resilience bounds (requires proof update)
  - If false alarm: recalibrate detector threshold
  - If network issue: check p2p connectivity
  ```
- **Done Criteria:** All 4 playbooks written, AlertManager links tested

---

## SUMMARY TABLE

| Item | Owner | Status | Start | End | Effort |
|------|-------|--------|-------|-----|--------|
| **QUICK WINS** |
| QW1 Docstrings | Lean | ⏳ | This week | EOW | 1d |
| QW2 Health Metrics | Backend | ⏳ | This week | EOW | 1d |
| QW3 Playbook | Docs | ⏳ | This week | EOW | 1d |
| **PRIORITY 1** |
| P1.1 Chernoff Bounds | Lean | ⏳ | W1 | W2 | 3-4d |
| P1.2 Real Convergence | Lean | ⏳ | W3 | W4 | 5-7d |
| P1.3 Matrix Update | QA+Lean | 🔒 | W2,W4 | W2,W4 | 2d |
| **PRIORITY 2** |
| P2.1 Metrics Extraction | DevOps | ✅ | W1 | W2 | 2d |
| P2.2 Regression Detection | DevOps | ✅ | W2 | W3 | 2d |
| P2.3 Dependency Audit | DevOps | ✅ | W2 | W3 | 1d |
| **PRIORITY 3** |
| P3.1 Property Tests | QA | ⏳ | W2 | W3 | 3d |
| P3.2 Fuzz Aggregation | QA | 🔒 | W3 | W4 | 2d |
| P3.3 10M Simulation | QA | 🔒 | W4 | W5 | 3d |
| **PRIORITY 4** |
| P4.1 Live Metrics | Backend | 🔒 | W3 | W4 | 2d |
| P4.2 Validation Endpoint | Backend | 🔒 | W3 | W4 | 2d |
| P4.3 Playbooks | Ops | 🔒 | W4 | W5 | 1d |

Legend: ⏳ = Ready to start | 🔒 = Blocked | ✅ = Complete

---

**Next Review:** Friday EOD (weekly standup)  
**Escalation:** Issues blocking start → discuss immediately  
**Success:** All quick wins complete by EOW → momentum for P1-P2
