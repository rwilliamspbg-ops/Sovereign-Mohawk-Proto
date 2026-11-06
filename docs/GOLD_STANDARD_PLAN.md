# Gold-Standard Elevation Plan
## Sovereign-Mohawk-Proto — from research testbed to #1 high-assurance FL platform

**Status:** Draft (2026-11-06) — planning document, not yet scheduled.
**Owner:** TBD (engineering + formal-methods lead)
**Companion:** `ROADMAP.md` (Phase 3/4), `docs/EXTERNAL_AUDIT_SCOPE.md`, `proofs/FORMAL_TRACEABILITY_MATRIX.md`

---

## 0. Honest baseline (what already exists)

Before planning, the four "gaps" in the source proposal map onto code that is
**partially implemented**, not absent. Each pillar below states the real current
state so we do not re-plan work that is done.

| Pillar | Already present | Partially present | Missing |
|---|---|---|---|
| 1. ZK weight verifiability | `internal/zksnark_verifier.go` (BN254 Groth16), `internal/zksnark_circuit_verifier.go`, ZK-SNARK/STARK hybrid paths, `proofs/ZKSnarkVerification.lean` | Verifies a **static genesis identity**, not a per-update gradient proof | Client-side circuit compilation; per-update proof generation; gradient-norm + DP-noise constraints in circuit |
| 2. Wide-area mesh resilience | `internal/network/transport.go` (libp2p host), `libp2p/go-libp2p` dep, KEX mode parsing, `internal/transport/interface.go`, MRC adapter | Transport abstraction exists; gossip/Kademlia/hole-punching not wired into the federation control plane | DHT routing, NAT hole-punching, async fault-tolerant consensus across tiers, WAN chaos evidence |
| 3. Lean → executable code | `proofs/LeanFormalization/` (Lean 4), `scripts/check_refinement.py`, `scripts/ci/check_theorem_runtime_consistency.py`, 12/12 pattern checks | Static consistency checks only — no compile-time proof that Go matches Lean | Verified compilation/synthesis pipeline (Kani, Hax, or codegen); CI gate that fails on divergence |
| 4. TEE native acceleration | TPM attestation (Linux hardware-backed), XMSS, `results/security-audit/*` | TPM identity only; aggregation/training in user space | SEV-SNP/SGX/TrustZone integration, enclave-protected aggregation, MPC at regional tier |

**Conclusion:** the chasm is not "absent → present"; it is "present in
simulation/static form → present in adversarial/production form." Plan accordingly.

---

## 1. Pillar 1 — Dynamic ZK weight verifiability

### Goal
Every client update carries a SNARK proving (a) training ran on the stated
dataset commitment, (b) gradient norm ≤ bound, (c) DP noise was added before
compression. Aggregator verifies in O(1) pairing time; no trust in Multi-Krum
alone.

### Phases

**P1.1 — Circuit specification (2–3 weeks)**
- Write a Lean + Noir/Halo2 circuit spec for: forward pass on committed
  batch, gradient computation, norm clipping, DP noise injection, compression.
- Define the public inputs: model hash (before/after), dataset commitment,
  gradient norm bound, DP ε/δ, compressed update hash.
- Deliverable: `proofs/ZKWeightProof.lean` + `circuits/weight_update.nr` (or `.rs` for Halo2).
- Gate: circuit compiles to a proving key; constraint count documented.

**P1.2 — Client-side prover integration (3–4 weeks)**
- Add a prover binary/module callable from the Go node-agent (cgo or sidecar).
- Generate proof alongside the update; attach to `GradientUpdate` proto.
- Benchmark: proof time on a representative model (target < 30s on CPU, < 5s on GPU).
- Gate: end-to-end test proves an honest update and rejects a poisoned one.

**P1.3 — Aggregator verification + Multi-Krum demotion (2 weeks)**
- Aggregator verifies the SNARK before accepting an update; Multi-Krum becomes
  a secondary filter, not the primary trust root.
- Fail-closed: missing/invalid proof → reject update (no silent accept).
- Gate: chaos test with 30% Byzantine nodes still converges; proof-verification
  count exposed in metrics.

