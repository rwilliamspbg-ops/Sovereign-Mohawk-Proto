#!/usr/bin/env python3
"""End-to-end checks for machine-checkable formal validation report generation."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
REPORT_SCRIPT = REPO_ROOT / "scripts" / "ci" / "generate_formal_validation_report.py"


def run(cmd: list[str], expect_success: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if expect_success and proc.returncode != 0:
        raise SystemExit(
            "command failed with exit code "
            f"{proc.returncode}: {' '.join(cmd)}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )
    return proc


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="mohawk-formal-report-") as tmp:
        tmp_path = Path(tmp)
        out_path = tmp_path / "formal_validation_report.json"

        run(["python3", str(REPORT_SCRIPT), "--output", str(out_path)])

        if not out_path.exists():
            raise SystemExit(f"missing expected report output: {out_path}")

        payload = json.loads(out_path.read_text(encoding="utf-8"))

        required_top_level = {
            "schema_version",
            "toolchain_lock",
            "inputs",
            "input_merkle_root",
            "traceability",
            "lean_modules",
            "summary",
        }
        missing = sorted(required_top_level - set(payload.keys()))
        if missing:
            raise SystemExit(f"report missing top-level keys: {', '.join(missing)}")

        toolchain_lock = payload.get("toolchain_lock", {})
        for required in ("lean_toolchain", "mathlib4_ref", "go_version", "zk_backend_gnark_crypto"):
            if not toolchain_lock.get(required):
                raise SystemExit(f"toolchain lock missing required field: {required}")

        check_ok = run(
            ["python3", str(REPORT_SCRIPT), "--output", str(out_path), "--check"],
            expect_success=True,
        )
        if "check passed" not in check_ok.stdout:
            raise SystemExit("expected --check success confirmation in output")

        tampered = dict(payload)
        tampered["schema_version"] = "formal_validation_report.v1_tampered"
        out_path.write_text(json.dumps(tampered, indent=2) + "\n", encoding="utf-8")

        check_fail = run(
            ["python3", str(REPORT_SCRIPT), "--output", str(out_path), "--check"],
            expect_success=False,
        )
        if check_fail.returncode == 0:
            raise SystemExit("expected --check to fail for tampered report")
        if "mismatch" not in (check_fail.stdout + check_fail.stderr):
            raise SystemExit("expected mismatch error for tampered report")

    print("formal validation report e2e test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
