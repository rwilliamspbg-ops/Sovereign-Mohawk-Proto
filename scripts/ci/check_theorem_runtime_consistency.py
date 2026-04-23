#!/usr/bin/env python3
"""
Check theorem/runtime consistency by comparing documented formulas in proofs
with the corresponding implementations in the codebase.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


def load_theorem_claims(path: Path) -> dict:
    """Load theorem claims metadata."""
    if not path.exists():
        return {"claims": []}
    with open(path) as f:
        return json.load(f)


def check_runtime_patterns(repo_root: Path, claim: dict) -> list[str]:
    """Check that runtime files contain expected patterns."""
    findings = []
    runtime_targets = claim.get("runtime_targets", [])

    for target in runtime_targets:
        file_path = repo_root / target.get("path", "")
        if not file_path.exists():
            findings.append(f"Runtime target not found: {file_path}")
            continue

        content = file_path.read_text()
        patterns = target.get("patterns", [])

        for pattern_str in patterns:
            # Convert pattern from escaped form to actual regex
            pattern = re.compile(pattern_str, re.MULTILINE | re.IGNORECASE)
            if not pattern.search(content):
                findings.append(f"Pattern not found in {file_path}:\n" f"  Pattern: {pattern_str}")

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check theorem/runtime consistency")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    claims_file = repo_root / "proofs" / "theorem_claims.json"

    theorem_claims = load_theorem_claims(claims_file)
    claims = theorem_claims.get("claims", [])

    all_findings: list[str] = []
    for claim in claims:
        claim_id = claim.get("id", "<unknown>")
        findings = check_runtime_patterns(repo_root, claim)

        if findings:
            print(f"\n❌ Claim {claim_id} has runtime consistency issues:")
            for finding in findings:
                print(f"   {finding}")
                all_findings.append(finding)

    if not all_findings:
        print("✅ Theorem/runtime consistency check passed")
        print(f"   Checked {len(claims)} claims with runtime targets")
        return 0

    print(f"\n❌ Found {len(all_findings)} consistency issue(s)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
