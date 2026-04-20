#!/usr/bin/env python3
"""Smoke-test the container runner script wiring with a fake docker binary."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER_SCRIPT = REPO_ROOT / "scripts" / "ci" / "run_formal_validation_in_container.sh"


FAKE_DOCKER_SCRIPT = """#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
exit 0
"""


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="mohawk-fake-docker-") as tmp:
        tmp_path = Path(tmp)
        fake_bin = tmp_path / "bin"
        fake_bin.mkdir(parents=True, exist_ok=True)

        fake_docker = fake_bin / "docker"
        fake_docker.write_text(FAKE_DOCKER_SCRIPT, encoding="utf-8")
        fake_docker.chmod(0o755)

        log_path = tmp_path / "docker_calls.log"

        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}:{env.get('PATH', '')}"
        env["FAKE_DOCKER_LOG"] = str(log_path)
        env["FORMAL_VERIFIER_IMAGE_TAG"] = "mohawk/test-formal-verifier:unit"

        proc = subprocess.run(
            ["bash", str(RUNNER_SCRIPT)],
            cwd=REPO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0:
            raise SystemExit(
                f"runner script failed: {proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
            )

        if not log_path.exists():
            raise SystemExit("fake docker log missing")

        calls = log_path.read_text(encoding="utf-8").splitlines()
        if len(calls) != 2:
            raise SystemExit(f"expected 2 docker calls (build + run), got {len(calls)}")

        if "build -t mohawk/test-formal-verifier:unit" not in calls[0]:
            raise SystemExit("missing expected docker build invocation")
        if "run --rm" not in calls[1]:
            raise SystemExit("missing expected docker run invocation")
        if "make validate-formal" not in calls[1]:
            raise SystemExit("docker run command missing validate-formal")

    print("formal validation container runner smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
