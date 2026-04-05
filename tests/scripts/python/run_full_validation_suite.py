#!/usr/bin/env python3
"""Run profile-based full validation suites and emit reproducible artifacts.

Artifacts:
- test-results/full-validation/full_validation_<timestamp>.json
- test-results/full-validation/full_validation_<timestamp>.md
- test-results/full-validation/history.jsonl
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parents[3]
ARTIFACT_DIR = ROOT / "test-results" / "full-validation"


@dataclass
class CommandResult:
    command: str
    exit_code: int
    duration_seconds: float


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def profile_commands(profile: str) -> List[str]:
    fast = [
        "make verify",
        "make fips-regression",
        "make openapi-spec",
        "make capability-dashboard-matrix",
    ]
    deep = fast + [
        "make release-performance-evidence",
        "make go-live-gate-advisory",
        "make failure-injection-latency-check",
        "make tpm-closure-summary",
    ]
    return deep if profile == "deep" else fast


def run_command(command: str) -> CommandResult:
    start = time.perf_counter()
    proc = subprocess.run(
        command,
        cwd=ROOT,
        shell=True,
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    duration = time.perf_counter() - start

    print(f"\n$ {command}")
    if proc.stdout:
        print(proc.stdout.rstrip())
    if proc.stderr:
        print(proc.stderr.rstrip(), file=sys.stderr)

    return CommandResult(
        command=command,
        exit_code=proc.returncode,
        duration_seconds=round(duration, 3),
    )


def write_markdown(report: dict, path: Path) -> None:
    lines = [
        "# Full Validation Report",
        "",
        f"- Timestamp: {report['timestamp_utc']}",
        f"- Profile: {report['profile']}",
        f"- Status: {'PASS' if report['passed'] else 'FAIL'}",
        f"- Duration (s): {report['duration_seconds']}",
        "",
        "## Command Results",
        "",
        "| Command | Exit | Duration (s) |",
        "| --- | ---: | ---: |",
    ]
    for entry in report["commands"]:
        lines.append(
            f"| `{entry['command']}` | {entry['exit_code']} | {entry['duration_seconds']} |"
        )
    lines.append("")
    if report["failed_commands"]:
        lines.append("## Failed Commands")
        lines.append("")
        for cmd in report["failed_commands"]:
            lines.append(f"- `{cmd}`")
    else:
        lines.append("All commands passed.")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--profile",
        choices=["fast", "deep"],
        default="fast",
        help="Validation profile to execute.",
    )
    args = parser.parse_args()

    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

    start = time.perf_counter()
    commands = profile_commands(args.profile)
    results = [run_command(cmd) for cmd in commands]
    duration = round(time.perf_counter() - start, 3)

    failed = [r.command for r in results if r.exit_code != 0]
    report = {
        "timestamp_utc": utc_now_iso(),
        "profile": args.profile,
        "passed": not failed,
        "duration_seconds": duration,
        "commands": [r.__dict__ for r in results],
        "failed_commands": failed,
    }

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    json_path = ARTIFACT_DIR / f"full_validation_{ts}.json"
    md_path = ARTIFACT_DIR / f"full_validation_{ts}.md"
    history_path = ARTIFACT_DIR / "history.jsonl"

    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_markdown(report, md_path)
    with history_path.open("a", encoding="utf-8") as fp:
        fp.write(json.dumps(report) + "\n")

    print(f"Wrote: {json_path}")
    print(f"Wrote: {md_path}")
    print(f"Updated: {history_path}")

    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
