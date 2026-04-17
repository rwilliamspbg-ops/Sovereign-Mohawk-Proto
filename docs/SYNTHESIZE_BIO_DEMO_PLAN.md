# Synthesize.bio Dataset Demo Plan for Sovereign Mohawk Proto

## Goal
Build a reproducible, evidence-backed demo that uses real datasets from `https://app.synthesize.bio/datasets` to show Sovereign Mohawk Proto end-to-end: privacy-preserving federation, Byzantine-resilient aggregation, proof-backed verification, policy-gated routing, and compliance-grade artifacts.

## Branch
- Working branch: `feat/synthesizebio-demo-plan`
- Target merge branch: `main`

## Demo Storyline (What the audience sees)
1. Three institutions each train locally on different synthesize.bio datasets (heterogeneous schemas).
2. Sovereign Mohawk node-agents submit updates under differential privacy budget controls.
3. Aggregation layer applies Byzantine filtering and robust aggregation.
4. Proof verifier validates model/protocol evidence.
5. Federated router shares approved, policy-constrained insights across domains.
6. Observability stack shows metrics and audit lineage in real time.
7. Compliance artifact pack is generated from run outputs.

## Dataset Strategy
Use 3 datasets from synthesize.bio with different modality and label distributions.

Selection criteria:
- Dataset A: tabular clinical outcomes (binary classification).
- Dataset B: time-series or encounter-level data (risk scoring).
- Dataset C: different schema/domain to exercise router translation and policy gates.

Data policy controls:
- No raw row-level export to demo artifacts.
- Keep dataset manifests and feature mappings only.
- Document source dataset IDs, terms-of-use, and permitted processing in an allowlist manifest.

## Architecture
- Institution 1 (Region us-east): node-agent + local trainer on Dataset A
- Institution 2 (Region eu-west): node-agent + local trainer on Dataset B
- Institution 3 (Region ap-south): node-agent + local trainer on Dataset C
- Aggregation/Orchestrator: existing local 3-node stack pattern
- Proof and policy: existing verifier + bridge policy files
- Monitoring: Prometheus + Grafana dashboards

## Concrete Implementation Plan

### Phase 0 - Compliance and Access (Day 1)
- Confirm synthesize.bio dataset license/usage constraints for demo publication.
- Create `demo/synthesize_bio/dataset_allowlist.yaml` with:
  - dataset_id
  - modality
  - allowed_use
  - export_restrictions
- Add `demo/synthesize_bio/DATA_GOVERNANCE.md` documenting handling boundaries.

Exit criteria:
- Dataset allowlist approved by project owner.
- No blocked legal/compliance items.

### Phase 1 - Data Connectors and Normalization (Days 1-2)
- Add ingestion script: `scripts/demo_synthesizebio_ingest.py`
- Add canonical feature schema: `demo/synthesize_bio/schema/canonical_features.yaml`
- Add per-dataset mappers:
  - `demo/synthesize_bio/schema/map_dataset_a.yaml`
  - `demo/synthesize_bio/schema/map_dataset_b.yaml`
  - `demo/synthesize_bio/schema/map_dataset_c.yaml`
- Add quality gates for null/label drift:
  - `scripts/demo_synthesizebio_data_quality.py`

Exit criteria:
- All selected datasets map to canonical schema.
- Data quality gate passes and writes a report artifact.

### Phase 2 - Federated Training Scenario (Days 2-3)
- Add trainer harness: `scripts/demo_synthesizebio_train.py`
- Add demo scenario config: `demo/synthesize_bio/scenario.yaml`
- Configure 3 clients with non-IID partitions and round schedule.
- Integrate DP runtime knobs and log privacy spend per round.

Exit criteria:
- 10+ rounds complete in local environment.
- Per-client and global metrics are emitted and persisted.

### Phase 3 - Resilience and Proofs (Day 3)
- Add adversarial client simulation (gradient poisoning / label flip).
- Validate Byzantine filtering behavior using existing evidence pattern.
- Add proof artifact capture script:
  - `scripts/demo_synthesizebio_capture_proofs.sh`
- Produce artifact bundle:
  - aggregation acceptance/rejection report
  - proof verification status
  - runtime guardrail settings snapshot

Exit criteria:
- Malicious update is detected/rejected in at least one scenario.
- Proof verification passes for accepted rounds.

### Phase 4 - Router + Cross-Domain Policy Demo (Day 4)
- Add router policy profile for healthcare demo:
  - `demo/synthesize_bio/bridge-policies.demo.json`
- Route approved aggregate insights to a second domain consumer.
- Demonstrate schema translation + provenance chaining.

Exit criteria:
- Policy-allowed route succeeds.
- Policy-blocked route is denied with auditable reason.

### Phase 5 - Evidence and Operator UX (Day 5)
- Add one-command demo runner:
  - `scripts/run_synthesizebio_demo.sh`
- Add metrics snapshot collector:
  - `scripts/demo_synthesizebio_collect_metrics.sh`
- Add final report template:
  - `results/demo/synthesize_bio/README.md`
- Capture screenshots/plots from Grafana and key logs.

Exit criteria:
- New operator can run full demo with one command.
- Evidence folder is complete and deterministic.

### Phase 6 - Documentation and Release Readiness (Day 5)
- Add runbook:
  - `docs/DEMO_SYNTHESIZE_BIO_RUNBOOK.md`
- Add troubleshooting guide for common failures.
- Add README section linking demo assets and commands.

Exit criteria:
- Dry run performed by second operator.
- Runbook steps validated end-to-end.

## Acceptance Criteria (Must Pass)
- Functional:
  - End-to-end demo run completes with 3 institutions and 10+ rounds.
  - Global model quality improves from round 1 to final round.
- Security/Trust:
  - Byzantine mitigation evidence captured.
  - Proof verification status captured and passing.
- Privacy:
  - Differential privacy budget logs generated per round.
  - No prohibited raw dataset export in artifacts.
- Governance:
  - Policy allow/deny route behavior demonstrated.
  - Audit trail includes dataset IDs and policy decisions.
- Operability:
  - Single command runner works on clean checkout.
  - Results are reproducible (same command -> same artifact structure).

## Demo Command Path (Target)
```bash
# 1) bootstrap stack
make full-stack-3-nodes

# 2) run synthesize.bio demo scenario
bash scripts/run_synthesizebio_demo.sh

# 3) collect evidence and reports
bash scripts/demo_synthesizebio_collect_metrics.sh
make go-live-gate-advisory

# 4) teardown
make full-stack-3-nodes-down
```

## Risks and Mitigations
- Dataset API/format changes:
  - Mitigation: freeze dataset version IDs in allowlist and checksum manifests.
- License ambiguity for public demo artifacts:
  - Mitigation: publish only aggregate metrics and synthetic visualizations.
- Non-deterministic training variance:
  - Mitigation: fixed seeds, pinned environment, deterministic artifact naming.
- Runtime drift from main branch:
  - Mitigation: nightly demo smoke test in CI (advisory mode first).

## Immediate Next Build Tasks
1. Finalize three concrete synthesize.bio dataset IDs.
2. Implement ingestion + schema maps.
3. Implement scenario config and runner shell script.
4. Run first end-to-end pass and generate baseline artifact pack.
5. Iterate on storyline visuals and operator runbook.
