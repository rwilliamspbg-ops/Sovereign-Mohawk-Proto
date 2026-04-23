# Machine Validation Implementation Plan

## Branch

- Working branch: `fix/phase3b-verification-alignment`
- Base branch: `main`
- Objective: replace abstract Lean proof placeholders with specification-backed, implementation-linked, machine-checkable verification.

## Current Status Snapshot (2026-04-23)

- Already implemented in repo:
  - `proofs/Specification/*` modules exist (`System`, `Byzantine`, `Privacy`, `Communication`, `Liveness`, `Cryptography`, `Convergence`).
  - `proofs/Refinement/*` modules exist (`MultiKrum`, `RDPAccountant`, `Transport`, `Ledger`).
  - `scripts/check_refinement.py` exists and validates required Lean/Go symbol alignment.
  - CI workflows include formal verification jobs and refinement checks:
    - `.github/workflows/verify-proofs.yml`
    - `.github/workflows/verify-formal-proofs.yml`
- Locally verified in this environment:
  - `python3 scripts/check_refinement.py --lean proofs/Specification/System.lean --go internal/` passes.
- Environment constraint observed:
  - `lake` is not currently installed in this container session, so Lean build verification could not be re-run here.

## Success Criteria

- Lean specs model real runtime behavior for critical components (`MultiKrum`, RDP accounting, transport bounds, ledger transfer safety).
- Refinement checks exist between spec and implementation behavior (Lean model + Go property checks, plus Gobra for critical Go paths).
- CI blocks merges on unfinished proofs/specs and broken refinement checks.
- Existing synthetic/arithmetical theorem claims are either upgraded to real assumptions and bounds or downgraded/removed from security claims.

## Scope (Phase 1 Delivery)

- In scope now:
  - Add formal specification layer under `proofs/Specification/`.
  - Add refinement layer under `proofs/Refinement/`.
  - Add machine validation tooling and CI wiring.
  - Add traceability updates proving what is actually machine-validated.
- Out of scope now (tracked, but not blocking this branch):
  - Full Groth16 game-hopping proof in Lean.
  - Full convergence proof under non-IID assumptions end-to-end.

## Current Gaps (Repo Reality)

- Abstract placeholders in theorem modules:
  - `proofs/LeanFormalization/Theorem2RDP.lean` uses abstract composition (`composeEps`).
  - `proofs/LeanFormalization/Theorem5Cryptography.lean` uses fixed `proofSize` and cost constants.
  - `proofs/LeanFormalization/Theorem6Convergence.lean` uses synthetic `envelope` arithmetic.
- Runtime implementation exists but is not formally linked:
  - `internal/multikrum.go`
  - `internal/rdp_accountant.go`
  - `internal/network/transport.go`
  - `internal/token/ledger.go`

## Workstreams

### WS1: Specification Layer (Lean)

Create new modules and migrate theorem statements from arithmetic placeholders to system specs.

Planned files:

- `proofs/Specification/System.lean` (new)
- `proofs/Specification/Byzantine.lean` (new)
- `proofs/Specification/Privacy.lean` (new)
- `proofs/Specification/Communication.lean` (new)
- `proofs/Specification/Liveness.lean` (new)
- `proofs/Specification/Cryptography.lean` (new)
- `proofs/Specification/Convergence.lean` (new)

Concrete tasks:

1. Define runtime-aligned data structures (`Node`, `Swarm`, message model, accountant state model).
2. Define implementation model functions (`multiKrumSelectImpl`, accountant step composition, transport message accounting).
3. Define spec functions and assumptions for each theorem domain.
4. Move current claim statements to reference these spec definitions.

Acceptance gates:

- `lake build` succeeds for all new modules.
- No `sorry`, `admit`, or unexplained broad `axiom` in production theorem modules.
- Each theorem header references exact runtime file(s) it intends to model.

### WS2: Refinement Layer (Spec -> Implementation)

Prove or check that modeled implementation behavior aligns with specification.

Planned files:

