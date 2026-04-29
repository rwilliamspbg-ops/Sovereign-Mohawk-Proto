#!/usr/bin/env python3
"""Build dual-signature migration payloads for epoch-based PQC cutover."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Dict


def _read_text(path: str | None) -> str | None:
    if not path:
        return None
    return Path(path).read_text(encoding="utf-8").strip()


def _canonical_json(payload: Dict[str, Any]) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


def build_signing_payload(args: argparse.Namespace) -> Dict[str, Any]:
    return {
        "legacy_account": args.legacy_account,
        "pqc_account": args.pqc_account,
        "asset": args.asset,
        "amount_units": args.amount_units,
        "memo": args.memo,
        "idempotency_key": args.idempotency_key,
        "nonce": args.nonce,
    }


def build_dual_signature_payload(args: argparse.Namespace) -> Dict[str, Any]:
    signing_payload = build_signing_payload(args)
    canonical = _canonical_json(signing_payload)
    digest_hex = hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    legacy_sig = args.legacy_sig or _read_text(args.legacy_sig_file)
    pqc_sig = args.pqc_sig or _read_text(args.pqc_sig_file)
    legacy_pub_key = args.legacy_pub_key or _read_text(args.legacy_pub_key_file)
    pqc_pub_key = args.pqc_pub_key or _read_text(args.pqc_pub_key_file)

    payload: Dict[str, Any] = {
        **signing_payload,
        "digest_hex": digest_hex,
        "legacy_algo": args.legacy_algo,
        "legacy_pub_key": legacy_pub_key,
        "legacy_sig": legacy_sig,
        "pqc_algo": args.pqc_algo,
        "pqc_pub_key": pqc_pub_key,
        "pqc_sig": pqc_sig,
    }

    if args.attach_signing_payload:
        payload["signing_payload"] = signing_payload
        payload["signing_payload_canonical"] = canonical

    return payload


def validate_payload(payload: Dict[str, Any]) -> None:
    required = [
        "legacy_account",
        "pqc_account",
        "asset",
        "amount_units",
        "nonce",
        "digest_hex",
        "legacy_algo",
        "legacy_pub_key",
        "legacy_sig",
        "pqc_algo",
        "pqc_pub_key",
        "pqc_sig",
    ]
    missing = [field for field in required if payload.get(field) in (None, "")]
    if missing:
        raise ValueError(
            f"missing required fields for migration payload: {', '.join(missing)}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate dual-signature migration payloads for /ledger/migration/migrate. "
            "The digest is SHA-256 over canonical JSON of the signing payload."
        )
    )
    parser.add_argument(
        "--legacy-account", required=True, help="Legacy account identifier"
    )
    parser.add_argument(
        "--pqc-account", required=True, help="Post-quantum account identifier"
    )
    parser.add_argument("--asset", default="MHC", help="Asset symbol (default: MHC)")
    parser.add_argument(
        "--amount-units", type=int, required=True, help="Transfer amount in base units"
    )
    parser.add_argument("--memo", default="", help="Optional migration memo")
    parser.add_argument(
        "--idempotency-key", default="", help="Optional idempotency key"
    )
    parser.add_argument("--nonce", type=int, required=True, help="Anti-replay nonce")

    parser.add_argument(
        "--legacy-algo",
        default="ecdsa-p256-sha256",
        help="Legacy signature algorithm",
    )
    parser.add_argument("--legacy-pub-key", help="Legacy public key string")
    parser.add_argument("--legacy-sig", help="Legacy signature string")
    parser.add_argument(
        "--legacy-pub-key-file", help="Path containing legacy public key"
    )
    parser.add_argument("--legacy-sig-file", help="Path containing legacy signature")

    parser.add_argument(
        "--pqc-algo",
        default="ml-dsa-65",
        help="PQC signature algorithm",
    )
    parser.add_argument("--pqc-pub-key", help="PQC public key string")
    parser.add_argument("--pqc-sig", help="PQC signature string")
    parser.add_argument("--pqc-pub-key-file", help="Path containing PQC public key")
    parser.add_argument("--pqc-sig-file", help="Path containing PQC signature")

    parser.add_argument(
        "--attach-signing-payload",
        action="store_true",
        help="Embed canonical signing payload in output for auditability",
    )
    parser.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="Allow missing signatures/public keys when producing draft payloads",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Output path (default: stdout)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload = build_dual_signature_payload(args)
        if not args.allow_incomplete:
            validate_payload(payload)

        text = json.dumps(payload, indent=2, sort_keys=True)
        if args.output == "-":
            print(text)
        else:
            Path(args.output).write_text(text + "\n", encoding="utf-8")
            print(f"wrote migration payload to {args.output}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
