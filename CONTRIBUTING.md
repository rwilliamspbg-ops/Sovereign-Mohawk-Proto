# Contributing to Sovereign-Mohawk

Thank you for your interest in the Sovereign-Mohawk protocol. We are building the first formally verified decentralized intelligence pipeline capable of scaling to 10M nodes.

## Technical Priorities
We are currently seeking contributions in the following areas:
* **Cryptographic Optimization:** Enhancing the [Ed25519 Batching](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto) logic.
* **Formal Verification:** Extending the **Theorem 1 (BFT Safety)** proofs for continental-scale hubs.
* **Hardware Integration:** Improving the [internal/tpm](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/main/internal/tpm) capability-scoped interface for various TEEs.

## Development Process
1. **Fork & Branch:** Create a feature branch from `main`.
2. **Implement:** Ensure your code follows the [System Architecture](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto#%EF%B8%8F-system-architecture) guidelines.
3. **Formal Check:** If your PR affects core logic, please update the relevant [White Paper](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/WHITE_PAPER.md) sections.
4. **Pull Request:** Submit for review by the Technical Steering Committee.

## Licensing
By contributing, you agree that your contributions will be licensed under the **Apache License 2.0**.

By making a contribution to this project, you agree to the Developer Certificate of Origin (DCO) v1.1:
https://developercertificate.org/