- `proofs/Refinement/MultiKrum.lean` (new)
- `proofs/Refinement/RDPAccountant.lean` (new)
- `proofs/Refinement/Transport.lean` (new)
- `proofs/Refinement/Ledger.lean` (new)
- `scripts/check_refinement.py` (new)

Concrete tasks:

1. `MultiKrum`: define `krumSpec` and `krumImpl` model; prove equality on shared domain constraints.
2. `RDPAccountant`: prove composition model matches accountant ledger arithmetic and conversion formula assumptions.
3. `Transport`: prove byte-count model upper-bounds protocol message accounting model.
4. `Ledger.Transfer`: verify conservation, nonce monotonicity, idempotency consistency.
5. Add automated type-shape and naming checks (`scripts/check_refinement.py`) to prevent spec/runtime drift.

Acceptance gates:

- Lean refinement modules compile.
- `scripts/check_refinement.py --lean proofs/Specification/System.lean --go internal/` passes.
- Runtime property tests pass for refinement assumptions.

### WS3: Go Verification and Runtime Validation

Use direct Go verification where Lean modeling is too indirect.

Planned files:

- `proofs/gobra/MultiKrum.gobra` (new)
- `proofs/gobra/RDP.gobra` (new)
- `proofs/gobra/Ledger.gobra` (new)
- `test/property/refinement_properties_test.go` (new)

Concrete tasks:

1. Gobra specs for:
   - `internal/multikrum.go` (`MultiKrumSelect`, `MultiKrumAggregate`).
   - `internal/rdp_accountant.go` (`RecordStepRat`, `CheckBudget`).
   - `internal/token/ledger.go` (`TransferWithControls`).
2. Property-based tests validating executable behavior against model invariants.
3. Add deterministic adversarial test vectors for Byzantine and accountant edge cases.

Acceptance gates:

- Gobra checks pass in CI for critical functions.
- Property tests run in PR CI and pass.

### WS4: Cryptography Claims Realignment

Convert constant-time/constant-size placeholders into defensible assumptions and verifiable interfaces.

Planned files:

- `proofs/Specification/Cryptography.lean` (new)
- `proofs/LeanFormalization/Theorem5Cryptography.lean` (update)
- `docs/formal/CRYPTO_ASSUMPTIONS.md` (new)

Concrete tasks:

1. Replace fixed-size placeholder theorem with assumption-scoped theorem (q-SDH style assumption declaration).
2. Specify Groth16 verification equation interface in Lean (abstract group operations, no fake constants).
3. Add explicit boundary: computational soundness delegated to CryptoVerif/EasyCrypt artifacts.
4. Add FFI-correctness theorem target for Go->WASM->Rust verifier path if applicable.

Acceptance gates:

- No claim states unconditional constant-time/constant-size without assumption or implementation evidence.
- Traceability matrix links theorem claims to concrete artifact type (Lean/Gobra/CryptoVerif/EasyCrypt/test evidence).

### WS5: CI and Governance

Update CI from proof-presence checks to real validation pipeline checks.

Planned files:

- `.github/workflows/verify-proofs.yml` (update)
- `.github/workflows/verify-formal-proofs.yml` (update if needed)
- `.github/workflows/formal-verification.yml` (new, optional consolidation)
- `proofs/FORMAL_TRACEABILITY_MATRIX.md` (update)
- `proofs/FORMAL_VERIFICATION_GUIDE.md` (update)

Concrete tasks:

1. Add jobs:
   - `lean-specs`
   - `gobra-verification`
   - `refinement-check`
2. Ensure placeholder scanning covers new `proofs/Specification/` and `proofs/Refinement/` trees.
3. Upload machine-readable artifacts (spec hash, refinement report, gobra outputs).
4. Fail PR if theorem claims in matrix do not resolve to proof/check artifacts.

Acceptance gates:

- CI fails on broken refinement or unresolved theorem traceability.
- CI artifacts include proof/check summaries suitable for audit.

## Ordered Execution Plan

### Milestone M1 (Days 1-2): Repository Scaffolding

- Create Lean directories and baseline module files.
- Add imports to `proofs/LeanFormalization.lean` as needed.
- Add initial CI placeholders for new jobs (skipped mode allowed).