**P1.4 — Formal link (2 weeks)**
- Extend `proofs/ZKSnarkVerification.lean` to state the per-update soundness
  theorem; add a refinement bridge to `internal/zksnark_circuit_verifier.go`.
- Update `proofs/FORMAL_TRACEABILITY_MATRIX.md`.

### Risks
- Proving time on large models (transformers) may exceed epoch budget →
  scope to MLP/CNN first; document.
- Trusted setup (Groth16) vs transparent (Halo2/STARK) — recommend Halo2 for
  no-trusted-setup, or keep Groth16 with a documented ceremony (open item).

### Dependencies
- Needs P2 (mesh) only for WAN proof transport; P1 can ship on local Docker.

---

## 2. Pillar 2 — True wide-area mesh resilience

### Goal
Federation runs over libp2p with Kademlia DHT, NAT hole-punching, QUIC
transport, and async fault-tolerant consensus; survives 30% node drop mid-epoch
on a WAN testbed.

### Phases

**P2.1 — Transport hardening (2 weeks)**
- Wire `internal/network/transport.go` into the federation control plane
  (currently isolated). Add QUIC + TCP fallback, connection pooling.
- Add peer discovery via Kademlia DHT (currently absent).
- Gate: 50-node local libp2p mesh forms and routes.

**P2.2 — NAT traversal (2 weeks)**
- Enable libp2p hole-punching + relay (circuit relay v2) for NAT'd nodes.
- Add a public bootstrap/relay node list (configurable).
- Gate: two nodes behind separate NATs connect via hole-punch.

**P2.3 — Async consensus (3–4 weeks)**
- Replace synchronous epoch barriers with async aggregation (FedAsync-style or
  bounded staleness). Handle stragglers without stalling global update.
- Add Byzantine-straggler detection (timeout + reputation).
- Gate: 1000-node simulation with 20% stragglers completes epoch < 2× baseline.

**P2.4 — WAN evidence (2 weeks)**
- Run on a multi-region testbed (3+ cloud regions) or a chaos-injected WAN
  emulator (tc netem). Publish `results/wan-evidence/`.
- Update `docs/BENCHMARKS_AND_REPRODUCIBILITY.md` with WAN numbers.

### Risks
- libp2p Go module weight → build time / binary size; acceptable.
- Async aggregation convergence proofs are harder → Lean model update needed
  (Pillar 3).

---

## 3. Pillar 3 — Lean → executable code (verified compilation)

### Goal
A change to an aggregation function in Go that violates a Lean theorem fails CI.
No implementation-level divergence.

### Phases

**P3.1 — Property-based fuzzing bridge (2 weeks)**
- Add a Go fuzz harness (`testing.F`) for each aggregation function with
  invariants derived from Lean theorems (e.g., norm bound, monotonicity).
- Add `go test -fuzz` to CI (bounded, 60s per target).
- Gate: fuzz finds no counterexamples on current code.

**P3.2 — Bounded model checking (Kani) for Rust components (3 weeks)**
- Identify Rust components (if any) or port critical aggregation to a
  Kani-verifiable Rust shim; run `cargo kani` in CI.
- If no Rust, use CBMC/ESBMC on the Go-generated C? → defer; keep fuzzing.

**P3.3 — Verified codegen (long-term, 6–12 weeks)**
- Evaluate Hax (Lean ↔ Rust) or a Lean → Go code generator for the
  aggregation kernel only (not the whole runtime).
- Scope deliberately narrow: only the pure aggregation function.
- Gate: generated code bit-identical to hand-written on a test suite; CI
  verifies regeneration produces no diff.

### Risks
- Full verified compilation is a research project; scope to the aggregation
  kernel to keep it tractable. Do not attempt whole-runtime verification.

---

## 4. Pillar 4 — TEE native acceleration

### Goal
Regional aggregators run inside SEV-SNP/SGX enclaves; raw intermediate
updates never visible to the host. SMPC at regional tier for multi-party
aggregation.

### Phases

**P4.1 — Enclave abstraction (2 weeks)**
- Define a `TEEProvider` interface in `internal/tee/` with implementations:
  SGX (via Gramine/EGo), SEV-SNP (via Coconut-SVSM or direct), TrustZone
  (stub for ARM).
- Attestation: extend TPM attestation to include enclave measurement.

