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
        except (urllib.error.URLError, json.JSONDecodeError) as exc:
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
        raise RuntimeError(f"unexpected result type for {expr}: {data.get('resultType')}")
    return data.get("result", [])


def query_scalar_value(prom_url: str, expr: str) -> float:
    result = query_vector(prom_url, expr)
    if not result:
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


def check_supply_invariant(prom_url: str, tolerance: float) -> list[str]:
    minted = query_scalar_value(prom_url, "mohawk_utility_coin_minted_amount_total")
    burned = query_scalar_value(prom_url, "mohawk_utility_coin_burned_amount_total")
    supply = query_scalar_value(prom_url, "mohawk_utility_coin_total_supply")

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
    parser.add_argument("--prom-url", default="http://localhost:9090", help="Prometheus base URL")
    parser.add_argument("--grafana-url", default="http://localhost:3000", help="Grafana base URL")
    parser.add_argument("--retries", type=int, default=30, help="Number of retries per readiness wait")
    parser.add_argument("--delay", type=float, default=2.0, help="Delay between retries in seconds")
    parser.add_argument(
        "--supply-tolerance",
        type=float,
        default=1e-6,
        help="Absolute tolerance for supply invariant: total_supply ~= minted-burned",
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

        _ = wait_json(
            f"{args.prom_url}/api/v1/targets",
            expect_key="status",
            retries=args.retries,
            delay_seconds=args.delay,
        )
        report["checks"]["prometheus_api"] = True

        target_failures = check_targets(
            args.prom_url,
            required_instances=["orchestrator:9091", "tpm-metrics:9102"],
        )
        report["checks"]["targets_up"] = len(target_failures) == 0
        failures.extend(target_failures)

        metric_failures = check_metric_names(
            args.prom_url,
            required_metrics=[
                "mohawk_utility_coin_total_supply",
                "mohawk_utility_coin_minted_amount_total",
                "mohawk_utility_coin_burned_amount_total",
                "mohawk_utility_coin_tx_count",
                "mohawk_utility_coin_holders_count",
            ],
        )
        report["checks"]["metric_names_present"] = len(metric_failures) == 0
        failures.extend(metric_failures)

        optional_metric_failures = check_metric_names(
            args.prom_url,
            required_metrics=[
                "mohawk_bridge_transfers_total",
                "mohawk_proof_verifications_total",
            ],
        )
        report["checks"]["optional_protocol_metrics_present"] = len(optional_metric_failures) == 0
        report["checks"]["optional_protocol_metrics_missing"] = [
            failure.replace("metric missing: ", "") for failure in optional_metric_failures
        ]

        invariant_failures = check_supply_invariant(args.prom_url, args.supply_tolerance)
        report["checks"]["supply_invariant"] = len(invariant_failures) == 0
        failures.extend(invariant_failures)

        tx_count = query_scalar_value(args.prom_url, "mohawk_utility_coin_tx_count")
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
