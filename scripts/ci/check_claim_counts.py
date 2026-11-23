#!/usr/bin/env python3
"""Pin the hand-written claim counts in README / EXTERNAL_AUDIT_SCOPE to the tree.

Both documents state how many traceability-matrix rows exist and how many
standing assumptions remain. Both numbers were written by hand and no gate
compared them to the tree, so both drifted silently: the row count went
15 -> 27 -> 39 while README and the scope doc still said 27 and 23, and the
standing-assumption count went two -> four while README still said two.

This script derives the row count from proofs/FORMAL_TRACEABILITY_MATRIX.md
and cross-checks the two documents' machine-readable markers and their
assumption-name sets. Markers are HTML comments, so they render invisibly:

    <!-- matrix-rows: N -->
    <!-- standing-assumptions: N -->
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MATRIX = ROOT / "proofs" / "FORMAL_TRACEABILITY_MATRIX.md"
README = ROOT / "README.md"
SCOPE = ROOT / "docs" / "EXTERNAL_AUDIT_SCOPE.md"

MARKER = re.compile(r"<!--\s*(matrix-rows|standing-assumptions):\s*(\d+)\s*-->")
ROW = re.compile(r"^\|\s*(\d+)\s*\|", re.MULTILINE)


def matrix_row_count() -> int:
    """Count the main traceability table's rows (the Workstream 4 table has no
    leading row-number column, so it is not matched)."""
    return len(ROW.findall(MATRIX.read_text(encoding="utf-8")))


def markers(path: Path) -> dict[str, int]:
    return {m.group(1): int(m.group(2)) for m in MARKER.finditer(path.read_text(encoding="utf-8"))}


def _head(name: str) -> str:
    """`Ed25519GroupLaws affineBase` and `Ed25519GroupLaws` name the same
    assumption; compare the leading identifier so prose arguments do not matter."""
    m = re.match(r"[A-Za-z_][A-Za-z0-9_']*", name)
    return m.group(0) if m else name


def readme_assumptions() -> set[str]:
    text = README.read_text(encoding="utf-8")
    start = text.index("**Four** assumptions")
    end = text.index('"Axiom-free" is therefore')
    return {_head(n) for n in re.findall(r"^- `([^`]+)`", text[start:end], flags=re.MULTILINE)}


def scope_assumptions() -> set[str]:
    text = SCOPE.read_text(encoding="utf-8")
    m = re.search(
        r"So the full set of standing assumptions is (.+?)\. None is an", text, flags=re.DOTALL
    )
    if m is None:
        raise SystemExit("check_claim_counts: could not find the scope doc's assumption sentence")
    return {_head(n) for n in re.findall(r"`([^`]+)`", m.group(1))}


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return path.name


def main() -> int:
    failures: list[str] = []
    actual_rows = matrix_row_count()

    for path in (README, SCOPE):
        got = markers(path).get("matrix-rows")
        if got != actual_rows:
            failures.append(
                f"{_rel(path)}: matrix-rows marker is {got}, " f"matrix has {actual_rows} rows"
            )

    readme_m = markers(README)
    scope_m = markers(SCOPE)
    if readme_m.get("standing-assumptions") != scope_m.get("standing-assumptions"):
        failures.append(
            "standing-assumptions marker disagrees: "
            f"README={readme_m.get('standing-assumptions')} "
            f"scope={scope_m.get('standing-assumptions')}"
        )

    readme_set = readme_assumptions()
    scope_set = scope_assumptions()
    if readme_set != scope_set:
        failures.append(
            "assumption name sets disagree: "
            f"README-only={sorted(readme_set - scope_set)} "
            f"scope-only={sorted(scope_set - readme_set)}"
        )

    if failures:
        print("claim count check FAILED", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print(
        f"claim count check passed: {actual_rows} matrix rows; "
        f"{len(readme_set)} standing assumptions"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
