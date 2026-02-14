# Theorem 5: Cryptographic Verifiability (zk-SNARKs)

### Formal Statement
The Sovereign-Mohawk architecture provides cryptographic assurance of correct aggregation via zk-SNARKs, producing proofs of constant size (~200 bytes) with a verification time of $O(1) \approx 10\text{ms}$, independent of the $10^7$ participant scale.

### Proof Structure
1. **Computational Assumption:** Based on the q-Strong Diffie-Hellman (q-SDH) assumption in bilinear groups.
2. **Succinctness:** The Groth16 construction reduces the proof $\pi$ to:
   $$\pi = (A \in \mathbb{G}_1, B \in \mathbb{G}_2, C \in \mathbb{G}_1)$$
3. **Efficiency:** Verification requires only 3 pairing operations, which take approximately $3\text{ms}$ each on standard hardware.

### Impact
This allows the global aggregator to verify that regional nodes haven't tampered with model weights without needing to re-execute the training logic.
