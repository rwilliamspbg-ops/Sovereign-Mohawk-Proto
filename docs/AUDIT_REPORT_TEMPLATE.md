# External Audit Report — Template

Copy this file to `results/audits/<date>-<short-name>.md`, fill it in, and open a PR
(or email the maintainer). Reports can be short: **one well-evidenced finding is
more useful than a long confirmation.**

---

# Audit report: <title>

- **Reviewer:** <name / handle / anonymous>
- **Date:**
- **Commit reviewed:** `<full sha>`
- **Scope:** <e.g. "traceability rows 5 and 22", "Section 3 targets", "whole development">
- **Time spent:**

## 1. Verdict

- [ ] **Claims confirmed under stated scope** — list which ones.
- [ ] **Gaps found** — list them in §2.
- [ ] **Claims overstated** — list them in §2, quoting the claim and the
      artifact it should have cited.

## 2. Findings

For each finding, one block. Be specific: quote the file, the declaration, the
claim, and the evidence that contradicts it.

### F1 — <short title>

- **Claim under review:** <quote + link>
- **Where stated:** <file:line, paper section, README, …>
- **What I found:** <the discrepancy>
- **Evidence:** <command output, counterexample, reference>
- **Severity:** blocking / material / cosmetic
- **Suggested fix:**

## 3. Checks performed

- `cd proofs && lake build` — <pass/fail>
- `#print axioms` spot-checks — <which declarations, what they reported>
- `grep -rn "sorry\|admit\|^axiom " --include=*.lean proofs/`
- refinement bridges checked by hand — <rows>
- runtime tests — <which, result>

## 4. Claims I could NOT verify

State what you did not check, so the next reviewer knows where to look.

## 5. Notes for the maintainer

Anything that would make the next review cheaper: better docs, missing pinned
vectors, confusing naming, stale comments.

---

Maintainer: add a row to [`AUDITS.md`](../AUDITS.md) once the report is received,
and link the follow-up PR in the Notes column.
