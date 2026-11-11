#!/usr/bin/env python3
"""Reject unsafe formal proof placeholders (`admit`, undeclared `axiom`s).

`admit` is never acceptable in this repo's Lean formalization -- it always
fails. `sorry` is allowed (tracked, not blocked -- an honest marker for
in-progress proofs, per the existing convention this check preserves).

`axiom` is banned by default too, for the same reason: a vacuous, unproven
"trust me" is exactly what this repo's formal-verification effort exists to
prevent from hiding behind a passing build. Rather than a blanket ban or an
easily-slapped-on marker comment, any axiom must be explicitly named in
ALLOWED_AXIOMS below, keyed to the exact file it's expected in -- adding a
new axiom means a visible, reviewable change to this allowlist, not a
silent pass.

That allowlist is currently empty. The two assumptions this development
still carries are deliberately **not** axioms, so they do not appear here:

  * the IEEE-754 `Float` order laws -- Lean's `Float` carries no order laws
    (`#print floatSpec` shows an opaque constant asserting nothing) and
    Mathlib defines no order instance for it, so the laws are packaged as
    the `FloatOrderLaws` structure in `proofs/Refinement/MultiKrum.lean`
    and passed explicitly to the theorems that need them;
  * the primality of the 253-bit Ed25519 subgroup order `L` -- a standard
    number-theoretic fact that is out of scope to re-derive in Lean, carried
    as the explicit `Fact (Nat.Prime dlL)` hypothesis on the four
    declarations in `proofs/LeanFormalization/DiscreteLogReduction.lean`
    that need it.

Consolidates what were previously two independently-drifting inline `grep`
checks (`.github/workflows/verify-proofs.yml`'s `verify-lean-formalization`
job and `.github/workflows/verify-formal-proofs.yml`'s
`verify-lean-formalizations` job) into one shared, single-source-of-truth
script both now call.
"""

from __future__ import annotations

import re
from pathlib import Path

# (relative path from proofs/, axiom name) -> why it's allowed. The reason is
# documentation for reviewers, not machine-checked, but every entry must be
# real and specific -- "needed for a proof" is not a reason.
#
# The allowlist is currently EMPTY: the Lean development has no `axiom`
# declarations at all. The two remaining assumptions are not axioms --
#   * the IEEE-754 `Float` order laws are the `FloatOrderLaws` structure in
#     proofs/Refinement/MultiKrum.lean, passed explicitly to each theorem;
#   * the primality of the Ed25519 subgroup order L is the explicit
#     `Fact (Nat.Prime dlL)` hypothesis on the four declarations in
#     proofs/LeanFormalization/DiscreteLogReduction.lean that need it.
ALLOWED_AXIOMS: dict[tuple[str, str], str] = {}

SCAN_DIRS = ["LeanFormalization", "Specification", "Refinement"]
ADMIT_RE = re.compile(r"\badmit\b")
# Only matches an actual top-level declaration ('axiom name ...' at the start
# of a line, Lean's own style for every axiom in this repo) -- deliberately
# NOT a bare `\baxiom\b` word search, which false-positives on the word
# "axiom" appearing in ordinary English prose inside doc comments (this
# file's own doc comments discuss axioms at length).
AXIOM_DECL_RE = re.compile(r"^\s*axiom\s+(\w+)")


def iter_lean_files(proofs_root: Path):
    for d in SCAN_DIRS:
        yield from sorted((proofs_root / d).rglob("*.lean"))
    yield from sorted(proofs_root.glob("*.lean"))


def strip_comments(text: str) -> list[str]:
    """Return each line with comment content blanked out (block comments
    `/- ... -/`, nesting-aware, and `--` line comments), preserving line
    count/numbering so reported line numbers stay accurate. Necessary
    because this repo's doc comments discuss `axiom`/`sorry`/`admit` at
    length in ordinary English prose -- a line-wrapped sentence can
    innocently start with one of those words, which a comment-blind regex
    would misread as a real declaration/usage."""
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    for line in lines:
        buf: list[str] = []
        i, n = 0, len(line)
        while i < n:
            if depth > 0:
                if line[i : i + 2] == "-/":
                    depth -= 1
                    i += 2
                elif line[i : i + 2] == "/-":
                    depth += 1
                    i += 2
                else:
                    i += 1
                continue
            if line[i : i + 2] == "/-":
                depth += 1
                i += 2
                continue
            if line[i : i + 2] == "--":
                break
            buf.append(line[i])
            i += 1
        out.append("".join(buf))
    return out


def main() -> int:
    proofs_root = Path("proofs") if Path("proofs").is_dir() else Path(".")
    violations: list[str] = []
    sorry_count = 0

    for path in iter_lean_files(proofs_root):
        rel = path.relative_to(proofs_root).as_posix()
        text = path.read_text(encoding="utf-8")
        raw_lines = text.splitlines()
        code_lines = strip_comments(text)
        for lineno, (raw, code) in enumerate(zip(raw_lines, code_lines), start=1):
            if ADMIT_RE.search(code):
                violations.append(f"{rel}:{lineno}: `admit` is never allowed: {raw.strip()}")
            if re.search(r"\bsorry\b", code):
                sorry_count += 1
            m = AXIOM_DECL_RE.match(code)
            if m:
                name = m.group(1)
                key = (rel, name)
                if key not in ALLOWED_AXIOMS:
                    violations.append(
                        f"{rel}:{lineno}: axiom `{name}` is not in ALLOWED_AXIOMS "
                        f"(scripts/ci/check_no_unsafe_placeholders.py) -- add it there with a "
                        f"real justification, or don't introduce it."
                    )

    print(f"info: sorry placeholders detected: {sorry_count} (allowed, tracked only)")

    if violations:
        print("Unsafe formal proof placeholder(s) found:")
        for v in violations:
            print(f"  - {v}")
        return 1

    print(
        f"Placeholder scan passed: no `admit`, no un-allowlisted `axiom` ({len(ALLOWED_AXIOMS)} allowlisted)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
