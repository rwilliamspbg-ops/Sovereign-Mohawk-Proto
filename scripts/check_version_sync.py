#!/usr/bin/env python3
"""Verify VERSION, README, CHANGELOG, and sdk/python version are in sync."""

import re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
version = (root / "VERSION").read_text().strip()
errors = []
# README
readme = (root / "README.md").read_text()
if f"### Platform Upgrade (v{version})" not in readme:
    errors.append(f"README missing '### Platform Upgrade (v{version})'")
# CHANGELOG
cl = (root / "CHANGELOG.md").read_text()
if f"## [{version}]" not in cl:
    errors.append(f"CHANGELOG missing '## [{version}]'")
# sdk/python version
init = root / "sdk/python/mohawk/__init__.py"
if init.exists():
    txt = init.read_text()
    m = re.search(r'__version__\s*=\s*"([^"]+)"', txt)
    if m and m.group(1) != version:
        errors.append(f"sdk/python __version__ {m.group(1)} != {version}")
if errors:
    for e in errors:
        print("ERROR:", e)
    sys.exit(1)
print(f"Version sync OK: {version}")
