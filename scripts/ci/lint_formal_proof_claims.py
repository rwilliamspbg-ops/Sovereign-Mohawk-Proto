#!/usr/bin/env python3
"""Lint proof-facing artifacts for vacuous proof shapes and overclaiming language."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


VacuousLeanPatterns = [
    (
        "theorem_true",
        re.compile(r"^\s*theorem\s+([A-Za-z0-9_']+)\s*:\s*True\s*:=", re.MULTILINE),
        "theorem concludes `True`",
    ),
    (
        "prop_true_def",
        re.compile(r"^\s*def\s+([A-Za-z0-9_']+)\s*\([^)]*\)\s*:\s*Prop\s*:=\s*True\b", re.MULTILINE),
        "Prop definition reduces directly to `True`",
    ),
]

SelfEqualityPattern = re.compile(
    r"^\s*theorem\s+([A-Za-z0-9_']+)\s*:\s*(.+?)\s*=\s*(.+?)\s*:=?",
    re.MULTILINE,
)


def normalize_expr(expr: str) -> str:
    return re.sub(r"\s+", "", expr)


def lint_lean_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    findings: list[str] = []
    for _, pattern, message in VacuousLeanPatterns:
        for match in pattern.finditer(text):
            findings.append(f"{path}: {message} in `{match.group(1)}`")
    for match in SelfEqualityPattern.finditer(text):
        lhs = normalize_expr(match.group(2))
        rhs = normalize_expr(match.group(3))
        if lhs == rhs:
            findings.append(f"{path}: theorem `{match.group(1)}` is a direct self-equality")
    return findings


def lint_proof_docs(paths: list[Path]) -> list[str]:
    forbidden = [
        re.compile(r"\bAPPROVED FOR PRODUCTION USE\b"),
        re.compile(r"\bVERIFIED AND CERTIFIED FOR PRODUCTION USE\b"),
        re.compile(r"Formal Methods Team \+ Automated CI"),
    ]
    findings: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for pattern in forbidden:
            for match in pattern.finditer(text):
                findings.append(f"{path}: forbidden proof-certification phrase `{match.group(0)}`")
    return findings


def lint_claims_file(path: Path) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    findings: list[str] = []
    valid_statuses = {
        "fully_formalized",
        "model_verified",
        "surrogate_verified",
        "runtime_validated_only",
    }
    for claim in payload.get("claims", []):
        claim_id = claim.get("id", "<missing-id>")
        status = claim.get("status")
        if status not in valid_statuses:
            findings.append(f"{path}: claim `{claim_id}` has invalid status `{status}`")
        if status != "fully_formalized" and not claim.get("blocking_gaps"):
            findings.append(f"{path}: claim `{claim_id}` is `{status}` but has no `blocking_gaps`")
        if not claim.get("lean_modules"):
            findings.append(f"{path}: claim `{claim_id}` is missing `lean_modules`")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint formal proof claims and proof-facing artifacts")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    claims_file = root / "proofs" / "theorem_claims.json"
    lean_files = list((root / "proofs" / "LeanFormalization").glob("*.lean"))
    lean_files += list((root / "proofs" / "Specification").glob("*.lean"))
    lean_files += list((root / "proofs" / "Refinement").glob("*.lean"))

    protected_docs = [
        root / "proofs" / "FORMAL_TRACEABILITY_MATRIX.md",
        root / "proofs" / "FORMAL_VERIFICATION_GUIDE.md",
        root / "proofs" / "FULL_FORMALIZATION_VALIDATION_REPORT.md",
        root / "proofs" / "FORMALIZATION_TEST_COMPLETE.md",
        root / "proofs" / "MACHINE_VERIFICATION_REPORT.md",
        root / "TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md",
        root / "BLOG_POST_FORMAL_PROOFS.md",
    ]

    findings: list[str] = []
    if claims_file.exists():
        findings.extend(lint_claims_file(claims_file))
    for path in lean_files:
        findings.extend(lint_lean_file(path))
    findings.extend(lint_proof_docs([p for p in protected_docs if p.exists()]))

    if findings:
        print("formal proof claim lint failed")
        for item in findings:
            print(f"  - {item}")
        return 1

    print("formal proof claim lint passed")
    print(f"  - claims metadata: {claims_file}")
    print(f"  - lean files checked: {len(lean_files)}")
    print(f"  - protected docs checked: {len([p for p in protected_docs if p.exists()])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
