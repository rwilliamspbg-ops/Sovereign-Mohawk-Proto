# Recruiting an External Reviewer

Status: **open**. See [`AUDITS.md`](../AUDITS.md) for the credit policy and the
reviewer log (currently empty).

## Why this is worth a reviewer's time

- The central result is a **machine-checked negative result** — a concrete Lean 4
  counterexample showing that per-tier Multi-Krum guards do not compose — plus a
  probabilistic repair. A clean negative result with a repair is more interesting
  to review than another "we verified our system" submission.
- The development is **axiom-free and sorry-free**, with exactly one documented
  `native_decide` toolchain trust. The audit surface is small and well-labelled.
- The scope is **explicitly bounded**: `proofs/FORMAL_TRACEABILITY_MATRIX.md`
  records per-claim status, including the rows that are surrogates or empirical
  rather than fully formalized.

## Ask

One of:

1. **A 30-minute review** following `docs/EXTERNAL_AUDIT_SCOPE.md` §1.1. Cheapest
   useful contribution; most likely to find something.
2. **A focused review** of §3's four targets (discrete-log reduction, Ed25519
   UF-CMA model, the ZK circuit refinement, the convergence bridges).
3. **A full audit** producing the public report that is the deliverable of
   `docs/MAJOR_WIN_PLAN.md` W1.

## Where to start

| Step | Link |
| --- | --- |
| Read first | [`docs/EXTERNAL_AUDIT_SCOPE.md`](EXTERNAL_AUDIT_SCOPE.md) §2, then §1.1 |
| Highest priority | [`docs/EXTERNAL_AUDIT_SCOPE.md`](EXTERNAL_AUDIT_SCOPE.md) §3 |
| Per-claim status | [`proofs/FORMAL_TRACEABILITY_MATRIX.md`](../proofs/FORMAL_TRACEABILITY_MATRIX.md) |
| Report template | [`docs/AUDIT_REPORT_TEMPLATE.md`](AUDIT_REPORT_TEMPLATE.md) |
| Open an issue | use the **External audit / review request** template |

## Outreach message (copy-paste)

> **Seeking an external reviewer for a machine-checked federated-learning
> security proof (Lean 4 + Go).**
>
> The project proves, in Lean 4, that hierarchical per-tier Byzantine guards do
> *not* compose — with an explicit counterexample — and then proves a
> probabilistic repair under an i.i.d. committee-sampling model. The development
> is axiom-free and sorry-free (one documented `native_decide` toolchain trust).
>
> I am looking for a 30-minute to 2-day review. Start here:
> `docs/EXTERNAL_AUDIT_SCOPE.md` §1.1 ("Review in under 30 minutes").
> Repo: https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto
>
> Credit: every review is acknowledged in `AUDITS.md`; substantive contributions
> (new theorem, discharged axiom, found vulnerability) earn co-authorship on the
> resulting technical note or paper.

## Suggested venues / channels

- Lean Zulip (`#mathlib > formalization` / `#general`), the Lean discourse.
- Researchers working on Byzantine-robust aggregation or formalized
  differential privacy.
- The repository's own `audit-help-wanted` label on GitHub.
