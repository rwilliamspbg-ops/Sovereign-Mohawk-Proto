#!/usr/bin/env python3
"""Prevent final GA tags when TPM closure evidence is incomplete."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

FINAL_TAG_PATTERN = re.compile(r"^v\d+\.\d+\.\d+$")


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _latest_matching(repo_root: Path, pattern: str) -> Path | None:
    matches = sorted((repo_root / "results" / "go-live" / "evidence").glob(pattern))
    if not matches:
        return None
    return matches[-1]


def _is_final_ga_tag(tag: str) -> bool:
    return bool(FINAL_TAG_PATTERN.match(tag))


def enforce(repo_root: Path, tag: str) -> tuple[bool, list[str]]:
    failures: list[str] = []

    if not _is_final_ga_tag(tag):
        return True, failures

    closure_path = _latest_matching(repo_root, "tpm_attestation_closure_validation_*.json")
    if closure_path is None:
        failures.append("missing TPM closure validation artifact")
    else:
        closure = _load_json(closure_path)
        if not bool(closure.get("ok", False)):
            failures.append(f"TPM closure validation not passing: {closure_path.name}")

    strict_gate_path = _latest_matching(repo_root, "go_live_gate_strict_*.json")
    if strict_gate_path is None:
        failures.append("missing strict go-live gate artifact")
    else:
        strict_gate = _load_json(strict_gate_path)
        if not bool(strict_gate.get("ok", False)):
            failures.append(f"strict go-live gate not passing: {strict_gate_path.name}")

    return len(failures) == 0, failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Enforce final GA tag safety based on closure evidence."
    )
    parser.add_argument("--tag", required=True, help="Tag name to validate (for example: v1.0.0)")
    parser.add_argument("--repo-root", default=".", help="Repository root path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()

    ok, failures = enforce(repo_root, args.tag.strip())
    if ok:
        print(f"tag={args.tag} status=PASS")
        if _is_final_ga_tag(args.tag):
            print("final GA tag safety checks passed")
        else:
            print("non-final tag detected; GA gate not required")
        return 0

    print(f"tag={args.tag} status=FAIL")
    for failure in failures:
        print(f"- {failure}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
