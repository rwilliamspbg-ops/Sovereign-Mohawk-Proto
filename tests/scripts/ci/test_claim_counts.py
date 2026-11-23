#!/usr/bin/env python3
"""Regression tests for the hand-written claim-count gate.

`scripts/ci/check_claim_counts.py` exists because the row count in README and
docs/EXTERNAL_AUDIT_SCOPE drifted twice (15 -> 27 -> 39) and the
standing-assumption count once (two -> four) with no gate noticing. These tests
pin the parser against the real documents and against a deliberately stale
marker, so the gate cannot silently stop checking.
"""

from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "scripts" / "ci" / "check_claim_counts.py"
README = REPO_ROOT / "README.md"
SCOPE = REPO_ROOT / "docs" / "EXTERNAL_AUDIT_SCOPE.md"


def load_module():
    spec = importlib.util.spec_from_file_location("check_claim_counts", SCRIPT)
    if spec is None or spec.loader is None:
        raise SystemExit(f"FAIL: could not load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    print(f"  ok: {message}")


def test_real_documents_agree_with_the_matrix() -> None:
    module = load_module()
    rows = module.matrix_row_count()
    check(rows > 0, f"matrix exposes {rows} numbered rows")
    for path in (README, SCOPE):
        got = module.markers(path).get("matrix-rows")
        check(got == rows, f"{path.name} matrix-rows marker is {rows}")


def test_assumption_name_sets_agree() -> None:
    module = load_module()
    readme_set = module.readme_assumptions()
    scope_set = module.scope_assumptions()
    check(readme_set == scope_set, f"assumption sets agree: {sorted(readme_set)}")
    check(len(readme_set) == 4, f"four standing assumptions, got {len(readme_set)}")


def test_gate_passes_on_the_current_tree() -> None:
    module = load_module()
    check(module.main() == 0, "gate exits 0 on the current tree")


def test_gate_fails_on_a_stale_row_count() -> None:
    """Negative control: a stale count must be caught, not waved through."""
    module = load_module()
    stale = module.matrix_row_count() + 1
    text = README.read_text(encoding="utf-8")
    perturbed = text.replace(
        "<!-- matrix-rows: %d -->" % module.matrix_row_count(),
        "<!-- matrix-rows: %d -->" % stale,
        1,
    )
    if perturbed == text:
        raise SystemExit("FAIL: could not perturb the README marker for the negative control")
    with tempfile.TemporaryDirectory() as tmp:
        fake = Path(tmp) / "README.md"
        fake.write_text(perturbed, encoding="utf-8")
        original = module.README
        module.README = fake
        try:
            rc = module.main()
        finally:
            module.README = original
    check(rc == 1, f"gate exits 1 on a stale row count ({stale})")


if __name__ == "__main__":
    test_real_documents_agree_with_the_matrix()
    test_assumption_name_sets_agree()
    test_gate_passes_on_the_current_tree()
    test_gate_fails_on_a_stale_row_count()
    print("claim-count gate tests passed")
