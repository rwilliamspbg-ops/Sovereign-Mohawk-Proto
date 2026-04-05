#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path

REQUIRED_ATTESTATIONS = {
    "security_audit": "results/go-live/attestations/security_audit.json",
    "penetration_test": "results/go-live/attestations/penetration_test.json",
    "threat_model_refresh": "results/go-live/attestations/threat_model_refresh.json",
    "dependency_sla_baseline": "results/go-live/attestations/dependency_sla_baseline.json",
    "fips_evidence_bundle": "results/go-live/attestations/fips_evidence_bundle.json",
    "backup_restore_drill": "results/go-live/attestations/backup_restore_drill.json",
    "soak_scale_rehearsal": "results/go-live/attestations/soak_scale_rehearsal.json",
    "incident_escalation_drill": "results/go-live/attestations/incident_escalation_drill.json",
    "runbook_published": "results/go-live/attestations/runbook_published.json",
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def check_readiness(
    repo_root: Path, failures: list[str], checks: dict[str, bool]
) -> None:
    path = repo_root / "results/readiness/readiness-report.json"
    if not path.exists():
        failures.append(f"missing readiness report: {path}")
        checks["readiness_report_ok"] = False
        return
    try:
        payload = load_json(path)
    except Exception as exc:  # noqa: BLE001
        failures.append(f"invalid readiness report json: {exc}")
        checks["readiness_report_ok"] = False
        return
    ok = bool(payload.get("ok", False))
    checks["readiness_report_ok"] = ok
    if not ok:
        failures.append("readiness report indicates non-passing state")


def check_chaos(repo_root: Path, failures: list[str], checks: dict[str, bool]) -> None:
    path = repo_root / "chaos-reports/tpm-metrics-summary.json"
    if not path.exists():
        failures.append(f"missing chaos summary: {path}")
        checks["chaos_summary_ok"] = False
        return
    try:
        payload = load_json(path)
    except Exception as exc:  # noqa: BLE001
        failures.append(f"invalid chaos summary json: {exc}")
        checks["chaos_summary_ok"] = False
        return
    ok = bool(payload.get("recovery_latency_ok", False))
    checks["chaos_summary_ok"] = ok
    if not ok:
        failures.append("chaos summary indicates recovery latency SLO failure")


def check_host_tuning(
    repo_root: Path,
    failures: list[str],
    checks: dict[str, bool],
    mode: str,
    warnings: list[str],
) -> None:
    script = repo_root / "scripts/validate_host_network_tuning.sh"
    if not script.exists():
        message = f"missing host tuning script: {script}"
        if mode == "advisory":
            warnings.append(message)
            checks["host_network_tuning_ok"] = False
            checks["host_network_tuning_enforced"] = False
            return
        failures.append(message)
        checks["host_network_tuning_ok"] = False
        checks["host_network_tuning_enforced"] = True
        return

    proc = subprocess.run(
        ["bash", str(script)],
        cwd=str(repo_root),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    ok = proc.returncode == 0
    checks["host_network_tuning_ok"] = ok
    checks["host_network_tuning_enforced"] = mode == "strict"
    if not ok:
        message = "host UDP/sysctl tuning preflight failed"
        if mode == "advisory":
            warnings.append(message)
        else:
            failures.append(message)


def check_attestations(
    repo_root: Path, failures: list[str], checks: dict[str, bool]
) -> None:
    all_ok = True
    for gate_name, rel_path in REQUIRED_ATTESTATIONS.items():
        path = repo_root / rel_path
        key = f"attestation_{gate_name}_approved"
        if not path.exists():
            checks[key] = False
            all_ok = False
            failures.append(f"missing attestation file: {path}")
            continue
        try:
            payload = load_json(path)
        except Exception as exc:  # noqa: BLE001
            checks[key] = False
            all_ok = False
            failures.append(f"invalid attestation json ({gate_name}): {exc}")
            continue

        status = str(payload.get("status", "")).strip().lower()
        approved = status == "approved"
        checks[key] = approved
        if not approved:
            all_ok = False
            failures.append(
                f"attestation not approved ({gate_name}): status={status or 'missing'}"
            )

    checks["all_attestations_approved"] = all_ok


def check_capability_dashboard_matrix(
    repo_root: Path, failures: list[str], checks: dict[str, bool]
) -> None:
    path = repo_root / "results/go-live/capability_dashboard_matrix.md"
    exists = path.exists()
    checks["capability_dashboard_matrix_present"] = exists
    if not exists:
        failures.append(f"missing capability-to-dashboard matrix artifact: {path}")


def write_report(repo_root: Path, report: dict) -> Path:
    out = repo_root / "results/go-live/go-live-gate-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate formal go-live gates for production readiness."
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root directory",
    )
    parser.add_argument(
        "--host-preflight-mode",
        choices=["strict", "advisory"],
        default="strict",
        help="Host network preflight mode. strict fails the gate; advisory records warning only.",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    failures: list[str] = []
    warnings: list[str] = []
    checks: dict[str, bool] = {}

    check_readiness(repo_root, failures, checks)
    check_chaos(repo_root, failures, checks)
    check_host_tuning(repo_root, failures, checks, args.host_preflight_mode, warnings)
    check_attestations(repo_root, failures, checks)
    check_capability_dashboard_matrix(repo_root, failures, checks)

    ok = len(failures) == 0
    report = {
        "ok": ok,
        "host_preflight_mode": args.host_preflight_mode,
        "checks": checks,
        "warnings": warnings,
        "failures": failures,
    }
    out = write_report(repo_root, report)

    print(json.dumps(report, indent=2, sort_keys=True))
    print(f"report_path={out}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
