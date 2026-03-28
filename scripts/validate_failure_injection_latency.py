#!/usr/bin/env python3
"""Validate failure-injection latency outcomes against the versioned SLO baseline."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_report(repo_root: Path, readiness_path: Path, chaos_dir: Path, slo_path: Path) -> dict:
    readiness = _load_json(repo_root / readiness_path)
    slo = _load_json(repo_root / slo_path)

    thresholds = slo["slo_targets"]["recovery_latency_threshold_seconds"]
    default_threshold = int(thresholds.get("default", 120))
    scenario_thresholds = thresholds.get("scenarios", {})

    scenarios = []
    failures = []

    for summary_path in sorted((repo_root / chaos_dir).glob("*-summary.json")):
        payload = _load_json(summary_path)
        scenario = str(payload.get("scenario", summary_path.stem.replace("-summary", "")))
        latency = int(payload.get("recovery_latency_seconds", 0))
        threshold = int(scenario_thresholds.get(scenario, default_threshold))
        gate_ok = bool(payload.get("recovery_latency_ok", False))
        threshold_ok = latency <= threshold
        ok = gate_ok and threshold_ok
        if not ok:
            failures.append(
                f"{scenario}: latency={latency}s threshold={threshold}s gate_ok={gate_ok}"
            )

        scenarios.append(
            {
                "scenario": scenario,
                "latency_seconds": latency,
                "threshold_seconds": threshold,
                "gate_reported_ok": gate_ok,
                "threshold_ok": threshold_ok,
                "ok": ok,
                "artifact": str(summary_path.relative_to(repo_root)).replace("\\", "/"),
            }
        )

    readiness_ok = bool(readiness.get("ok", False))
    if not readiness_ok:
        failures.append("readiness gate reported ok=false")

    report = {
        "generated_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "baseline_version": str(slo.get("version", "unknown")),
        "readiness_report": str(readiness_path).replace("\\", "/"),
        "slo_baseline": str(slo_path).replace("\\", "/"),
        "checks": {
            "readiness_gate_ok": readiness_ok,
            "chaos_scenarios_found": len(scenarios) > 0,
            "all_scenarios_within_threshold": all(s["ok"] for s in scenarios) if scenarios else False,
        },
        "scenarios": scenarios,
        "failures": failures,
    }
    report["ok"] = (
        report["checks"]["readiness_gate_ok"]
        and report["checks"]["chaos_scenarios_found"]
        and report["checks"]["all_scenarios_within_threshold"]
    )
    return report


def render_markdown(report: dict) -> str:
    lines = [
        "# Failure-Injection Latency Validation (2026-03-28)",
        "",
        f"- Generated (UTC): `{report['generated_utc']}`",
        f"- Baseline version: `{report['baseline_version']}`",
        f"- Overall result: `{'PASS' if report['ok'] else 'FAIL'}`",
        "",
        "## Scenario Results",
        "",
        "| Scenario | Latency | Threshold | Gate OK | Threshold OK | Overall | Artifact |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for scenario in report["scenarios"]:
        lines.append(
            "| {scenario} | {latency}s | {threshold}s | {gate} | {threshold_ok} | {overall} | `{artifact}` |".format(
                scenario=scenario["scenario"],
                latency=scenario["latency_seconds"],
                threshold=scenario["threshold_seconds"],
                gate="yes" if scenario["gate_reported_ok"] else "no",
                threshold_ok="yes" if scenario["threshold_ok"] else "no",
                overall="PASS" if scenario["ok"] else "FAIL",
                artifact=scenario["artifact"],
            )
        )

    lines.extend(["", "## Gate Checks", ""])
    for name, value in report["checks"].items():
        lines.append(f"- `{name}`: {'PASS' if value else 'FAIL'}")

    lines.extend(["", "## Failures", ""])
    if report["failures"]:
        for failure in report["failures"]:
            lines.append(f"- {failure}")
    else:
        lines.append("- none")

    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate failure-injection latency artifacts against SLO thresholds."
    )
    parser.add_argument(
        "--readiness-report",
        default="results/readiness/readiness-report.json",
        help="Path to readiness report JSON (relative to repo root).",
    )
    parser.add_argument(
        "--chaos-dir",
        default="chaos-reports",
        help="Directory containing *-summary.json chaos artifacts (relative to repo root).",
    )
    parser.add_argument(
        "--slo-baseline",
        default="results/go-live/evidence/slo_sli_baseline_2026-03-28.json",
        help="Path to SLO baseline JSON (relative to repo root).",
    )
    parser.add_argument(
        "--output-json",
        default="results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json",
        help="Output JSON report path (relative to repo root).",
    )
    parser.add_argument(
        "--output-md",
        default="results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md",
        help="Output Markdown report path (relative to repo root).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]

    readiness_path = Path(args.readiness_report)
    chaos_dir = Path(args.chaos_dir)
    slo_path = Path(args.slo_baseline)
    out_json = repo_root / Path(args.output_json)
    out_md = repo_root / Path(args.output_md)

    report = build_report(repo_root, readiness_path, chaos_dir, slo_path)

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
