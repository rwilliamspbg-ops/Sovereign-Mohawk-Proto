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
3. **Efficiency:** Verification requires only 3 pairing operations, which take approximately $3\text{ms}$ each on standard hardware.

### Impact
This allows the global aggregator to verify that regional nodes haven't tampered with model weights without needing to re-execute the training logic.
