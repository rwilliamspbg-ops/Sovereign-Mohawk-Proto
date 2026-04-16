#!/usr/bin/env python3
"""Generate TPM closure dashboard summary artifacts."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _latest_matching(repo_root: Path, pattern: str) -> Path | None:
    matches = sorted((repo_root / "results" / "go-live" / "evidence").glob(pattern))
    if not matches:
        return None
    return matches[-1]


def build_summary(repo_root: Path) -> dict:
    evidence_dir = repo_root / "results" / "go-live" / "evidence"
    matrix_path = _latest_matching(repo_root, "tpm_attestation_cross_platform_matrix_*.json")
    validation_path = _latest_matching(repo_root, "tpm_attestation_closure_validation_*.json")
    strict_path = _latest_matching(repo_root, "go_live_gate_strict_*.json")
    advisory_path = _latest_matching(repo_root, "go_live_gate_advisory_*.json")
    attestation_path = (
        repo_root
        / "results"
        / "go-live"
        / "attestations"
        / "tpm_attestation_production_closure.json"
    )

    if matrix_path is None or validation_path is None:
        raise FileNotFoundError("TPM matrix/validation artifacts are required to build summary")

    matrix = _load_json(matrix_path)
    validation = _load_json(validation_path)
    attestation = (
        _load_json(attestation_path) if attestation_path.exists() else {"status": "missing"}
    )
    strict_gate = (
        _load_json(strict_path)
        if strict_path and strict_path.exists()
        else {"ok": False, "status": "missing"}
    )
    advisory_gate = (
        _load_json(advisory_path)
        if advisory_path and advisory_path.exists()
        else {"ok": False, "status": "missing"}
    )

    platform_rows = matrix.get("platforms", [])
    total = len(platform_rows)
    passed = sum(1 for row in platform_rows if str(row.get("status", "")).strip().lower() == "pass")

    completion_pct = round((passed / total) * 100, 2) if total else 0.0

    summary = {
        "generated_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "matrix_artifact": str(matrix_path.relative_to(repo_root)).replace("\\", "/"),
        "closure_validation_artifact": str(validation_path.relative_to(repo_root)).replace(
            "\\", "/"
        ),
        "go_live_gate_advisory_artifact": (
            str(advisory_path.relative_to(repo_root)).replace("\\", "/")
            if advisory_path
            else "missing"
        ),
        "go_live_gate_strict_artifact": (
            str(strict_path.relative_to(repo_root)).replace("\\", "/") if strict_path else "missing"
        ),
        "attestation_status": str(attestation.get("status", "missing")),
        "closure_ok": bool(validation.get("ok", False)),
        "platforms_passed": passed,
        "platforms_total": total,
        "platform_completion_percent": completion_pct,
        "go_live_advisory_ok": bool(advisory_gate.get("ok", False)),
        "go_live_strict_ok": bool(strict_gate.get("ok", False)),
        "remaining_failures": validation.get("failures", []),
        "platform_status": validation.get("platform_status", {}),
    }
    summary["ga_ready"] = bool(
        summary["closure_ok"]
        and summary["go_live_strict_ok"]
        and summary["attestation_status"] == "approved"
    )

    evidence_dir.mkdir(parents=True, exist_ok=True)
    return summary


def render_markdown(summary: dict) -> str:
    lines = [
        "# TPM Closure Summary",
        "",
        f"- Generated (UTC): `{summary['generated_utc']}`",
        f"- GA ready: `{'YES' if summary['ga_ready'] else 'NO'}`",
        f"- Platform completion: `{summary['platforms_passed']}/{summary['platforms_total']} ({summary['platform_completion_percent']}%)`",
        f"- Attestation status: `{summary['attestation_status']}`",
        "",
        "## Gate Status",
        "",
        f"- Advisory go-live gate: `{'PASS' if summary['go_live_advisory_ok'] else 'FAIL'}`",
        f"- Strict go-live gate: `{'PASS' if summary['go_live_strict_ok'] else 'FAIL'}`",
        f"- TPM closure validation: `{'PASS' if summary['closure_ok'] else 'FAIL'}`",
        "",
        "## Platform Status",
        "",
        "| Platform | Status | Evidence Count | Result |",
        "| --- | --- | --- | --- |",
    ]

    for platform, row in sorted(summary.get("platform_status", {}).items()):
        lines.append(
            "| {platform} | {status} | {count} | {result} |".format(
                platform=platform,
                status=row.get("status", "missing"),
                count=row.get("evidence_count", 0),
                result="PASS" if row.get("ok") else "FAIL",
            )
        )

    lines.extend(["", "## Remaining Failures", ""])
    failures = summary.get("remaining_failures", [])
    if failures:
        for failure in failures:
            lines.append(f"- {failure}")
    else:
        lines.append("- none")

    lines.extend(["", "## Evidence Inputs", ""])
    lines.append(f"- `{summary['matrix_artifact']}`")
    lines.append(f"- `{summary['closure_validation_artifact']}`")
    lines.append(f"- `{summary['go_live_gate_advisory_artifact']}`")
    lines.append(f"- `{summary['go_live_gate_strict_artifact']}`")
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate TPM closure summary artifacts")
    parser.add_argument("--repo-root", default=".", help="Repository root path")
    parser.add_argument(
        "--output-json",
        default="results/go-live/evidence/tpm_closure_summary_2026-03-28.json",
        help="Output summary JSON path (relative to repo root)",
    )
    parser.add_argument(
        "--output-md",
        default="results/go-live/evidence/tpm_closure_summary_2026-03-28.md",
        help="Output summary markdown path (relative to repo root)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()

    summary = build_summary(repo_root)
    out_json = repo_root / Path(args.output_json)
    out_md = repo_root / Path(args.output_md)

    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    out_json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    out_md.write_text(render_markdown(summary), encoding="utf-8")

    print(f"wrote {out_json}")
    print(f"wrote {out_md}")
    print("status=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
