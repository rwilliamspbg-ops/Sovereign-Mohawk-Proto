#!/usr/bin/env python3
import argparse
import json
import math
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


def fetch_json(url: str, timeout: float = 5.0) -> dict:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        data = response.read().decode("utf-8")
    return json.loads(data)


def wait_json(url: str, expect_key: str, retries: int, delay_seconds: float) -> dict:
    last_error = ""
    for _ in range(retries):
        try:
            payload = fetch_json(url)
            if expect_key in payload:
                return payload
            last_error = f"missing key '{expect_key}'"
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)
        time.sleep(delay_seconds)
    raise RuntimeError(f"failed to fetch {url}: {last_error}")


def query_vector(prom_url: str, expr: str) -> list[dict]:
    query = urllib.parse.quote(expr, safe="")
    payload = fetch_json(f"{prom_url}/api/v1/query?query={query}")
    if payload.get("status") != "success":
        raise RuntimeError(f"prometheus query failed: {expr}")
    data = payload.get("data", {})
    if data.get("resultType") != "vector":
        raise RuntimeError(
            f"unexpected result type for {expr}: {data.get('resultType')}"
        )
    return data.get("result", [])


def query_scalar_value(
    prom_url: str, expr: str, default_if_empty: float | None = None
) -> float:
    result = query_vector(prom_url, expr)
    if not result:
        if default_if_empty is not None:
            return default_if_empty
        raise RuntimeError(f"metric not present yet for query: {expr}")
    value = result[0].get("value")
    if not isinstance(value, list) or len(value) != 2:
        raise RuntimeError(f"malformed value for query: {expr}")
    return float(value[1])


def check_targets(prom_url: str, required_instances: list[str]) -> list[str]:
    payload = fetch_json(f"{prom_url}/api/v1/targets")
    active = payload.get("data", {}).get("activeTargets", [])
    healthy = {
        target.get("labels", {}).get("instance")
        for target in active
        if target.get("health") == "up"
    }
    failures = []
    for instance in required_instances:
        if instance not in healthy:
            failures.append(f"target not healthy: {instance}")
    return failures


def check_metric_names(prom_url: str, required_metrics: list[str]) -> list[str]:
    payload = fetch_json(f"{prom_url}/api/v1/label/__name__/values")
    names = set(payload.get("data", []))
    failures = []
    for metric_name in required_metrics:
        if metric_name not in names:
            failures.append(f"metric missing: {metric_name}")
    return failures


def wait_target_health(
    prom_url: str, required_instances: list[str], retries: int, delay_seconds: float
) -> list[str]:
    last_failures: list[str] = []
    for _ in range(retries):
        try:
            last_failures = check_targets(prom_url, required_instances)
        except Exception as exc:  # noqa: BLE001
            last_failures = [str(exc)]
        if not last_failures:
            return []
        time.sleep(delay_seconds)
    return last_failures


def wait_metric_names(
    prom_url: str, required_metrics: list[str], retries: int, delay_seconds: float
) -> list[str]:
    last_failures: list[str] = []
    for _ in range(retries):
        try:
            last_failures = check_metric_names(prom_url, required_metrics)
        except Exception as exc:  # noqa: BLE001
            last_failures = [str(exc)]
        if not last_failures:
            return []
        time.sleep(delay_seconds)
    return last_failures


def wait_query_scalar_value(
    prom_url: str,
    expr: str,
    default_if_empty: float | None,
    retries: int,
    delay_seconds: float,
) -> float:
    last_error = ""
    for _ in range(retries):
        try:
            return query_scalar_value(prom_url, expr, default_if_empty=default_if_empty)
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)
            time.sleep(delay_seconds)
    raise RuntimeError(f"failed to query {expr}: {last_error}")


