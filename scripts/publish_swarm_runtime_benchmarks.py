#!/usr/bin/env python3
"""Build scaled swarm benchmark artifacts from go test JSONL outputs."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional


FILE_RE = re.compile(
    r"(?:runtime_)?(?P<nodes>\d+)_(?P<profile>safe|edge)(?:_count(?P<count>\d+))?\.jsonl$"
)


@dataclass
class BenchmarkRow:
    nodes: int
    profile: str
    count: int
    elapsed_seconds: float
    passed: bool
    wall_seconds: Optional[float]
    user_seconds: Optional[float]
    sys_seconds: Optional[float]


def parse_time_file(path: Path) -> Dict[str, float]:
    metrics: Dict[str, float] = {}
    for token in path.read_text(encoding="utf-8").strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        try:
            metrics[key] = float(value)
        except ValueError:
            continue
    return metrics


def parse_jsonl(path: Path) -> BenchmarkRow:
    match = FILE_RE.search(path.name)
    if not match:
        raise ValueError(f"unexpected filename format: {path.name}")

    nodes = int(match.group("nodes"))
    profile = match.group("profile")
    count = int(match.group("count") or 1)
    elapsed = 0.0
    passed = False
    wall_seconds: Optional[float] = None
    user_seconds: Optional[float] = None
    sys_seconds: Optional[float] = None

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

    time_path = path.with_suffix(".time")
    if time_path.exists():
        timing = parse_time_file(time_path)
        wall_seconds = timing.get("real")
        user_seconds = timing.get("user")
        sys_seconds = timing.get("sys")

    return BenchmarkRow(
        nodes=nodes,
        profile=profile,
        count=count,
        elapsed_seconds=elapsed,
        passed=passed,
        wall_seconds=wall_seconds,
        user_seconds=user_seconds,
        sys_seconds=sys_seconds,
    )


def row_throughput(row: BenchmarkRow) -> Optional[float]:
    if not row.wall_seconds or row.wall_seconds <= 0:
        return None
    return row.count / row.wall_seconds


def row_ms_per_iter(row: BenchmarkRow) -> Optional[float]:
    if not row.wall_seconds or row.count <= 0:
        return None
    return (row.wall_seconds * 1000.0) / row.count


def render_markdown(rows: List[BenchmarkRow]) -> str:
    out_dir = Path("test-results/swarm-runtime")
    router_smoke_path = out_dir / "router_smoke.txt"
    router_metrics_path = out_dir / "router_metrics_snapshot.prom"
    router_smoke_passed = (
        router_smoke_path.exists()
        and "[router-smoke] PASS" in router_smoke_path.read_text(encoding="utf-8")
    )
    router_metrics_captured = (
        router_metrics_path.exists() and router_metrics_path.stat().st_size > 0
    )

    lines = [
        "# Scaled Swarm Benchmark Report",
        "",
        "Router-enabled runtime swarm benchmark summary generated from CI matrix outputs.",
        "",
        f"- Router smoke: {'PASS' if router_smoke_passed else 'MISSING/FAIL'}",
        f"- Router metrics snapshot: {'present' if router_metrics_captured else 'missing'}",
        "",
        "| Nodes | Profile | Count | Result | Elapsed (s) | Wall (s) | Iter/s | ms/iter |",
        "| ---: | --- | ---: | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in sorted(rows, key=lambda r: (r.nodes, r.profile)):
        result = "pass" if row.passed else "fail"
        throughput = row_throughput(row)
        ms_iter = row_ms_per_iter(row)
        lines.append(
            "| {nodes} | {profile} | {count} | {result} | {elapsed:.3f} | {wall} | {throughput} | {ms_iter} |".format(
                nodes=row.nodes,
                profile=row.profile,
                count=row.count,
                result=result,
                elapsed=row.elapsed_seconds,
                wall=(f"{row.wall_seconds:.3f}" if row.wall_seconds is not None else "n/a"),
                throughput=(f"{throughput:.2f}" if throughput is not None else "n/a"),
                ms_iter=(f"{ms_iter:.3f}" if ms_iter is not None else "n/a"),
            )
        )

    throughput_by_nodes: Dict[int, List[float]] = {}
    for row in rows:
        tput = row_throughput(row)
        if tput is None:
            continue
        throughput_by_nodes.setdefault(row.nodes, []).append(tput)

    if throughput_by_nodes:
        lines.extend(
            [
                "",
                "## Throughput vs Nodes",
                "",
                "| Nodes | Mean Iter/s (profiles) |",
                "| ---: | ---: |",
            ]
        )
        for nodes in sorted(throughput_by_nodes.keys()):
            values = throughput_by_nodes[nodes]
            mean_tput = sum(values) / len(values)
            lines.append(f"| {nodes} | {mean_tput:.2f} |")

    return "\n".join(lines) + "\n"


def main() -> int:
    out_dir = Path("test-results/swarm-runtime")
    out_dir.mkdir(parents=True, exist_ok=True)

    rows: List[BenchmarkRow] = []
    for path in out_dir.glob("*_*.jsonl"):
        if not FILE_RE.search(path.name):
            continue
        rows.append(parse_jsonl(path))

    router_smoke_path = out_dir / "router_smoke.txt"
    router_metrics_path = out_dir / "router_metrics_snapshot.prom"
    router_smoke_passed = (
        router_smoke_path.exists()
        and "[router-smoke] PASS" in router_smoke_path.read_text(encoding="utf-8")
    )
    router_metrics_captured = (
        router_metrics_path.exists() and router_metrics_path.stat().st_size > 0
    )

    payload: Dict[str, object] = {
        "generated_from": "Swarm Runtime Matrix",
        "router_enabled_evidence": {
            "router_smoke_passed": router_smoke_passed,
            "router_metrics_snapshot_present": router_metrics_captured,
            "router_smoke_path": str(router_smoke_path),
            "router_metrics_snapshot_path": str(router_metrics_path),
        },
        "results": [
            {
                "nodes": row.nodes,
                "profile": row.profile,
                "count": row.count,
                "passed": row.passed,
                "elapsed_seconds": row.elapsed_seconds,
                "wall_seconds": row.wall_seconds,
                "user_seconds": row.user_seconds,
                "sys_seconds": row.sys_seconds,
                "iterations_per_second": row_throughput(row),
                "ms_per_iteration": row_ms_per_iter(row),
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
