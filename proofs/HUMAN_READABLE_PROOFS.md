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

## Phase 4 Summary (UF-CMA + Ledger Transitions)

Theorem 7 and Theorem 8 now include a full UF-CMA-style adversary game model: the attacker can query a signing oracle on chosen messages and only wins by producing a valid forgery on a fresh, previously unqueried message. This captures the core post-quantum migration claim that legacy compromise does not bypass the required PQC authorization in post-epoch acceptance.

The model also introduces explicit ledger transition rules across `preEpoch`, `cutover`, and `postEpoch`, plus invariant lemmas that preserve dual-signature safety under modeled transitions. Refinement lemmas are closed and document alignment toward `internal/token/migration_signatures.go` and `internal/token/settlement.go`, including compute-proof-gated payout logic.

### Workstream 4 Linkage (Upgrade Plan 2026-2027)

- Scope: Workstream 4 - PQC Migration Hardening.
- Theorem 7 refinement: `goVerifyMigrationSignatureBundle` and `goPostEpochAccept` document the Lean-level contract corresponding to `verifyMigrationSignatureBundle` and post-epoch acceptance checks.
- Theorem 8 refinement: `goSettleTaskPayoutSafe` captures the `SettleTaskPayout` proof-valid gate and maps it to the Lean non-hijack predicate (`hijackSafe`).
- Operational meaning: a valid compute proof plus mandatory dual signatures keeps payout settlement aligned with post-cutover non-hijack policy.
