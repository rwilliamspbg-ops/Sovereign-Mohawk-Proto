# ZK Circuit & Verifier Finalization Plan

Status: **implemented 2026-11-18** (M1, M2, M3-benchmark, M4, M5; the M3 figure
retraction is deferred). Scope: Pillar 1 of
[`GOLD_STANDARD_PLAN.md`](GOLD_STANDARD_PLAN.md) — close the circuit-binding gap
and replace the unbacked zk performance figures with measured artifacts.

---

## Completion status (2026-11-18)

| WP | State | Evidence |
| --- | --- | --- |
| M1 sound binding | **done** | `internal/zkweight_circuit.go`; `test/zkweight_circuit_test.go` (honest round-trip, distinct-witness binding, tampered statement, over-bound, zero dataset, tampered proof); 9569 constraints |
| M2 production wiring | **done, with two honest gaps** | `internal/zkprover/gnark.go`; `internal/batch/aggregator.go`; `test/batch_zkweight_attestation_test.go`. **Gap 1:** `computeproof.Trace` has no production producer at all (only `computeproof_property_test.go` and `test/computeproof_test.go` construct it, and there is no `GradientUpdate{` construction site anywhere in the tree), so populating it would mean inventing a caller; it is left unwired and recorded here rather than faked. **Gap 2:** `zkprover.MockProver` / `CLIProver` remain placeholders; `SelectProver` can still return them, so they must not be used in a production proof path. |
| M3 real evidence | **partial** | `cmd/zkweightbench`, `.github/workflows/zk-circuit-gate.yml`, `results/zk/weight-proof-latest.json` (verify 0.67 ms, prove 34 ms, setup 44 s). **The figure retraction is deferred** — see below |
| M4 formal link + docs | **done** | `Theorem5Cryptography.lean` `WeightUpdateCircuit` section; matrix row 21; `circuits/README.md` corrected; `GOLD_STANDARD_PLAN.md` status |
| M5 decision record | **done** | §1 below |

**Deferred (M3 retraction).** The advertised "10 ms zk-SNARK verification"
figures (`CHANGELOG.md:745,801`, `sdk/python/README.md:13,23,572`,
`docs/HARDWARE_COMPATIBILITY.md:41`, `docs/DoD_Alignment_Addendum.md:151`) and
the `time.sleep(0.0104)` mock in `sdk/python/tests/test_benchmarks.py` are
**unchanged**. They now coexist with the real measurement
(`results/zk/weight-proof-latest.json`), which reports **0.67 ms** verify — the
advertised number is a sleep, not a measurement, and should be retracted or
replaced with a pointer to the artifact.

---

## 0. Problem statement

Two independent defects, both confirmed by reading the tree on `main`.

### 0.1 Binding gap — no proof today attests anything about gradients or weights

There are **two disconnected circuits**:

| Circuit | Where | Public inputs | Private inputs | Wired to Go? |
| --- | --- | --- | --- | --- |
| `weight_update` (Noir) | `circuits/src/main.nr` | `model_hash_before`, `model_hash_after`, `dataset_commitment`, `grad_norm_bound`, `dp_epsilon`, `update_hash` | `[Field; 8]` gradients, `[Field; 8]` noise, `training_steps` | **No** — compiles in CI (`noir-circuit-check.yml`) and stops there |
| `DataCommitmentCircuit` (gnark) | `internal/zksnark_circuit_verifier.go` | `Commitment` (one field element) | `Preimage` (one field element) | **Yes** — `pyapi`, `internal/hybrid`, `internal/batch` |

Only the second is reachable from production. It proves *"I know a MiMC preimage of
this commitment"* — a single scalar. The Go prover that feeds it
(`internal/zkprover/gnark.go:31-41`) folds the gradient vector into that scalar
with a **linear XOR of shifted float64 bit patterns**:

```go
preimage.Xor(preimage, new(big.Int).SetUint64(bits<<uint(i%64)))
```

