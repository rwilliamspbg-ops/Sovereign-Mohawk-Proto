# Theorem 5: Cryptographic Verifiability (zk-SNARKs)

### Formal Statement
The current Lean module machine-checks an abstract verifier-cost model in which:

- proof size is represented as a constant,
- verifier work is represented as a constant number of operations, and
- the resulting runtime proxy is scale-invariant with respect to participant count.

This supports the engineering claim that the verifier model is constant-cost, but it is not yet a full formalization of Groth16 succinctness, soundness, or q-SDH-based security.

### Proof Structure
1. **Computational Assumption:** Based on the q-Strong Diffie-Hellman (q-SDH) assumption in bilinear groups.
2. **Succinctness:** The Groth16 construction reduces the proof $\pi$ to:
   $$\pi = (A \in \mathbb{G}_1, B \in \mathbb{G}_2, C \in \mathbb{G}_1)$$
3. **Efficiency:** The abstract Lean model fixes verifier work at a constant three operations (`theorem5_verifyops_constant`), a bookkeeping count, not a latency measurement. For the compiled 9,569-constraint `WeightUpdateCircuit`, measured mean verification is **0.675 ms** (200 iterations) and proving **38 ms** (20 iterations), with a ~41 s one-time in-process simulated 3-party MPC setup (`results/zk/weight-proof-latest.json`).

### Impact
In principle, a properly circuit-bound Groth16 deployment lets the global aggregator verify that regional nodes haven't tampered with model weights without re-executing training logic. **That path is now the production weight-update flow:** `zkprover.ProduceWeightProof` (`internal/zkprover/produce.go`) verifies each framed proof against the statement embedded in it before returning, and `batch.Aggregator.ProcessRound` re-verifies it, so the proof is bound to the `WeightUpdateCircuit` statement rather than to a fixed key. The fixed `genesisVK` in `internal/zksnark_verifier.go` is a deprecated commitment-less fallback (removal scheduled 2027-01-15), not the production weight-update key; it binds no model-weight content. Groth16 knowledge soundness for the compiled R1CS remains an external assumption, and the setup is not a production ceremony.
