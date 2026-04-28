# Contributing to Lean Proofs

This playbook explains how to add or extend Lean theorems in the Sovereign-Mohawk proof tree without breaking the traceability matrix or the runtime validation story.

## 1. Start From The Claim

Write the claim in plain language first, then convert it into a Lean signature.

Template:

```lean
/-- Short claim statement. -/
theorem my_new_claim (params : Type) :
    target_statement := by
  sorry
```

Keep the statement narrow. If the claim needs a stronger hypothesis, write that hypothesis explicitly rather than hiding it inside a helper theorem.

## 2. Use Common Tactic Patterns

Most files in this repository rely on a small set of tactics:

- `simp` for list, sum, and structure normalization
- `norm_num` for concrete finite checks
- `omega` for integer inequalities
- `linarith` for linear real or rational bounds
- `rfl` when the proof is definitional

Prefer the simplest tactic that discharges the goal. If a proof becomes hard to read, split it into small lemmas instead of stacking a long tactic script.

## 3. Build Locally

Run the Lean build from the proof root before opening a PR:

```bash
cd proofs
lake build
```

If the repository is checking a specific theorem family, build the smallest module first and then the full tree.

## 4. Update Traceability

Every new theorem should be linked to the traceability matrix and to at least one runtime or validation artifact.

When you add a theorem:

1. Add the theorem row to `proofs/FORMAL_TRACEABILITY_MATRIX.md`.
2. Add or update the runtime test that exercises the claim.
3. Keep the theorem name and test name aligned so the matrix stays searchable.

## 5. Connect Runtime Evidence

If the theorem corresponds to a production guard, expose the matching runtime observation in Go and make sure the metric name mirrors the claim.

Good examples in this repository include BFT resilience, RDP composition, communication cost, liveness success probability, and proof-verification latency.

## 6. Example Workflow

For a new convergence lemma:

1. State the lemma over a concrete envelope or bound.
2. Prove the algebraic reduction with `simp`, `norm_num`, or `linarith`.
3. Add the theorem to the matrix.
4. Add the matching runtime test in `test/`.
5. Run `lake build` and the relevant test target.

## 7. Review Checklist

- The theorem is free of placeholders.
- The proof is reproducible with `lake build`.
- The traceability matrix references the theorem and its runtime test.
- The surrounding file has a short strategy docstring if it is part of the main theorem family.

If you are unsure where a theorem belongs, follow the existing file layout in `proofs/LeanFormalization/` and mirror the nearest established pattern.
