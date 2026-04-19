#!/usr/bin/env python3
"""Validate local Markdown links in the repository.

This checker intentionally ignores remote URLs to avoid flaky CI behavior.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Matches inline markdown links: [text](target)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")

# Matches image links: ![alt](target)
IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")

IGNORE_DIRS = {
    ".git",
    ".github",
    "node_modules",
    "test-results",
    "results",
    "captured_artifacts",
    "runtime-secrets",
}


def is_ignored(path: Path) -> bool:
    return any(part in IGNORE_DIRS for part in path.parts)


def normalize_target(target: str) -> str:
    return target.split("#", 1)[0].strip()


def is_external_or_non_file_target(target: str) -> bool:
    lower = target.lower()
    return (
        not target
        or target.startswith("#")
        or lower.startswith("http://")
        or lower.startswith("https://")
        or lower.startswith("mailto:")
        or lower.startswith("tel:")
    )


def collect_markdown_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*.md"):
        if path.is_file() and not is_ignored(path.relative_to(ROOT)):
            files.append(path)
    return files


def link_exists(md_path: Path, target: str) -> bool:
    if target.startswith("/"):
        candidate = ROOT / target.lstrip("/")
    else:
        candidate = (md_path.parent / target).resolve()
    return candidate.exists()


def check_file(md_path: Path) -> list[str]:
    errors: list[str] = []
    text = md_path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    for lineno, line in enumerate(lines, start=1):
        targets = LINK_RE.findall(line) + IMAGE_RE.findall(line)
        for raw_target in targets:
            if is_external_or_non_file_target(raw_target):
                continue
            target = normalize_target(raw_target)
            if not target:
                continue
            if not link_exists(md_path, target):
                rel_md = md_path.relative_to(ROOT)
                errors.append(f"{rel_md}:{lineno}: broken local link target '{raw_target}'")
    return errors


def main() -> int:
    markdown_files = collect_markdown_files()
    all_errors: list[str] = []
    for md_file in markdown_files:
        all_errors.extend(check_file(md_file))

    if all_errors:
        print("Markdown link check failed:")
        for err in all_errors:
            print(f"  - {err}")
        return 1

    print(f"Markdown link check passed for {len(markdown_files)} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
