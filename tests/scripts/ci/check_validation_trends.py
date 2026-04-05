#!/usr/bin/env python3
"""Validate recent full-validation history against basic trend SLOs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_history(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--history",
        default="test-results/full-validation/history.jsonl",
        help="Path to history jsonl.",
    )
    parser.add_argument(
        "--window",
        type=int,
        default=10,
        help="Number of most recent runs to evaluate.",
    )
    parser.add_argument(
        "--min-pass-rate",
        type=float,
        default=0.80,
        help="Minimum acceptable pass rate in the selected window.",
    )
    args = parser.parse_args()

    history = load_history(Path(args.history))
    if not history:
        print("No validation history found; run the suite at least once.")
        return 1

    window = history[-args.window :]
    total = len(window)
    passed = sum(1 for item in window if item.get("passed", False))
    pass_rate = passed / total

    latest = window[-1]
    latest_passed = bool(latest.get("passed", False))

    print(f"Window size: {total}")
    print(f"Passed: {passed}")
    print(f"Pass rate: {pass_rate:.2%}")
    print(f"Latest run passed: {latest_passed}")

    if not latest_passed:
        print("Trend check failed: latest full validation run did not pass.")
        return 1

    if pass_rate < args.min_pass_rate:
        print(
            "Trend check failed: pass rate "
            f"{pass_rate:.2%} below threshold {args.min_pass_rate:.2%}."
        )
        return 1

    print("Trend check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
