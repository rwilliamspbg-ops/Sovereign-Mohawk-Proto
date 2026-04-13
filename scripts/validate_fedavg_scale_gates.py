#!/usr/bin/env python3
"""Validate FedAvg scale performance gates from swarm runtime and metric snapshots."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Dict, Tuple


LINE_RE = re.compile(r"^(?P<name>[a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{[^}]*\})?\s+(?P<value>-?[0-9]+(?:\.[0-9]+)?)$")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_prom_totals(path: Path) -> Dict[str, float]:
    totals: Dict[str, float] = {}
    if not path.exists():
        return totals

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = LINE_RE.match(line)
        if not match:
            continue
        name = match.group("name")
        value = float(match.group("value"))
        totals[name] = totals.get(name, 0.0) + value
    return totals


def gate_eval(rows: list[dict], min_throughput: float, min_count_for_floor: int) -> Tuple[bool, list[str], dict]:
    failures: list[str] = []
    checks: dict = {}

    checks["rows_present"] = len(rows) > 0
    if not rows:
        failures.append("no runtime result rows found")
        return False, failures, checks

    all_pass = all(bool(r.get("passed")) for r in rows)
    checks["all_profiles_passed"] = all_pass
    if not all_pass:
        failures.append("one or more runtime profiles failed")

    eligible_rows = [r for r in rows if int(r.get("count", 0)) >= min_count_for_floor]
    checks["throughput_floor_sample_rows_present"] = len(eligible_rows) > 0
    if not eligible_rows:
        failures.append(
            f"no rows meet minimum count for throughput floor evaluation (count>={min_count_for_floor})"
        )

    throughputs = [
        r.get("iterations_per_second") for r in eligible_rows if r.get("iterations_per_second")
    ]
    has_throughput = len(throughputs) > 0
    checks["throughput_available"] = has_throughput
    if not has_throughput:
        failures.append("no timing-derived throughput values available")

    meets_floor = has_throughput and min(throughputs) >= min_throughput
    checks["throughput_floor_met"] = meets_floor
    if has_throughput and not meets_floor:
        failures.append(
            f"throughput floor not met: min={min(throughputs):.2f} iter/s required>={min_throughput:.2f}"
        )

    return len(failures) == 0, failures, checks


def prom_diff(pre: Path, post: Path) -> dict:
    pre_totals = load_prom_totals(pre)
    post_totals = load_prom_totals(post)

    keys = [
        "mohawk_bridge_settlements_total",
        "mohawk_bridge_transfers_total",
        "mohawk_proof_verifications_total",
        "mohawk_fedavg_gradients_received_total",
        "mohawk_fedavg_gradients_aggregated_total",
    ]

    deltas = {}
    for key in keys:
        deltas[key] = {
            "pre": pre_totals.get(key, 0.0),
            "post": post_totals.get(key, 0.0),
            "delta": post_totals.get(key, 0.0) - pre_totals.get(key, 0.0),
        }
    return deltas


def render_markdown(report: dict) -> str:
    lines = [
        "# FedAvg Scale Gate Validation",
        "",
        f"- Generated (UTC): `{report['generated_utc']}`",
        f"- Overall status: `{'PASS' if report['ok'] else 'FAIL'}`",
        f"- Runtime report: `{report['runtime_report']}`",
        f"- Min throughput gate (iter/s): `{report['throughput_floor_iter_per_sec']}`",
        "",
        "## Gate Checks",
        "",
    ]

    for key, value in report["checks"].items():
        lines.append(f"- `{key}`: {'PASS' if value else 'FAIL'}")

    lines.extend(["", "## Failures", ""])
    if report["failures"]:
        for failure in report["failures"]:
            lines.append(f"- {failure}")
    else:
        lines.append("- none")

    lines.extend(["", "## Counter Deltas (Pre/Post)", "", "| Metric | Pre | Post | Delta |", "| --- | ---: | ---: | ---: |"])
    for metric, values in report["counter_deltas"].items():
        lines.append(
            f"| `{metric}` | {values['pre']:.3f} | {values['post']:.3f} | {values['delta']:.3f} |"
        )

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate FedAvg scaling gates from runtime artifacts.")
    parser.add_argument(
        "--runtime-report",
        default="test-results/swarm-runtime/scaled_swarm_benchmark_report.json",
        help="Swarm runtime benchmark JSON report path.",
    )
    parser.add_argument(
        "--pre-prom",
        default="captured_artifacts/router_metrics_pre_stress_2026-04-13.prom",
        help="Pre-run Prometheus snapshot path.",
    )
    parser.add_argument(
        "--post-prom",
        default="captured_artifacts/router_metrics_post_stress_2026-04-13.prom",
        help="Post-run Prometheus snapshot path.",
    )
    parser.add_argument(
        "--min-throughput-iter-per-sec",
        type=float,
        default=100.0,
        help="Minimum per-profile iteration throughput requirement.",
    )
    parser.add_argument(
        "--min-count-for-floor",
        type=int,
        default=50,
        help="Minimum row count required to enforce throughput floor checks.",
    )
    parser.add_argument(
        "--output-json",
        default="results/metrics/fedavg_scale_gate_validation.json",
        help="Output JSON path.",
    )
    parser.add_argument(
        "--output-md",
        default="results/metrics/fedavg_scale_gate_validation.md",
        help="Output Markdown path.",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    runtime_report_path = repo_root / args.runtime_report
    pre_prom = repo_root / args.pre_prom
    post_prom = repo_root / args.post_prom

    payload = load_json(runtime_report_path)
    rows = payload.get("results", [])

    ok, failures, checks = gate_eval(rows, args.min_throughput_iter_per_sec, args.min_count_for_floor)
    deltas = prom_diff(pre_prom, post_prom)

    report = {
        "generated_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "ok": ok,
        "runtime_report": args.runtime_report,
        "throughput_floor_iter_per_sec": args.min_throughput_iter_per_sec,
        "min_count_for_floor": args.min_count_for_floor,
        "checks": checks,
        "failures": failures,
        "counter_deltas": deltas,
        "pre_prom_path": args.pre_prom,
        "post_prom_path": args.post_prom,
    }

    out_json = repo_root / args.output_json
    out_md = repo_root / args.output_md
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    out_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    out_md.write_text(render_markdown(report), encoding="utf-8")

    print(f"wrote {out_json}")
    print(f"wrote {out_md}")
    print("status=PASS" if report["ok"] else "status=FAIL")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
