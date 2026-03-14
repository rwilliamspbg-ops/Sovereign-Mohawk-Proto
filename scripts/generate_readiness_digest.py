#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def emoji(ok: bool) -> str:
    return "✅" if ok else "❌"


def stringify(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float, str)):
        return str(value)
    if isinstance(value, list):
        return ", ".join(str(v) for v in value)
    return json.dumps(value, sort_keys=True)


def build_readiness_section(readiness: dict) -> str:
    lines = []
    lines.append("## Readiness Gate")
    lines.append("")
    ok = bool(readiness.get("ok", False))
    lines.append(f"- Status: {emoji(ok)} {'pass' if ok else 'fail'}")

    failures = readiness.get("failures", [])
    if failures:
        lines.append("- Failures:")
        for failure in failures:
            lines.append(f"  - {failure}")
    else:
        lines.append("- Failures: none")

    checks = readiness.get("checks", {})
    lines.append("")
    lines.append("### Check Results")
    lines.append("")
    lines.append("| Check | Value |")
    lines.append("| --- | --- |")
    for check_name in sorted(checks.keys()):
        lines.append(f"| {check_name} | {stringify(checks[check_name])} |")

    return "\n".join(lines)


def load_chaos_scenarios(chaos_dir: Path) -> list[dict]:
    scenarios = []
    for summary_path in sorted(chaos_dir.glob("*-summary.json")):
        scenario = summary_path.name.replace("-summary.json", "")
        baseline_path = chaos_dir / f"{scenario}-baseline.json"
        failure_path = chaos_dir / f"{scenario}-failure.json"
        recovery_path = chaos_dir / f"{scenario}-recovery.json"

        summary = load_json(summary_path)
        baseline = load_json(baseline_path) if baseline_path.exists() else {}
        failure = load_json(failure_path) if failure_path.exists() else {}
        recovery = load_json(recovery_path) if recovery_path.exists() else {}

        scenarios.append(
            {
                "scenario": scenario,
                "baseline_ok": bool(baseline.get("ok", False)),
                "failure_ok": bool(failure.get("ok", False)),
                "recovery_ok": bool(recovery.get("ok", False)),
                "latency_seconds": summary.get("recovery_latency_seconds", "n/a"),
                "latency_threshold_seconds": summary.get("recovery_latency_threshold_seconds", "n/a"),
                "latency_ok": bool(summary.get("recovery_latency_ok", False)),
            }
        )

    return scenarios


def build_chaos_section(chaos_scenarios: list[dict]) -> str:
    lines = []
    lines.append("## Chaos Gate")
    lines.append("")

    if not chaos_scenarios:
        lines.append("- No chaos scenario reports found.")
        return "\n".join(lines)

    lines.append("| Scenario | Baseline | Outage Failure Expected | Recovery | Recovery Latency | Threshold | Latency SLO |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- |")

    for scenario in chaos_scenarios:
        baseline_mark = emoji(scenario["baseline_ok"])
        outage_expected = emoji(not scenario["failure_ok"])
        recovery_mark = emoji(scenario["recovery_ok"])
        latency_mark = emoji(scenario["latency_ok"])
        lines.append(
            "| {scenario} | {baseline} | {outage_expected} | {recovery} | {latency}s | {threshold}s | {latency_mark} |".format(
                scenario=scenario["scenario"],
                baseline=baseline_mark,
                outage_expected=outage_expected,
                recovery=recovery_mark,
                latency=scenario["latency_seconds"],
                threshold=scenario["latency_threshold_seconds"],
                latency_mark=latency_mark,
            )
        )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate markdown digest from readiness and chaos gate reports.")
    parser.add_argument("--readiness-report", required=True, help="Path to readiness-report.json")
    parser.add_argument("--chaos-dir", required=True, help="Directory containing chaos report json files")
    parser.add_argument("--output", required=True, help="Output markdown path")
    args = parser.parse_args()

    readiness_path = Path(args.readiness_report)
    chaos_dir = Path(args.chaos_dir)
    output_path = Path(args.output)

    readiness = load_json(readiness_path)
    chaos_scenarios = load_chaos_scenarios(chaos_dir)

    header = [
        "# Weekly Mainnet Readiness Digest",
        "",
        "Automated summary generated from readiness and chaos gate runs.",
        "",
    ]

    document = "\n".join(
        header
        + [
            build_readiness_section(readiness),
            "",
            build_chaos_section(chaos_scenarios),
            "",
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(document, encoding="utf-8")
    print(document)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
