#!/usr/bin/env python3
"""Demonstrate cross-silo publish/subscribe against the federated router HTTP API."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict


def _post_json(base_url: str, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    url = urllib.parse.urljoin(base_url, path)
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def _get_json(base_url: str, path: str, query: Dict[str, str]) -> Dict[str, Any]:
    query_string = urllib.parse.urlencode(query)
    url = urllib.parse.urljoin(base_url, f"{path}?{query_string}")
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a cross-silo publish/subscribe router flow over HTTP"
    )
    parser.add_argument(
        "--router-url",
        default="http://localhost:8087",
        help="Federated router base URL (default: http://localhost:8087)",
    )
    args = parser.parse_args()

    base_url = args.router_url.rstrip("/") + "/"
    offer: Dict[str, Any] = {
        "offer_id": "climate-offer-001",
        "source_vertical": "climate",
        "schema": {
            "temperature_delta": "float",
            "soil_humidity": "float",
            "rainfall_outlook_7d": "float",
        },
        "payload": {
            "temperature_delta": 0.8,
            "soil_humidity": 0.42,
            "rainfall_outlook_7d": 11.5,
        },
    }
    subscription: Dict[str, Any] = {
        "subscriber_id": "agri-analytics-001",
        "subscriber_vertical": "agriculture",
        "interested_verticals": ["climate"],
    }

    try:
        print("Publishing climate offer...")
        publish_response = _post_json(base_url, "router/publish", offer)
        print(json.dumps(publish_response, indent=2))

        print("Registering agriculture subscription...")
        subscribe_response = _post_json(base_url, "router/subscribe", subscription)
        print(json.dumps(subscribe_response, indent=2))

        print("Discovering routeable offers for agriculture...")
        discover_response = _get_json(
            base_url,
            "router/discover",
            {"subscriber_vertical": "agriculture"},
        )
        print(json.dumps(discover_response, indent=2))

        print("Recording provenance for the routed offer...")
        provenance_response = _post_json(
            base_url,
            "router/provenance",
            {
                "route": "climate->agriculture",
                "offer_id": "climate-offer-001",
                "impact_hash": "demo-impact-hash",
            },
        )
        print(json.dumps(provenance_response, indent=2))

    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP error: {exc.code} {exc.reason}")
        print(body)
        return 1
    except urllib.error.URLError as exc:
        print(f"Network error: {exc.reason}")
        print(
            "Tip: start the router first with `docker compose up -d federated-router`."
        )
        return 1

    print("Cross-silo publish/subscribe flow completed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
