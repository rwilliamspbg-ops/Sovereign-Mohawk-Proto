#!/usr/bin/env python3
"""Ensure GitHub workflow actions are pinned to full commit SHAs."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

WORKFLOWS_DIR = Path(".github/workflows")
USES_RE = re.compile(r"^\s*uses:\s*([^\s#]+)")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def is_local_action(ref: str) -> bool:
    return ref.startswith("./") or ref.startswith(".github/")


def is_docker_action(ref: str) -> bool:
    return ref.startswith("docker://")


def action_repo_slug(action: str) -> str | None:
    parts = action.split("/")
    if len(parts) < 2:
        return None
    owner, repo = parts[0], parts[1]
    if not owner or not repo:
        return None
    return f"{owner}/{repo}"


def validate_uses(value: str) -> str | None:
    if "@" not in value:
        return f"missing @ref: {value}"
    action, ref = value.rsplit("@", 1)
    if is_local_action(action) or is_docker_action(action):
        return None
    if not SHA_RE.fullmatch(ref):
        return f"not pinned to 40-char SHA: {value}"
    return None


def sha_exists_in_repo(
    repo_slug: str, ref: str, cache: dict[str, set[str] | None]
) -> bool:
    if repo_slug not in cache:
        proc = subprocess.run(
            ["git", "ls-remote", f"https://github.com/{repo_slug}.git"],
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if proc.returncode != 0:
            cache[repo_slug] = None
        else:
            commits: set[str] = set()
            for line in proc.stdout.splitlines():
                if not line.strip():
                    continue
                sha = line.split()[0]
                if SHA_RE.fullmatch(sha):
                    commits.add(sha)
            cache[repo_slug] = commits

    commits_or_none = cache[repo_slug]
    if commits_or_none is None:
        return False
    return ref in commits_or_none


def main() -> int:
    violations: list[str] = []
    sha_cache: dict[str, set[str] | None] = {}

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
                continue

            action, ref = value.rsplit("@", 1)
            if is_local_action(action) or is_docker_action(action):
                continue

            repo_slug = action_repo_slug(action)
            if repo_slug is None:
                violations.append(
                    f"{workflow}:{i}: unable to parse action repo: {value}"
                )
                continue

            if not sha_exists_in_repo(repo_slug, ref, sha_cache):
                violations.append(f"{workflow}:{i}: unresolved action SHA: {value}")

    if violations:
        print("Workflow action pin check failed:")
        for v in violations:
            print(f"- {v}")
        return 1

    print("Workflow action pin check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