XOR is linear and trivially collision-prone (two distinct gradient vectors can
fold to the same preimage), so the "binding" is not collision-resistant. Worse,
`GnarkProver.Prove` **ignores `PublicInputs` entirely** — `ModelHashBefore`,
`ModelHashAfter`, `DatasetCommitment`, `UpdateHash`, `DPEpsilon` are never
asserted. A valid proof therefore says nothing about the model update it
accompanies.

`internal/computeproof.Trace` already carries the right fields
(`DatasetCommitment`, `ModelCommitmentBefore`, `ModelCommitmentAfter`,
`types.go:17-19`) but **no production caller populates them** — only
`computeproof_property_test.go` and `test/computeproof_test.go` do.

### 0.2 Evidence gap — the advertised 10 ms figure is a `time.sleep`

| Advertised claim | Location | Backing |
| --- | --- | --- |
| "zk-SNARK verification: 10ms (maintained from Go runtime)" | `CHANGELOG.md:745` | none |
| "10ms zk-SNARK proof verification (Theorem 5)" | `CHANGELOG.md:801` | none |
| Badge "Proof Verify Mean 10.55ms" | `sdk/python/README.md:13` | **mocked** |
| "10.55ms mean in the benchmark suite" | `sdk/python/README.md:572` | **mocked** |
| "Constant-time (10ms) zk-SNARK verification for 10M nodes" | `internal/zksnark_verifier.go:16` | none (the 15 ms value at `:159` is a timeout guard, not a measurement) |
| "10 ms zk-SNARK Window" | `docs/HARDWARE_COMPATIBILITY.md:41` | evidence column points at TPM attestation files, not zk |
| "zk-SNARK/STARK proofs (~10 ms)" | `docs/DoD_Alignment_Addendum.md:151` | none |

The generating "benchmark" is `sdk/python/tests/test_benchmarks.py:18-31`:

```python
def run_verify():
    # Mocking the 10.4ms latency currently seen in the WASM runtime
    time.sleep(0.0104)
```

So the headline number is a hardcoded sleep. `performance-gate.yml` runs this
file against a baseline, i.e. **the performance gate measures a sleep**. There is
no zk benchmark artifact anywhere under `results/` or `captured_artifacts/`, and
`VerifyDataCommitmentProof` — the only real circuit verifier — has **no
benchmark at all**.

### 0.3 Secondary defects found during the survey

- `circuits/README.md` overstates `main.nr`: it lists a `dp_delta` public input
  (absent), a "compression fidelity" constraint (absent), and a DP-noise
  "range proof or committed randomness seed" (absent).
- `zksnark_verifier.go:117` cross-references "GOLD_STANDARD_PLAN P1.1" for
  genesisVK migration, but P1.1 there is *circuit specification* — stale link.
- `GnarkProver.Verify` recovers the commitment from 32 trailing bytes appended by
  `Prove` (`gnark.go:51-54, 66-68`) rather than from the statement — a
  non-standard wire format that any other prover cannot satisfy.
- `zkprover.MockProver` and `zkprover.CLIProver.Verify` are placeholders;
  `CLIProver` has no implementation behind it.

---

## 1. Architecture decision (blocks everything else)

**Pick exactly one circuit and one backend.** Recommended:

> **gnark / Groth16 / BN254, in Go.** The Noir `weight_update` circuit is
> retained as the *specification* (public inputs + constraint list) and ported
> to gnark.

Reason: gnark is already wired end-to-end (compile → MPC setup → prove → verify)
and needs no sidecar process; `internal/zkprover`, `internal/hybrid`,
`internal/batch`, and `pyapi` already route to it. The cost is the trusted
setup, which is currently an **in-process MPC simulation**
(`zksnark_circuit_verifier.go:34-43`) — that must be either replaced by a real
ceremony or explicitly downgraded to "development key".

Rejected alternative: Halo2/Noir. Transparent setup, but requires the P1.2
sidecar prover, a second verifier implementation, and a ceremony decision
(`GOLD_STANDARD_PLAN.md` §8.1). Revisit only if "no trusted setup" becomes a
hard requirement.

