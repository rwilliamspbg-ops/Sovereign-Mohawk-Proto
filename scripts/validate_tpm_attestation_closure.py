#!/usr/bin/env python3
"""Validate TPM attestation production-closure evidence.

This validator is intentionally separate from the formal go-live gate until
cross-platform closure is complete.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

REQUIRED_PLATFORMS = ("linux", "windows", "macos")


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_report(repo_root: Path, matrix_path: Path, attestation_path: Path) -> dict:
    failures: list[str] = []
    checks: dict[str, bool] = {}

    matrix_file = repo_root / matrix_path
    attestation_file = repo_root / attestation_path

    if not matrix_file.exists():
        failures.append(f"missing matrix file: {matrix_path.as_posix()}")
        matrix = {"platforms": []}
    else:
        matrix = _load_json(matrix_file)

    if not attestation_file.exists():
        failures.append(f"missing attestation file: {attestation_path.as_posix()}")
        attestation = {}
    else:
        attestation = _load_json(attestation_file)

    platform_rows = {
        str(row.get("platform", "")).strip().lower(): row for row in matrix.get("platforms", [])
    }

    all_platforms_present = True
    all_platforms_pass = True
    all_platforms_have_evidence = True

    platform_status: dict[str, dict[str, object]] = {}

    for platform in REQUIRED_PLATFORMS:
        row = platform_rows.get(platform)
        if row is None:
            all_platforms_present = False
            all_platforms_pass = False
            all_platforms_have_evidence = False
            failures.append(f"platform missing from matrix: {platform}")
            platform_status[platform] = {
                "present": False,
                "status": "missing",
                "evidence_count": 0,
                "ok": False,
            }
            continue

        status = str(row.get("status", "")).strip().lower()
        evidence = row.get("evidence", [])
        if not isinstance(evidence, list):
            evidence = []
        evidence_count = len(evidence)

        platform_ok = status == "pass" and evidence_count > 0
        if status != "pass":
            all_platforms_pass = False
            failures.append(f"platform not passing: {platform} status={status or 'missing'}")
        if evidence_count == 0:
            all_platforms_have_evidence = False
            failures.append(f"platform missing evidence attachment: {platform}")

        platform_status[platform] = {
            "present": True,
            "status": status or "missing",
            "evidence_count": evidence_count,
            "ok": platform_ok,
        }

    attestation_status = str(attestation.get("status", "")).strip().lower()
    attestation_approved = attestation_status == "approved"

    if not attestation_approved:
        failures.append(f"attestation status is not approved: {attestation_status or 'missing'}")

    checks["all_platforms_present"] = all_platforms_present
    checks["all_platforms_pass"] = all_platforms_pass
    checks["all_platforms_have_evidence"] = all_platforms_have_evidence
    checks["attestation_approved"] = attestation_approved

    ok = all(checks.values())

    return {
        "generated_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "matrix": matrix_path.as_posix(),
        "attestation": attestation_path.as_posix(),
        "checks": checks,
        "platform_status": platform_status,
        "failures": failures,
        "ok": ok,
    }


def to_markdown(report: dict) -> str:
    lines = [
        "# TPM Attestation Production Closure Validation",
        "",
        f"- Generated (UTC): `{report['generated_utc']}`",
        f"- Overall result: `{'PASS' if report['ok'] else 'FAIL'}`",
        "",
        "## Platform Status",
        "",
        "| Platform | Present | Status | Evidence Count | Result |",
        "| --- | --- | --- | --- | --- |",
    ]

    for platform in REQUIRED_PLATFORMS:
        row = report["platform_status"].get(platform, {})
        lines.append(
            "| {platform} | {present} | {status} | {evidence_count} | {result} |".format(
                platform=platform,
                present="yes" if row.get("present") else "no",
                status=row.get("status", "missing"),
                evidence_count=row.get("evidence_count", 0),
                result="PASS" if row.get("ok") else "FAIL",
            )
        )

    lines.extend(["", "## Checks", ""])
    for name, value in report["checks"].items():
        lines.append(f"- `{name}`: {'PASS' if value else 'FAIL'}")

    lines.extend(["", "## Failures", ""])
    if report["failures"]:
        for failure in report["failures"]:
            lines.append(f"- {failure}")
    else:
        lines.append("- none")

    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate TPM attestation production-closure evidence."
    )
    parser.add_argument(
        "--matrix",
        default="results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json",
        help="Path to TPM cross-platform matrix JSON (relative to repo root).",
    )
    parser.add_argument(
        "--attestation",
        default="results/go-live/attestations/tpm_attestation_production_closure.json",
        help="Path to TPM closure attestation JSON (relative to repo root).",
    )
    parser.add_argument(
        "--output-json",
        default="results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json",
        help="Output JSON path (relative to repo root).",
    )
    parser.add_argument(
        "--output-md",
        default="results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md",
        help="Output markdown path (relative to repo root).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]

    report = build_report(repo_root, Path(args.matrix), Path(args.attestation))

    out_json = repo_root / Path(args.output_json)
    out_md = repo_root / Path(args.output_md)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    out_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    out_md.write_text(to_markdown(report), encoding="utf-8")

    print(f"wrote {out_json}")
    print(f"wrote {out_md}")
    print("status=PASS" if report["ok"] else "status=FAIL")

    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
