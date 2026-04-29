#!/usr/bin/env python3
"""End-to-end checks for formal verification bundle build + verification."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
TRACE_SCRIPT = REPO_ROOT / "scripts" / "ci" / "validate_formal_traceability.sh"
ARTIFACT_SCRIPT = REPO_ROOT / "scripts" / "ci" / "generate_formal_proof_artifacts.sh"
REPORT_SCRIPT = REPO_ROOT / "scripts" / "ci" / "generate_formal_validation_report.py"
BUILD_BUNDLE_SCRIPT = (
    REPO_ROOT / "scripts" / "ci" / "build_formal_verification_bundle.py"
)
VERIFY_BUNDLE_SCRIPT = (
    REPO_ROOT / "scripts" / "ci" / "verify_formal_verification_bundle.py"
)


def run(
    cmd: list[str], expect_success: bool = True
) -> subprocess.CompletedProcess[str]:
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
    # Ensure source artifacts expected by the bundler exist.
    run(["bash", str(TRACE_SCRIPT)])
    run(["bash", str(ARTIFACT_SCRIPT)])

    with tempfile.TemporaryDirectory(prefix="mohawk-formal-bundle-") as tmp:
        tmp_path = Path(tmp)
        report_path = tmp_path / "formal_validation_report.json"
        bundle_dir = tmp_path / "formal-verification-bundle"
        bundle_tar = tmp_path / "formal-verification-bundle.tar.gz"

        run(["python3", str(REPORT_SCRIPT), "--output", str(report_path)])

        run(
            [
                "python3",
                str(BUILD_BUNDLE_SCRIPT),
                "--report",
                str(report_path),
                "--bundle-dir",
                str(bundle_dir),
                "--bundle-tar",
                str(bundle_tar),
            ]
        )

        if not bundle_dir.exists():
            raise SystemExit(f"bundle directory not created: {bundle_dir}")
        if not bundle_tar.exists():
            raise SystemExit(f"bundle archive not created: {bundle_tar}")

        manifest_path = bundle_dir / "bundle_manifest.json"
        if not manifest_path.exists():
            raise SystemExit(f"missing bundle manifest: {manifest_path}")

        run(["python3", str(VERIFY_BUNDLE_SCRIPT), "--bundle-dir", str(bundle_dir)])

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        report_in_bundle = bundle_dir / "results/proofs/formal_validation_report.json"
        payload = json.loads(report_in_bundle.read_text(encoding="utf-8"))
        payload["input_merkle_root"] = "0" * 64
        report_in_bundle.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

        failed = run(
            ["python3", str(VERIFY_BUNDLE_SCRIPT), "--bundle-dir", str(bundle_dir)],
            expect_success=False,
        )
        if failed.returncode == 0:
            raise SystemExit(
                "expected bundle verification to fail after report tampering"
            )

        failure_output = failed.stdout + failed.stderr
        if (
            "report_input_merkle_root mismatch" not in failure_output
            and "hash mismatch" not in failure_output
        ):
            raise SystemExit("expected report/root mismatch in verifier failure output")

        if not manifest.get("bundle_merkle_root"):
            raise SystemExit("bundle manifest missing bundle_merkle_root")

    print("formal verification bundle e2e test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
