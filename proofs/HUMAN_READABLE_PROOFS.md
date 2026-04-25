# Human-Readable Proofs Guide

This guide translates low-level verification results into language that operators and policy stakeholders can use quickly.

## Why this exists

zk-SNARK and hybrid SNARK/STARK verifiers return machine-oriented payloads that are hard to interpret under incident pressure. Human-readable reports provide:

- A plain verdict (verified/rejected)
- An explicit trust-level hint
- A concise explanation of mode, scheme, backend, and timing
- A clear recommended next action

## Script

Use [scripts/render_human_readable_proof.py](../scripts/render_human_readable_proof.py).

Input: JSON output from `verify_proof(...)` or `verify_hybrid_proof(...)`.

```bash
python scripts/render_human_readable_proof.py \
  --input results/metrics/sample_verify_result.json \
  --output results/metrics/sample_verify_human.json
```

Example input:

```json
{
  "success": true,
  "message": "hybrid verification complete",
  "verification_time_ms": 8.71,
  "data": {
    "mode": "both",
    "selected_scheme": "hybrid",
    "stark_backend": "simulated_fri"
  }
}
```

Example output section:

```json
{
  "human_readable": {
    "verdict": "Verified",
    "trust_level": "high",
    "plain_language_summary": "Verdict: Verified; Proof mode: both; Verification scheme: hybrid; STARK backend: simulated_fri; Verification time: 8.710 ms; Runtime message: hybrid verification complete",
    "next_action": "Accept this update for aggregation and settlement."
  }
}
```

## Recommended operator workflow

1. Record the raw verifier response artifact.
2. Render it through the human-readable script.
3. Attach both artifacts to incident or governance reports.
4. Use the plain summary in stakeholder communication, not the raw payload.

## Human-Readable Theorem Summaries (PQC Migration)

### Theorem 7: PQC Migration Continuity

- Plain-language claim: After cutover, a migration is accepted only when legacy and PQC signatures are both present.
- Security meaning: A later compromise of the legacy key does not remove the requirement for a valid PQC signature.
- Runtime linkage: `internal/token/migration_signatures.go` and migration epoch checks in `internal/token/ledger.go`.

### Theorem 8: Dual-Signature Non-Hijack

- Plain-language claim: If the PQC signature is missing, the post-cutover non-hijack safety property does not hold.
- Security meaning: Legacy-only authorization cannot satisfy the post-epoch migration acceptance policy.
- Runtime linkage: settlement and payout enforcement in `internal/token/settlement.go` plus migration controls in `internal/token/ledger.go`.

## Phase 3 Summary (Adversary Game + Refinement)

Theorem 7 and Theorem 8 now model legacy and PQC signatures as abstract schemes with forgeability predicates and include an adversary-game skeleton for existential unforgeability. The model assumes legacy signatures can become forgeable after quantum capability while PQC signatures remain unforgeable under the configured assumptions. Under the enforced dual-signature policy, post-epoch migration acceptance remains continuous and hijack-resistant.

This phase also introduces Lean refinement placeholders to map formal acceptance/safety claims toward runtime behavior in `internal/token/migration_signatures.go` and `internal/token/settlement.go`, including compute-proof-gated settlement paths.
