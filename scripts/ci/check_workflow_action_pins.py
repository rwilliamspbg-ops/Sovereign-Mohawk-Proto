#!/usr/bin/env python3
"""Ensure GitHub workflow actions are pinned to full commit SHAs."""

from __future__ import annotations

import re
from pathlib import Path

WORKFLOWS_DIR = Path(".github/workflows")
USES_RE = re.compile(r"^\s*uses:\s*([^\s#]+)")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def is_local_action(ref: str) -> bool:
    return ref.startswith("./") or ref.startswith(".github/")


def validate_uses(value: str) -> str | None:
    if "@" not in value:
        return f"missing @ref: {value}"
    action, ref = value.rsplit("@", 1)
    if is_local_action(action):
        return None
    if not SHA_RE.fullmatch(ref):
        return f"not pinned to 40-char SHA: {value}"
    return None


def main() -> int:
    violations: list[str] = []

    for workflow in sorted(WORKFLOWS_DIR.glob("*.yml")):
        for i, line in enumerate(
            workflow.read_text(encoding="utf-8").splitlines(), start=1
        ):
            match = USES_RE.match(line)
            if not match:
                continue
            value = match.group(1).strip()
            issue = validate_uses(value)
            if issue:
                violations.append(f"{workflow}:{i}: {issue}")

    if violations:
        print("Workflow action pin check failed:")
        for v in violations:
            print(f"- {v}")
        return 1

    print("Workflow action pin check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