**Decision record (2026-11-18): gnark / Groth16 / BN254, adopted.**
`WeightUpdateCircuit` is implemented and wired; `circuits/src/main.nr` is
retained as the human-readable specification. Trusted-setup disposition: the
setup remains an in-process MPC simulation (`mpcSetupBN254` in `internal/zkweight_circuit.go`, 3
contributors, public beacon) and is labelled a development key in code and
docs — a production deployment needs a real ceremony or a switch to a
transparent backend.

**Deliverable of this decision:** a written record in this file (or
`GOLD_STANDARD_PLAN.md` §8) stating the chosen backend, the rejected
alternative, and the trusted-setup disposition.

---

## 2. Target circuit

New `WeightUpdateCircuit` (gnark, BN254), mirroring `circuits/src/main.nr`:

- **Public:** `model_hash_before`, `model_hash_after`, `dataset_commitment`,
  `grad_norm_bound`, `dp_epsilon`, `update_hash`.
- **Private:** `gradients []frontend.Variable`, `noise []frontend.Variable`,
  `training_steps`.
- **Constraints:**
  1. `model_hash_after == H(model_hash_before, training_steps, gradients…)`
  2. `sum(gradients[i]^2) <= grad_norm_bound^2`, each `|gradients[i]|` range-checked
  3. `update_hash == H(dp_epsilon, training_steps, gradients[i]+noise[i]…, dataset_commitment)`
  4. `dataset_commitment != 0`
- **Fixed arity** `N` (start 8, matching the Noir circuit) with a documented
  scaling path to 64/256/1024; constraint count recorded per `N`.

The hash `H` is MiMC over BN254 (already a dependency) so the same primitive is
used in- and off-circuit.

---

## 3. Work packages

### M1 — Sound binding (circuit + prover) · ~1 week
- [ ] Implement `WeightUpdateCircuit` and its gnark setup (reuse the existing
      MPC flow; record contributor count and beacon).
- [ ] Replace the XOR fold in `internal/zkprover/gnark.go` with a real
      encoding: each gradient as its own witness variable, hashed in-circuit.
- [ ] Make `Prove` consume `PublicInputs` and `Verify` check the proof against
      the **public inputs**, not trailing bytes. Define a versioned wire format
      (magic || version || public inputs || proof).
- [ ] Negative tests (`test/zksnark_circuit_verifier_test.go`):
      two distinct gradient vectors ⇒ distinct `update_hash`; a proof for one
      statement rejected against another; over-bound norm rejected; zero
      `dataset_commitment` rejected.
- [ ] Port the same four cases to `circuits/src/main.nr` (`nargo test`).

**Exit:** an honest update proves and verifies; a poisoned one is rejected;
the binding is collision-resistant by construction, not by assertion.

### M2 — Production wiring · ~1 week
- [ ] Populate `computeproof.Trace` from the real round/update producer
      (find the `GradientUpdate` construction site; today only tests set it).
- [ ] Thread `Trace` → circuit public inputs → `Aggregator.GradientProof` /
      `GradientCommitment`; keep the aggregator **fail-closed**.
- [ ] Put `MOHAWK_ALLOW_LEGACY_ATTESTATION` on a deprecation timeline and
      document it in `docs/ROADMAP.md:18`; default stays closed.
- [ ] Deprecate `genesisVK`/`VerifyProof` with a removal date; fix the stale
      `zksnark_verifier.go:117` cross-reference.
- [ ] Delete or implement `zkprover.MockProver` / `CLIProver` (no placeholders
      in the proof path).

**Exit:** every production round either carries a valid circuit proof or is
rejected; no caller can reach the legacy identity.

### M3 — Real performance evidence · ~1 week
- [ ] Add `test/zksnark_circuit_bench_test.go`: `Prove`, `Verify`, proof size,
      constraint count, for `N ∈ {8, 64, 256, 1024}`.
- [ ] New CI job (extend `performance-gate.yml` or add `zk-circuit-gate.yml`):
      run the benchmark, upload `results/zk/<date>-<sha>.json`, and **gate** on
      measured budgets (verify ≤ 15 ms; prove ≤ 30 s at `N=8`; scaling slope
      recorded). This is a real gate, not a baseline comparison of a sleep.
