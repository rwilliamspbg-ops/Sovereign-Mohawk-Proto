#!/usr/bin/env python3
"""Generate a shields.io endpoint badge JSON for total Go coverage.

Reads a `go tool cover -func` summary (the same file `go-test.yml` already
produces at test-results/go-coverage-summary.txt) and writes a shields.io
endpoint payload. Intended to be run from CI; kept as a standalone script so it
can be exercised locally without a full Actions run.

Usage:
    python3 scripts/generate_coverage_badge.py \
        --summary test-results/go-coverage-summary.txt \
        --out badges/go_coverage_badge.json

Exit codes:
    0  badge written
    1  usage error
    2  summary missing or unreadable
    3  no coverage total found in the summary
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# `go tool cover -func` ends with:
#   total:                       (statements)   68.6%
TOTAL_RE = re.compile(r"\(\s*statements\s*\)\s*(\d+(?:\.\d+)?)%")

# Coverage thresholds. Chosen to be strict about the high end: this repo's
# formal-verification story is a core claim, so a silent slide below 60% should
# be visible on the README rather than buried in an artifact.
COLOR_GOOD = "#2ea043"
COLOR_WARN = "#d29922"
COLOR_LOW = "#d73a49"


def parse_total(summary_text: str) -> float:
    """Extract the total coverage percentage from a `go tool cover -func` summary.

    Raises ValueError if no total line is present.
    """
    # The total is always the last matching line.
    matches = TOTAL_RE.findall(summary_text)
    if not matches:
        raise ValueError("no '(statements) N%' total line found")
    return float(matches[-1])


def color_for(pct: float) -> str:
    if pct >= 65.0:
        return COLOR_GOOD
    if pct >= 60.0:
        return COLOR_WARN
    return COLOR_LOW


def build_payload(pct: float) -> dict:
    return {
        "schemaVersion": 1,
        "label": "Go Coverage",
        "message": f"{pct:.1f}%",
        "color": color_for(pct),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--summary",
        default="test-results/go-coverage-summary.txt",
        help="path to a `go tool cover -func` summary",
    )
    parser.add_argument(
        "--out",
        default="badges/go_coverage_badge.json",
        help="path to write the shields.io endpoint JSON",
    )
    args = parser.parse_args(argv)

    summary = Path(args.summary)
    if not summary.is_file():
        print(f"error: summary not found: {summary}", file=sys.stderr)
        return 2

    try:
        text = summary.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"error: could not read {summary}: {exc}", file=sys.stderr)
        return 2

    try:
        pct = parse_total(text)
    except ValueError as exc:
        print(f"error: {exc} in {summary}", file=sys.stderr)
        return 3

    payload = build_payload(pct)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(f"coverage: {pct:.1f}% -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
