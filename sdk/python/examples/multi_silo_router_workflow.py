#!/usr/bin/env python3
"""Run a concrete multi-silo cross-vertical routing workflow via the Python SDK."""

from __future__ import annotations

import argparse
import json
import secrets
from typing import Dict, List

from mohawk import MohawkNode


def _fake_quote() -> bytes:
    # Dev/demo-only quote payload placeholder. Production should use real TPM quote bytes.
    return secrets.token_bytes(48)


def _print_block(title: str, payload: Dict) -> None:
    print(f"\n=== {title} ===")
    print(json.dumps(payload, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description="Run multi-silo router workflow demo")
    parser.add_argument(
        "--router-url",
        default="http://localhost:8087",
        help="Federated router URL (default: http://localhost:8087)",
    )
    args = parser.parse_args()

    with MohawkNode() as node:
        router_url = args.router_url

        offer_climate = node.router_publish_insight(
            source_vertical="climate",
            model_id="climate-risk-v3",
            summary="Rainfall volatility and soil-moisture forecast for harvest planning.",
            publisher_node_id="climate-node-001",
            publisher_quote=_fake_quote(),
            offer_id="climate-offer-001",
            router_url=router_url,
        )
        _print_block("Published Climate Offer", offer_climate)

        offer_oncology = node.router_publish_insight(
            source_vertical="oncology",
            model_id="oncology-inference-v2",
            summary="Drug-response surrogate model for cold-chain prioritization.",
            publisher_node_id="oncology-node-001",
            publisher_quote=_fake_quote(),
            offer_id="oncology-offer-001",
            router_url=router_url,
        )
        _print_block("Published Oncology Offer", offer_oncology)

        node.router_subscribe(
            subscriber_vertical="supply-chain",
            source_verticals=["climate", "oncology"],
            subscriber_node_id="supply-node-001",
            subscriber_quote=_fake_quote(),
            router_url=router_url,
        )

        discover_supply = node.router_discover(
            subscriber_vertical="supply-chain",
            router_url=router_url,
        )
        _print_block("Supply-Chain Discover", discover_supply)

        offers: List[Dict] = discover_supply.get("data", [])
        if offers:
            first = offers[0]
            node.router_append_provenance(
                offer_id=first.get("offer_id", "unknown-offer"),
                source_vertical=first.get("source_vertical", "unknown"),
                target_vertical="supply-chain",
                subscriber_model="inventory-optimizer-v5",
                impact_metric="forecast_error_reduction",
                impact_delta=0.18,
                router_url=router_url,
            )

        provenance = node.router_provenance(router_url=router_url)
        _print_block("Provenance Ledger", provenance)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
