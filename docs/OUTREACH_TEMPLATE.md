# Outreach Template (zero-budget external audit)

Copy-paste and personalize. Keep it short; link the scope doc and issues.

## Lean Zulip (#mathlib / #new-members / relevant stream)

> Hi everyone — I'm looking for independent review of a growing Lean 4 formalization:
> Sovereign-Mohawk-Proto formalizes BFT federated learning + PQC + ZK circuits
> with refinement bridges to a Go runtime.
>
> Highest-value review targets:
> - Discrete-log reduction + Forking Lemma core (DiscreteLogReduction.lean)
> - Ed25519 UF-CMA model soundness
> - MiMC circuit ↔ Go verifier refinement (ZKCircuit.lean, MiMC.lean)
> - Convergence / straggler refinement bridges
>
> Audit scope (one-command check: `make audit-ready-check`):
> https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/docs/EXTERNAL_AUDIT_SCOPE.md
>
> Open review issues: https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues?q=label%3Aaudit-help-wanted
>
> Zero funding — happy to give clear acknowledgment, co-authorship on resulting
> notes, and high-visibility credit. Happy to scope a deliverable to your
> interests (e.g., discharge a specific axiom).

## Email to academics (5–10 researchers)

Subject: Independent review opportunity: Lean 4 formalization of BFT FL + PQC + ZK

Dear Dr. <name>,

I'm reaching out because your work on <Lean crypto / EasyCrypt / SSProve / ZK formalization / FL theory> is directly relevant to a formalization I've been building.

Sovereign-Mohawk-Proto is a theorem-guided federated-learning runtime. The Lean 4 part formalizes BFT convergence, RDP privacy accounting, Ed25519 UF-CMA (via a discrete-log reduction), and a MiMC circuit with refinement bridges to a Go runtime (including a multi-party trusted setup). CI is green; `make audit-ready-check` reproduces everything.

I'm looking for independent review on a zero budget. Concretely, I'd welcome:
- A scoped review of one component (e.g., the Forking Lemma core, or the MiMC circuit↔Go bridge), or
- A student project / master's thesis topic with clear deliverables.

In return: public credit in AUDITS.md + CHANGELOG, co-authorship on any resulting technical note, and a letter of recommendation / LinkedIn endorsement.

Audit scope: https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/docs/EXTERNAL_AUDIT_SCOPE.md

Would you be open to a short call or to pointing me at a student who might find this interesting?

Best,
<name>

## ZKProof / ZK Security Discord

> Looking for review of a MiMC circuit ↔ Go verifier refinement (Lean 4 + gnark).
> The circuit proves knowledge of a MiMC preimage of a public commitment; the
> verifier key comes from a multi-party trusted setup (MPC, N=3, beacon-sealed)
> simulated in-process. Scope doc + one-command check:
> https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/docs/EXTERNAL_AUDIT_SCOPE.md
> Issue: https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues/249