def check_supply_invariant(
    prom_url: str, tolerance: float, retries: int, delay_seconds: float
) -> list[str]:
    minted = wait_query_scalar_value(
        prom_url,
        "mohawk_utility_coin_minted_amount_total",
        default_if_empty=0.0,
        retries=retries,
        delay_seconds=delay_seconds,
    )
    burned = wait_query_scalar_value(
        prom_url,
        "mohawk_utility_coin_burned_amount_total",
        default_if_empty=0.0,
        retries=retries,
        delay_seconds=delay_seconds,
    )
    supply = wait_query_scalar_value(
        prom_url,
        "mohawk_utility_coin_total_supply",
        default_if_empty=0.0,
        retries=retries,
        delay_seconds=delay_seconds,
    )

    expected = minted - burned
    if not math.isfinite(supply):
        return ["total supply is not finite"]
    if supply < 0:
        return [f"total supply is negative: {supply}"]

    delta = abs(supply - expected)
    if delta > tolerance:
        return [
            (
                "supply invariant failed: "
                f"total_supply={supply}, minted={minted}, burned={burned}, "
                f"expected={expected}, delta={delta}, tolerance={tolerance}"
            )
        ]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Mainnet readiness gate checks for monitoring and tokenomics invariants."
    )
    parser.add_argument(
        "--prom-url", default="http://localhost:9090", help="Prometheus base URL"
    )
    parser.add_argument(
        "--grafana-url", default="http://localhost:3000", help="Grafana base URL"
    )
    parser.add_argument(
        "--tpm-metrics-url",
        default="http://localhost:9102",
        help="TPM metrics exporter base URL",
    )
    parser.add_argument(
        "--expected-attestation-signature-mode",
        default="xmss",
        help="Required attestation signature mode reported by TPM metrics health endpoint",
    )
    parser.add_argument(
        "--retries", type=int, default=30, help="Number of retries per readiness wait"
    )
    parser.add_argument(
        "--delay", type=float, default=2.0, help="Delay between retries in seconds"
    )
    parser.add_argument(
        "--supply-tolerance",
        type=float,
        default=1e-6,
        help="Absolute tolerance for supply invariant: total_supply ~= minted-burned",
    )
    parser.add_argument(
        "--min-bridge-transfers",
        type=float,
        default=1.0,
        help="Minimum required sum(mohawk_bridge_transfers_total) for readiness pass",
    )
    parser.add_argument(
        "--min-proof-verifications",
        type=float,
        default=1.0,
        help="Minimum required sum(mohawk_proof_verifications_total) for readiness pass",
    )
    parser.add_argument(
        "--min-hybrid-verifications",
        type=float,
        default=1.0,
        help='Minimum required sum(mohawk_proof_verifications_total{scheme="hybrid"}) for readiness pass',
    )
    parser.add_argument(
        "--min-accelerator-ops",
        type=float,
        default=1.0,
        help="Minimum required sum(mohawk_accelerator_ops_total) for readiness pass",
    )
    parser.add_argument(
        "--min-gradient-compression-observations",
        type=float,
        default=1.0,
        help="Minimum required sum(mohawk_gradient_compression_ratio_count) for readiness pass",
    )
    args = parser.parse_args()

    report: dict[str, object] = {
        "ok": False,
        "checks": {},
        "failures": [],
    }

    failures: list[str] = []

    try:
        grafana_health = wait_json(
            f"{args.grafana_url}/api/health",
            expect_key="database",
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["grafana_health"] = grafana_health.get("database") == "ok"
        if not report["checks"]["grafana_health"]:
            failures.append(f"grafana database not ok: {grafana_health}")

        tpm_health = wait_json(
            f"{args.tpm_metrics_url}/healthz",
            expect_key="status",
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["tpm_health"] = tpm_health.get("status") == "ok"
        if not report["checks"]["tpm_health"]:
            failures.append(f"tpm health not ok: {tpm_health}")
        expected_mode = str(args.expected_attestation_signature_mode).strip().lower()
        actual_mode = (
            str(tpm_health.get("attestation_signature_mode", "")).strip().lower()
        )
        report["checks"]["tpm_attestation_signature_mode"] = (
            actual_mode == expected_mode
        )
        if actual_mode != expected_mode:
            failures.append(
                "tpm attestation signature mode mismatch: "
                f"expected={expected_mode}, got={actual_mode or 'missing'}"
            )

        _ = wait_json(
            f"{args.prom_url}/api/v1/targets",
            expect_key="status",
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["prometheus_api"] = True

        target_failures = wait_target_health(
            args.prom_url,
            required_instances=[
                "orchestrator:9091",
                "tpm-metrics:9102",
                "pyapi-metrics-exporter:9104",
            ],
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["targets_up"] = len(target_failures) == 0
        failures.extend(target_failures)

        metric_failures = wait_metric_names(
            args.prom_url,
            required_metrics=[
                "mohawk_utility_coin_total_supply",
                "mohawk_utility_coin_minted_amount_total",
                "mohawk_utility_coin_burned_amount_total",
                "mohawk_utility_coin_tx_count",
                "mohawk_utility_coin_holders_count",
                "mohawk_bridge_transfers_total",
                "mohawk_proof_verifications_total",
                "mohawk_accelerator_ops_total",
                "mohawk_gradient_compression_ratio_count",
            ],
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["metric_names_present"] = len(metric_failures) == 0
        failures.extend(metric_failures)

        bridge_transfer_total = wait_query_scalar_value(
            args.prom_url,
            "sum(mohawk_bridge_transfers_total)",
            default_if_empty=None,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["bridge_transfers_series_present"] = True
        report["checks"]["bridge_transfers_non_negative"] = bridge_transfer_total >= 0
        if bridge_transfer_total < 0:
            failures.append(
                f"bridge transfers counter negative: {bridge_transfer_total}"
            )
        report["checks"]["bridge_transfers_min_activity"] = (
            bridge_transfer_total >= args.min_bridge_transfers
        )
        if bridge_transfer_total < args.min_bridge_transfers:
            failures.append(
                "bridge transfer activity below minimum: "
                f"total={bridge_transfer_total}, min={args.min_bridge_transfers}"
            )

        proof_verification_total = wait_query_scalar_value(
            args.prom_url,
            "sum(mohawk_proof_verifications_total)",
            default_if_empty=None,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["proof_verifications_series_present"] = True
        report["checks"]["proof_verifications_non_negative"] = (
            proof_verification_total >= 0
        )
        if proof_verification_total < 0:
            failures.append(
                f"proof verifications counter negative: {proof_verification_total}"
            )
        report["checks"]["proof_verifications_min_activity"] = (
            proof_verification_total >= args.min_proof_verifications
        )
        if proof_verification_total < args.min_proof_verifications:
            failures.append(
                "proof verification activity below minimum: "
                f"total={proof_verification_total}, min={args.min_proof_verifications}"
            )

        hybrid_proof_total = wait_query_scalar_value(
            args.prom_url,
            'sum(mohawk_proof_verifications_total{scheme="hybrid"})',
            default_if_empty=None,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["hybrid_proof_series_present"] = True
        report["checks"]["hybrid_proof_non_negative"] = hybrid_proof_total >= 0
        if hybrid_proof_total < 0:
            failures.append(f"hybrid proof counter negative: {hybrid_proof_total}")
        report["checks"]["hybrid_proof_min_activity"] = (
            hybrid_proof_total >= args.min_hybrid_verifications
        )
        if hybrid_proof_total < args.min_hybrid_verifications:
            failures.append(
                "hybrid proof activity below minimum: "
                f"total={hybrid_proof_total}, min={args.min_hybrid_verifications}"
            )

        accelerator_ops_total = wait_query_scalar_value(
            args.prom_url,
            "sum(mohawk_accelerator_ops_total)",
            default_if_empty=None,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["accelerator_ops_series_present"] = True
        report["checks"]["accelerator_ops_non_negative"] = accelerator_ops_total >= 0
        if accelerator_ops_total < 0:
            failures.append(
                f"accelerator ops counter negative: {accelerator_ops_total}"
            )
        report["checks"]["accelerator_ops_min_activity"] = (
            accelerator_ops_total >= args.min_accelerator_ops
        )
        if accelerator_ops_total < args.min_accelerator_ops:
            failures.append(
                "accelerator ops activity below minimum: "
                f"total={accelerator_ops_total}, min={args.min_accelerator_ops}"
            )

        gradient_compression_count = wait_query_scalar_value(
            args.prom_url,
            "sum(mohawk_gradient_compression_ratio_count)",
            default_if_empty=None,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["gradient_compression_series_present"] = True
        report["checks"]["gradient_compression_non_negative"] = (
            gradient_compression_count >= 0
        )
        if gradient_compression_count < 0:
            failures.append(
                "gradient compression observation count negative: "
                f"{gradient_compression_count}"
            )
        report["checks"]["gradient_compression_min_activity"] = (
            gradient_compression_count >= args.min_gradient_compression_observations
        )
        if gradient_compression_count < args.min_gradient_compression_observations:
            failures.append(
                "gradient compression activity below minimum: "
                f"total={gradient_compression_count}, min={args.min_gradient_compression_observations}"
            )

        invariant_failures = check_supply_invariant(
            args.prom_url,
            args.supply_tolerance,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["supply_invariant"] = len(invariant_failures) == 0
        failures.extend(invariant_failures)

        tx_count = wait_query_scalar_value(
            args.prom_url,
            "mohawk_utility_coin_tx_count",
            default_if_empty=0.0,
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["tx_count_non_negative"] = tx_count >= 0
        if tx_count < 0:
            failures.append(f"tx count negative: {tx_count}")

    except Exception as exc:  # noqa: BLE001
        failures.append(str(exc))

    report["failures"] = failures
    report["ok"] = len(failures) == 0

    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
