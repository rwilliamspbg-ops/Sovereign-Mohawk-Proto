#!/usr/bin/env python3
"""Write a markdown summary diffing the two most recent validation runs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_history(path: Path) -> list[dict]:
    if not path.exists():
        return []
    out: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--history",
        default="test-results/full-validation/history.jsonl",
        help="Path to history jsonl.",
    )
    parser.add_argument(
        "--output",
        default="test-results/full-validation/validation_diff_summary.md",
        help="Markdown output path.",
    )
    args = parser.parse_args()

    history = load_history(Path(args.history))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    if len(history) < 2:
        output.write_text(
            "# Validation Diff Summary\n\n"
            "Not enough history entries to generate a diff summary.\n",
            encoding="utf-8",
        )
        print(f"Wrote: {output}")
        return 0

    prev = history[-2]
    curr = history[-1]

    prev_by_cmd = {c["command"]: c for c in prev.get("commands", [])}
    curr_by_cmd = {c["command"]: c for c in curr.get("commands", [])}
    all_cmds = sorted(set(prev_by_cmd) | set(curr_by_cmd))

    lines = [
        "# Validation Diff Summary",
        "",
        f"- Previous: {prev.get('timestamp_utc', 'unknown')} ({'PASS' if prev.get('passed') else 'FAIL'})",
        f"- Current: {curr.get('timestamp_utc', 'unknown')} ({'PASS' if curr.get('passed') else 'FAIL'})",
        "",
        "| Command | Prev Exit | Curr Exit | Prev Duration (s) | Curr Duration (s) | Delta (s) |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]

    for cmd in all_cmds:
        p = prev_by_cmd.get(cmd)
        c = curr_by_cmd.get(cmd)
        p_exit = p["exit_code"] if p else "NA"
        c_exit = c["exit_code"] if c else "NA"
        p_dur = p["duration_seconds"] if p else "NA"
        c_dur = c["duration_seconds"] if c else "NA"

        if p and c:
            delta = round(float(c["duration_seconds"]) - float(p["duration_seconds"]), 3)
        else:
            delta = "NA"

        lines.append(
            f"| `{cmd}` | {p_exit} | {c_exit} | {p_dur} | {c_dur} | {delta} |"
        )

    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
