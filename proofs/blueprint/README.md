# Lean blueprint

This directory is an interactive [leanblueprint](https://pypi.org/project/leanblueprint/)
dependency graph linking LaTeX theorem statements to compiled Lean declarations.
It lives under `proofs/` because that is this monorepo's Lake project root.

## Files

- `src/content.tex` — mathematical content. Each `\lean{Full.Name}` tag is checked
  against the compiled `.olean` files; `\uses{label}` draws dependency edges and
  `\leanok` marks a node as proved.
- `lean_decls` — generated list of declaration names. Regenerate with
  `python3 scripts/ci/generate_blueprint_decls.py`.
- `src/plastex.cfg`, `src/web.tex`, `src/print.tex`, `src/macros/` — standard
  leanblueprint scaffolding, rendered from its templates with doc-gen4 URLs
  pointing at the published API docs.

## Local commands

From the repository root:

```bash
bash scripts/ci/build_blueprint.sh
```

This runs `lake exe checkdecls blueprint/lean_decls` from `proofs/` and then,
when a TeX installation is available, the plasTeX HTML build. Because the Lake
project is in a subdirectory while `leanblueprint` resolves paths from the Git
root, use the script rather than bare `leanblueprint web` here.

## CI and publication

`.github/workflows/blueprint.yml` is a **manual** (`workflow_dispatch`) deployment:
it verifies all `\lean{}` tags, builds the plasTeX web pages, and deploys them
to GitHub Pages. The `doc-gen4` dependency is pinned in the Lake workspace for
local API generation, but its full-dependency docs build OOMs on the default
7 GB GitHub runner, so published `\lean{}` links currently point at the Lean
sources. A larger runner would allow re-enabling `LeanFormalization:docs`. It is intentionally not
triggered by pushes because `static.yml` already owns the `pages` concurrency
group for the default site; a second automatic deployment would cancel or
overwrite it. Pages must be configured with **Source: GitHub Actions** in
repository settings.

The graph intentionally omits claims that are not machine-checked: an
unconditional group law for the concrete implementation, a general Float↔ℝ
Krum bridge, and Groth16/q-SDH knowledge soundness.

## Self-hosted doc runner

`.github/workflows/blueprint.yml` is a **manual** (`workflow_dispatch`) deployment:
it verifies all `\lean{}` tags, builds the plasTeX web pages on a hosted runner,
builds `doc-gen4` API pages on the `deskmini-docgen` self-hosted runner
(label `docgen`, ~11 GiB available), then deploys both to GitHub Pages.
`static.yml` is manual-only so it cannot overwrite this site. Pages must be
configured with **Source: GitHub Actions** in repository settings.

The Desk-Mini runner is started with `nohup ./run.sh &` from
`~/actions-runner-docgen`; it is not installed as a systemd service, so it
does not survive a reboot. Re-launch it before triggering the workflow.
