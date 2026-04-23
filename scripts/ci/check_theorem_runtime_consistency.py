#!/usr/bin/env python3
"""Check that theorem-facing runtime formulas still match claimed proof models."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def load_claims(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Check theorem/runtime consistency")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument(
        "--claims",
        default="proofs/theorem_claims.json",
        help="Path to theorem claims metadata relative to repo root",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    claims_path = repo_root / args.claims
    payload = load_claims(claims_path)

    failures: list[str] = []
    checked_patterns = 0

    for claim in payload.get("claims", []):
        claim_id = claim["id"]
        for target in claim.get("runtime_targets", []):
            rel_path = target["path"]
            abs_path = repo_root / rel_path
            if not abs_path.exists():
                failures.append(f"{claim_id}: missing runtime target file {rel_path}")
                continue
            text = abs_path.read_text(encoding="utf-8")
            for pattern in target.get("patterns", []):
                checked_patterns += 1
                if re.search(pattern, text, flags=re.MULTILINE) is None:
                    failures.append(f"{claim_id}: pattern not found in {rel_path}: {pattern}")

    if failures:
        print("theorem/runtime consistency check failed")
        for item in failures:
            print(f"  - {item}")
        return 1

    print("theorem/runtime consistency check passed")
    print(f"  - claims file: {claims_path}")
    print(f"  - regex checks: {checked_patterns}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
