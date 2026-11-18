---
name: External audit / review request
description: Volunteer a review of the formal development or the Go runtime, or report findings from one.
labels: ["audit-help-wanted", "help wanted"]
title: "Audit: <scope> — <one-line summary>"
---

Thank you for reviewing this project. Everything you need is in
[`docs/EXTERNAL_AUDIT_SCOPE.md`](../docs/EXTERNAL_AUDIT_SCOPE.md) — start with
**§1.1 "Review in under 30 minutes"**.

## What would be most useful

- A **finding**: a claim that does not hold under its stated hypotheses, a
  refinement bridge where the Lean spec and the Go predicate disagree, a
  vacuous theorem, or an axiom/surrogate that is presented as stronger than it is.
- A **confirmation**: an explicit statement that a specific claim *does* hold
  under its stated scope. Negative results are genuinely valuable to us — the
  composition counterexample in Theorem 1 came from exactly this kind of review.

## Before you start

- [ ] I have read `docs/EXTERNAL_AUDIT_SCOPE.md` §2 (trusted base vs. proofs) —
      please do not audit Mathlib, gnark or the Go standard library.
- [ ] I have run `cd proofs && lake build` successfully.
- [ ] I have checked `proofs/FORMAL_TRACEABILITY_MATRIX.md` for the current status
      of the claim I am reviewing.

## Report

Use [`docs/AUDIT_REPORT_TEMPLATE.md`](../docs/AUDIT_REPORT_TEMPLATE.md). Reports may
be short; a single well-evidenced finding is enough.

## Credit

Every review is credited in [`AUDITS.md`](../AUDITS.md) and `CHANGELOG.md`.
Substantive reviews (new theorem, discharged axiom, found vulnerability) earn
co-authorship on the resulting technical note or paper.

/maintainer
