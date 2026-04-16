#!/usr/bin/env python3
"""Simple end-to-end test for tamper-evident bundle generation and validation."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
EXPORT_SCRIPT = REPO_ROOT / "scripts" / "export_tamper_evident_events.py"
CHECK_SCRIPT = REPO_ROOT / "scripts" / "ci" / "check_tamper_evident_bundle.py"


REQUIRED_FILES = (
    "events.ndjson",
    "events_chained.ndjson",
    "bundle_manifest.json",
    "tamper_evident_events_bundle.tar.gz",
)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, cwd=REPO_ROOT, check=True)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="mohawk-tamper-e2e-") as tmp:
        out_dir = Path(tmp) / "bundle"

        run(["python3", str(EXPORT_SCRIPT), "--output-dir", str(out_dir)])
        run(["python3", str(CHECK_SCRIPT), "--bundle-dir", str(out_dir)])

        missing = [name for name in REQUIRED_FILES if not (out_dir / name).exists()]
        if missing:
            raise SystemExit(f"missing expected output files: {', '.join(missing)}")

    print("tamper-evident bundle e2e test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
