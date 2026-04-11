#!/usr/bin/env python3
"""Build scaled swarm benchmark artifacts from go test JSONL outputs."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List


FILE_RE = re.compile(r"(?P<nodes>\d+)_(?P<profile>safe|edge)\.jsonl$")


@dataclass
class BenchmarkRow:
    nodes: int
    profile: str
    elapsed_seconds: float
    passed: bool


def parse_jsonl(path: Path) -> BenchmarkRow:
    match = FILE_RE.search(path.name)
    if not match:
        raise ValueError(f"unexpected filename format: {path.name}")

    nodes = int(match.group("nodes"))
    profile = match.group("profile")
    elapsed = 0.0
    passed = False

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            event = json.loads(line)
            if event.get("Test") != "TestSwarmRuntimeProfileFromEnv":
                continue
            action = event.get("Action")
            if action == "pass":
                passed = True
                elapsed = float(event.get("Elapsed", 0.0))
            elif action == "fail":
                passed = False
                elapsed = float(event.get("Elapsed", 0.0))

    return BenchmarkRow(nodes=nodes, profile=profile, elapsed_seconds=elapsed, passed=passed)


def render_markdown(rows: List[BenchmarkRow]) -> str:
    lines = [
        "# Scaled Swarm Benchmark Report",
        "",
        "Router-enabled runtime swarm benchmark summary generated from CI matrix outputs.",
        "",
        "| Nodes | Profile | Result | Elapsed (s) |",
        "| ---: | --- | --- | ---: |",
    ]
    for row in sorted(rows, key=lambda r: (r.nodes, r.profile)):
        result = "pass" if row.passed else "fail"
        lines.append(f"| {row.nodes} | {row.profile} | {result} | {row.elapsed_seconds:.3f} |")

    return "\n".join(lines) + "\n"


def main() -> int:
    out_dir = Path("test-results/swarm-runtime")
    out_dir.mkdir(parents=True, exist_ok=True)

    rows: List[BenchmarkRow] = []
    for path in out_dir.glob("*_*.jsonl"):
        if not FILE_RE.search(path.name):
            continue
        rows.append(parse_jsonl(path))

    payload: Dict[str, object] = {
        "generated_from": "Swarm Runtime Matrix",
        "results": [
            {
                "nodes": row.nodes,
                "profile": row.profile,
                "passed": row.passed,
                "elapsed_seconds": row.elapsed_seconds,
            }
            for row in sorted(rows, key=lambda r: (r.nodes, r.profile))
        ],
    }

    (out_dir / "scaled_swarm_benchmark_report.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )
    (out_dir / "scaled_swarm_benchmark_report.md").write_text(
        render_markdown(rows), encoding="utf-8"
    )

    print(f"Wrote {len(rows)} benchmark rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
