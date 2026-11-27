#!/usr/bin/env python3
r"""Regenerate proofs/blueprint/lean_decls from the \lean{...} tags.

Kept separate from plasTeX so `lake exe checkdecls` can run without a TeX
installation; the web/PDF build regenerates the same list via the leanblueprint
plugin.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "proofs" / "blueprint" / "src" / "content.tex"
OUT = ROOT / "proofs" / "blueprint" / "lean_decls"

text = SRC.read_text(encoding="utf-8")
body = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("%"))
names = re.findall(r"\\lean\{([^}]+)\}", body)
if not names:
    raise SystemExit("no \\lean{...} tags found in blueprint content")
OUT.write_text("\n".join(names) + "\n", encoding="utf-8", newline="\n")
print(f"wrote {len(names)} declarations to {OUT}")
