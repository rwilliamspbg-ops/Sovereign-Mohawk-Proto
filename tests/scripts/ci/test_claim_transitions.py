#!/usr/bin/env python3
"""Regression tests for the claim Status-transition gate's matrix parser.

The gate (`scripts/ci/check_claim_transitions.py`) diffs every row's Status
column between `origin/main` and the working tree and requires a new
`proofs/CLAIM_TRANSITIONS.md` entry for each change. It is only a gate if it
actually sees the rows.

That was not true for matrix rows 2-34: row 2 has been wrapped across physical
lines since #366, and the parser read physical lines, so it stopped the main
table at its first wrapped row and silently saw only row 1 plus the Workstream
4 table. A Status change anywhere in rows 2-34 needed no transition entry.
These tests pin the parser against the real matrix and against synthetic
wrapped rows.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "scripts" / "ci" / "check_claim_transitions.py"
MATRIX = REPO_ROOT / "proofs" / "FORMAL_TRACEABILITY_MATRIX.md"


def load_module():
    spec = importlib.util.spec_from_file_location("check_claim_transitions", SCRIPT)
    if spec is None or spec.loader is None:
        raise SystemExit(f"FAIL: could not load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    print(f"  ok: {message}")


def test_real_matrix_parses_every_row() -> None:
    module = load_module()
    text = MATRIX.read_text(encoding="utf-8")
    statuses = module.parse_tables(text)

    main_rows = {k: v for k, v in statuses.items() if k.startswith("0:")}
    ws4_rows = {k: v for k, v in statuses.items() if k.startswith("1:")}

    check(len(main_rows) == 42, f"main table yields 42 rows (got {len(main_rows)})")
    check(
        sorted(int(k.split(":", 1)[1]) for k in main_rows) == list(range(1, 43)),
        "main table row ids are exactly 1..42",
    )
    check(
        sorted(ws4_rows) == ["1:Theorem7", "1:Theorem8"],
        f"Workstream 4 table yields Theorem7 and Theorem8 (got {sorted(ws4_rows)})",
    )
    # The two wrapped rows are the regression: both must carry a Status.
    for row_id in ("0:2", "0:18"):
        check(bool(main_rows.get(row_id)), f"wrapped row {row_id} has a parsed Status")


def test_wrapped_row_status_change_is_visible() -> None:
    module = load_module()
    base = (
        "| # | Claim | Status |\n"
        "|---|---|---|\n"
        "| 1 | first | old_status |\n"
        "| 2 | second, wrapped\n"
        "  across two physical lines | old_status |\n"
    )
    head = base.replace(
        "across two physical lines | old_status |",
        "across two physical lines | new_status |",
        1,
    )
    assert head != base

    base_statuses = module.parse_tables(base)
    head_statuses = module.parse_tables(head)

    check(base_statuses == {"0:1": "old_status", "0:2": "old_status"},
          "synthetic wrapped row is parsed with its Status")
    check(head_statuses.get("0:2") == "new_status",
          "a Status edit on a wrapped row is visible to the diff")


def test_adjacent_tables_are_not_merged() -> None:
    module = load_module()
    text = (
        "| # | Claim | Status |\n"
        "|---|---|---|\n"
        "| 1 | first | s1 |\n"
        "| Theorem ID | Formal Statement | Status |\n"
        "|---|---|---|\n"
        "| Theorem7 | stmt | s7 |\n"
    )
    statuses = module.parse_tables(text)
    check(
        statuses == {"0:1": "s1", "1:Theorem7": "s7"},
        f"adjacent tables keep their own indices (got {statuses})",
    )


def main() -> int:
    print("claim Status-transition parser regression tests")
    test_real_matrix_parses_every_row()
    test_wrapped_row_status_change_is_visible()
    test_adjacent_tables_are_not_merged()
    print("claim transition parser tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