- [ ] **Remove the mock**: delete `time.sleep(0.0104)` from
      `sdk/python/tests/test_benchmarks.py` and either measure the real SDK
      `verify_proof` path or mark the test skipped with a pointer to the Go
      benchmark.
- [ ] Correct every figure listed in §0.2 to cite the artifact path, or drop
      the number. Specifically: `CHANGELOG.md:745,801`,
      `sdk/python/README.md:13,23,572`, `docs/HARDWARE_COMPATIBILITY.md:41`,
      `docs/DoD_Alignment_Addendum.md:151`, and the `zksnark_verifier.go:16`
      doc comment.
- [ ] Register the artifact under `captured_artifacts/` per
      `docs/ARTIFACT_GOVERNANCE.md`.

**Exit:** every zk number in the repo resolves to a committed artifact; the
performance gate fails on a real regression.

### M4 — Formal link + docs · ~1 week
- [ ] Extend `proofs/LeanFormalization/Theorem5Cryptography.lean` (the plan's
      `ZKSnarkVerification.lean` does not exist) with the per-update soundness
      statement: *if a proof verifies against public inputs
      `(h_before, h_after, ds, bound, ε, update_hash)`, then there exist
      gradients/noise satisfying the four constraints.* State explicitly that
      this is a statement about the **circuit relation**, not a Groth16/q-SDH
      soundness proof (row 5's Notes already disclaim the latter).
- [ ] Update `proofs/FORMAL_TRACEABILITY_MATRIX.md` row 5 and add a row for the
      new circuit + benchmark artifact.
- [ ] Fix `circuits/README.md` to match `main.nr` (drop `dp_delta`, the
      compression-fidelity claim, and the noise range-proof claim), or add the
      missing constraints.
- [ ] Update `GOLD_STANDARD_PLAN.md` §1 phase status (P1.1–P1.4) and §8.1.

**Exit:** the Lean model, the matrix, and the plan agree with the code.

### M5 — Decision record & cleanup · ~2 days
- [ ] Record the §1 backend decision and the trusted-setup disposition.
- [ ] Archive the unused circuit path (Noir stays as spec, or is deleted).
- [ ] Remove the stale `GOLD_STANDARD_PLAN.md` cross-references.

---

## 4. Sequencing

```
M1 (binding)  ──► M2 (wiring)  ──► M3 (evidence)  ──► M4 (formal+docs)  ──► M5
```

M3's doc corrections should land **before or with** M1's first PR: the current
tree advertises a number that the repo cannot reproduce, and that is the most
exposed defect. Suggested first PR: *"test: replace the mocked zk verification
benchmark with a real measurement + retract unbacked figures"*.

## 5. Risks

- **Trusted setup** is an in-process simulation; shipping Groth16 without a real
  ceremony is a security claim the repo cannot support. Either run a ceremony or
  label the key `development-only` in code and docs.
- **Proving time** at transformer scale will blow the epoch budget — scope to
  MLP/CNN first, as `GOLD_STANDARD_PLAN.md` §1 already concedes.
- **float64 → field encoding** must be documented and injective; the current XOR
  fold is neither.
- **Constraint cost** of a range check per gradient element dominates at large
  `N`; measure before committing to an arity.

## 6. Definition of done

1. A proof verifies **iff** the update satisfies the circuit relation, and a
   poisoned update is rejected — test-covered for each constraint.
2. `results/zk/*.json` exists, is committed, and is referenced by every zk
   performance claim in the repo.
3. `performance-gate.yml` (or its successor) fails on a real zk regression.
4. No zk number anywhere in the repo lacks an artifact pointer.
5. `genesisVK`/`VerifyProof` is removed, or carries a dated deprecation and is
   unreachable from production callers.
6. `Theorem5Cryptography.lean` + the traceability matrix state exactly what is
   proved about the circuit relation — and what is not.
