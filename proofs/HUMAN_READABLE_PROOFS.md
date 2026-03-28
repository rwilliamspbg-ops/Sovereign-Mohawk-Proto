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