Exit criteria:

- `lake build` still green.
- No net regression in existing workflows.

### Milestone M2 (Days 3-6): MultiKrum + RDP End-to-End Slice

- Implement `System.lean` and `Refinement/MultiKrum.lean`, `Refinement/RDPAccountant.lean`.
- Add `scripts/check_refinement.py` for shape alignment.
- Add Gobra specs for MultiKrum and RDP.

Exit criteria:

- End-to-end slice passes locally and in CI for MultiKrum + RDP.

### Milestone M3 (Days 7-9): Communication + Ledger Slice

- Add communication and ledger spec/refinement modules.
- Add Gobra verification for ledger transfer atomicity/conservation.
- Add property tests for transport accounting and ledger invariants.

Exit criteria:

- Communication and ledger checks are machine-enforced in CI.

### Milestone M4 (Days 10-12): Cryptography and Claim Realignment

- Replace synthetic theorem 5 claim language with assumption-scoped statement.
- Add crypto assumptions document and traceability mapping.
- Add optional FFI correctness target if runtime path is available.

Exit criteria:

- No synthetic cryptography claims remain in active theorem set.

### Milestone M5 (Days 13-14): Final CI Gate + Audit Output

- Turn all relevant verification jobs to required.
- Update verification guide and matrix to reflect real checks.
- Produce final machine-validation report artifact.

Exit criteria:

- PR-ready with reproducible verification commands and green CI.

## Command Matrix (Developer Workflow)

- Lean build:
  - `cd proofs && lake update && lake build`
- Placeholder scan:
  - `grep -RIn "\bsorry\b\|\badmit\b" proofs/Specification proofs/Refinement proofs/LeanFormalization`
- Refinement shape check:
  - `python3 scripts/check_refinement.py --lean proofs/Specification/System.lean --go internal/`
- Gobra checks (when installed):
  - `gobra -I internal/multikrum.go -p proofs/gobra/MultiKrum.gobra --backend SILICON`
  - `gobra -I internal/rdp_accountant.go -p proofs/gobra/RDP.gobra --backend SILICON`
  - `gobra -I internal/token/ledger.go -p proofs/gobra/Ledger.gobra --backend SILICON`
- Runtime tests:
  - `go test ./...`

## Risks and Mitigations

- Risk: Lean model diverges from Go semantics.
  - Mitigation: enforce shape checks and property tests per refinement module.
- Risk: Gobra onboarding and invariant burden slows throughput.
  - Mitigation: restrict Gobra to critical path functions first.
- Risk: Cryptographic claims exceed practical Lean scope.
  - Mitigation: split claim into assumption-scoped Lean statement + computational proof artifacts.
- Risk: CI runtime growth.
  - Mitigation: split PR-gate checks (fast) vs scheduled deep verification (slow).

## Deliverables for This Branch

- This plan document.
- Feature branch for implementation kickoff.
- Next PR (follow-up): M1 scaffolding + CI wiring skeleton.

## Immediate Next Actions (Current PR)

1. Strengthen refinement semantics beyond identity-style equalities by replacing direct `rfl` mirror definitions where possible with implementation-to-spec relation lemmas tied to explicit assumptions.

1. Expand drift checks in `scripts/check_refinement.py` by adding required symbols for transport accounting and ledger controls beyond file/function presence.

1. Unify placeholder policy language across workflows by ensuring both formal workflows use the same `sorry`/`axiom`/`admit` gate semantics and messaging.

1. Add artifact-level evidence hooks by emitting refinement check JSON (`--json`) as a CI artifact for audit traceability.

1. Re-run full Lean compile gate in a Lean-enabled environment and attach output artifacts to the PR.

## Ownership Proposal

- Lean/spec lead: formal methods engineer
- Go runtime verification lead: backend engineer
- CI and artifact pipeline lead: DevOps engineer
- Cryptography evidence lead: cryptography engineer

## Definition of Done

- Every externally stated theorem claim has:
  - a formal spec,
  - a machine-checked proof or verification artifact,
  - a traceable link to runtime implementation,
  - CI enforcement that blocks regressions.