**P4.2 — Enclave-protected aggregation (3–4 weeks)**
- Move the aggregation kernel into the enclave; pass encrypted updates in,
  receive aggregated result out.
- Key provisioning via remote attestation + sealed storage.
- Gate: aggregation produces identical result inside and outside enclave on
  test vectors.

**P4.3 — SMPC at regional tier (4–6 weeks)**
- Integrate a secret-sharing or MPC framework (e.g., MP-SPDZ or a Go MPC
  library) for multi-aggregator aggregation without any single party seeing
  plaintext.
- Gate: 3-party MPC aggregation matches plaintext on test vectors.

**P4.4 — Compliance & docs (1 week)**
- Update `docs/security/THREAT_MODEL.md`, `docs/EXTERNAL_AUDIT_SCOPE.md`,
  `docs/security/COMPLIANCE.md` with TEE scope limits and residual risks.

### Risks
- Hardware availability: SEV-SNP requires specific AMD EPYC; SGX requires
  specific Intel; CI cannot run enclave tests → use simulation mode in CI,
  real hardware in a nightly job.
- Performance overhead of MPC may be unacceptable for large models →
  benchmark and document; consider hybrid (enclave for small, MPC for sensitive).

---

## 5. Cross-cutting work

- **CI**: add a `gold-standard-gate` workflow that runs P1.2/P2.1/P4.2
  integration tests on a schedule (nightly), not on every PR.
- **Docs**: each pillar gets a "what is real / what is still open" section
  (follow `docs/CONTRIBUTING_DOCS.md` honesty bar).
- **Formal**: extend `proofs/FORMAL_TRACEABILITY_MATRIX.md` with new theorem
  entries for each pillar.
- **Metrics**: expose proof-verification count, mesh peer count, enclave
  attestation status, MPC party count.

---

## 6. Sequencing & effort summary

| Pillar | Effort | Can parallelize with | Blocks |
|---|---|---|---|
| P1 (ZK weights) | 9–11 weeks | P2.1, P4.1 | P3.1 (fuzz invariants) |
| P2 (mesh) | 9–10 weeks | P1, P4.1 | P3.2 (async proofs) |
| P3 (verified codegen) | 11–17 weeks | P1, P2, P4 | nothing (enhances all) |
| P4 (TEE) | 10–13 weeks | P1, P2 | P3.3 (codegen scope) |

**Recommended order:** P4.1 + P2.1 + P1.1 in parallel (foundations), then
P1.2/P2.2/P4.2, then P1.3/P2.3/P4.3, then P3.1–P3.3, then P1.4/P2.4/P4.4.

**Total to "gold standard":** ~6–9 months of focused engineering, assuming
2–3 engineers + 1 formal-methods specialist.

---

## 7. What this plan deliberately does NOT do

- Does **not** claim the existing Groth16 verifier proves per-update honesty
  (it proves genesis identity only).
- Does **not** claim libp2p is wired into the federation control plane
  (it is imported but isolated).
- Does **not** claim TEE protects aggregation (TPM attests identity only).
- Does **not** attempt whole-runtime verified compilation (scope limited to the
  aggregation kernel).
- Does **not** invent performance numbers; all targets are to-be-measured and
  published as evidence.

---

## 8. Decision points for the maintainer

1. **ZK backend choice**: Halo2 (transparent, no trusted setup) vs Groth16
   (faster verification, needs ceremony). Recommend Halo2 for "no trust"
   narrative.
2. **TEE priority**: SEV-SNP (AMD, broader cloud availability) vs SGX
   (Intel, more mature tooling). Recommend SEV-SNP primary, SGX secondary.
3. **MPC vs enclave**: decide whether regional aggregation needs MPC (stronger,
   slower) or enclave-only (faster, hardware trust). Recommend enclave-first,
   MPC as opt-in for highest-sensitivity deployments.
4. **Scope of verified codegen**: kernel-only (recommended) vs full runtime
   (not recommended — infeasible).

---

## 9. Next concrete action

Pick one pillar and open a tracking issue with the P*.1 sub-tasks. Suggested
first move: **P1.1 (circuit specification)** + **P4.1 (enclave abstraction)**
in parallel, since both are self-contained and unblock the rest.
