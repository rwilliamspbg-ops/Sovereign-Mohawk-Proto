#!/usr/bin/env python3
"""Minimal demo for digest-first PQC migration API flow.

This script targets the orchestrator HTTP API:
1) Request canonical migration digest
2) Show payload for cryptographic migration submit

It does not generate real signatures; operators should inject signatures from their
approved signing systems before POSTing /ledger/migration/migrate.
"""

from __future__ import annotations

import json
import os
import ssl
import urllib.error
import urllib.request

ORCH_URL = os.getenv("MOHAWK_ORCHESTRATOR_URL", "https://localhost:8080")
API_TOKEN = os.getenv("MOHAWK_API_TOKEN", "")


def _post_json(path: str, payload: dict) -> dict:
    url = f"{ORCH_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if API_TOKEN:
        headers["Authorization"] = f"Bearer {API_TOKEN}"

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    # Local demo environments commonly use self-signed certs.
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    digest_req = {
        "legacy_account": "legacy-edge",
        "pqc_account": "mldsa-edge",
        "amount": 2.5,
        "memo": "migration-demo",
        "idempotency_key": "demo-migration-001",
        "nonce": 101,
    }

    try:
        digest_resp = _post_json("/ledger/migration/digest", digest_req)
    except urllib.error.URLError as exc:
        print(f"digest request failed: {exc}")
        return 1

    print("Digest response:")
    print(json.dumps(digest_resp, indent=2))

    migrate_payload = {
        **digest_req,
        "legacy_algo": "ecdsa-p256-sha256",
        "legacy_pub_key": "<base64-or-pem>",
        "legacy_sig": "<base64-or-hex-or-pem>",
        "pqc_algo": "ml-dsa-65",
        "pqc_pub_key": "<base64-or-pem>",
        "pqc_sig": "<base64-or-hex-or-pem>",
    }

    print("\nSubmit this payload after signatures are generated:")
    print(json.dumps(migrate_payload, indent=2))
    print("\nEndpoint: POST /ledger/migration/migrate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
