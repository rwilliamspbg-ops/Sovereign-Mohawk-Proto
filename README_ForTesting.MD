# 🧪 Testing & Evaluation: Sovereign Mohawk Protocol

## 1. Automated Test Suite
Run the local validation script before pushing to ensure CI compliance:
```bash
./test_all.sh

2. CI/CD Proof-Linking RequirementsThe Proof-Driven Design Verification workflow requires every core logic file to contain a @proof tag pointing to the relevant mathematical theorem in the /proofs/ directory. Failure to include these links will result in a build error.3. Performance Benchmarks (2026 Standard)MetricRequirementLinkZK-Latency< 10msProof: Theorem 5Resilience55.5% BFTProof: Theorem 1ComplexityO(d log n)Proof: Theorem 2
