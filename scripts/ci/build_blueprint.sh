#!/usr/bin/env bash
# Build the Lean blueprint web pages and verify every \lean{} tag against
# compiled declarations. Mirrors `leanblueprint web` + `leanblueprint checkdecls`
# but works in this monorepo whose Lake project lives in proofs/.
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"
export PATH="$HOME/.elan/bin:$PATH"

python3 scripts/ci/generate_blueprint_decls.py

cd proofs
lake exe checkdecls blueprint/lean_decls
cd ..

# plasTeX (the engine behind leanblueprint web) needs a TeX installation for
# kpsewhich, even for the HTML build. Declaration checking above works without
# TeX, so skip only the HTML pass when the toolchain is absent.
if command -v kpsewhich >/dev/null 2>&1; then
  cd proofs/blueprint/src
  plastex -c plastex.cfg web.tex
  echo "[blueprint] web pages: proofs/blueprint/web"
else
  echo "[blueprint] kpsewhich not found: skipping HTML generation (declarations still checked)"
fi

echo "[blueprint] declarations checked: proofs/blueprint/lean_decls"
