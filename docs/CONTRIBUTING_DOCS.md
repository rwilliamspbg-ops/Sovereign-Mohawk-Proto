# Contributing to Documentation

**Status**: Real content as of 2026-11-05.

## Rules

1. Never invent features, numbers, theorems, or deployment paths not present
   in code/scripts/Helm/Compose/Lean/evidence.
2. Prefer under-claiming; mark scope limits, surrogates, and open items
   explicitly (follow `GETTING_STARTED.md`, `ROADMAP.md`,
   `PHASE_4_PRODUCTION_DEPLOYMENT.md`).
3. Every procedure/metric/architecture statement must point to a real file
   path, make target, script, workflow, or evidence artifact.
4. Do not delete history; move superseded content to `docs/archive/YYYY-MM-*/`.
5. Keep the formal-verification honesty bar: link to
   `proofs/FORMAL_TRACEABILITY_MATRIX.md`; never imply full hierarchical BFT
   or full Groth16 soundness where only surrogates/models exist.
6. All Markdown must be GitHub-flavored, use relative links, Mermaid where
   helpful, and pass `python3 scripts/ci/check_markdown_links.py`.
7. Run the link checker after every batch.
8. Do not mix formal-proof changes with pure documentation changes.

## Skeleton for new docs

```
# Title
> Status: real content as of YYYY-MM-DD · verified against commit <short-sha>

## Purpose / Audience
## Prerequisites
## Core content (with code/script/proof links)
## What is real vs still open
## Related documents
## Last verified
```

## Make targets

- `make audit-ready-check` — lake build + refinement + consistency.
- `make docs-check` — fails if scaffold string remains (see Makefile).
- `python3 scripts/ci/check_markdown_links.py` — link check.

## Review

Open a PR titled `docs: ...`. CI runs the link checker. For substantive
claims, cite the source file/commit.
