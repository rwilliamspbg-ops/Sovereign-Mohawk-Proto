#!/usr/bin/env python3
"""Validate tamper-evident export bundle integrity.

Checks:
- required files exist
- manifest file hashes match actual files
- chain linkage and per-record hashes in events_chained.ndjson are valid
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json_bytes(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def load_ndjson(path: Path) -> list[dict]:
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8", errors="strict").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def validate_chain(rows: list[dict]) -> None:
    prev = ""
    for i, row in enumerate(rows):
        if row.get("index") != i:
            raise ValueError(f"row {i}: index mismatch")

        row_prev = str(row.get("prev_hash", ""))
        row_hash = str(row.get("hash", ""))
        if row_prev != prev:
            raise ValueError(f"row {i}: prev_hash mismatch")
        if len(row_hash) != 64:
            raise ValueError(f"row {i}: hash must be 64 hex chars")

        payload = {
            "index": row.get("index"),
            "event": row.get("event"),
            "prev_hash": row.get("prev_hash"),
        }
        expected = sha256_hex(canonical_json_bytes(payload))
        if expected != row_hash:
            raise ValueError(f"row {i}: hash mismatch")
        prev = row_hash


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate tamper-evident event bundle")
    parser.add_argument(
        "--bundle-dir",
        default="test-results/tamper-evident-events",
        help="Directory containing events.ndjson, events_chained.ndjson, and bundle_manifest.json",
    )
    args = parser.parse_args()

    bundle_dir = Path(args.bundle_dir)
    raw_path = bundle_dir / "events.ndjson"
    chain_path = bundle_dir / "events_chained.ndjson"
    manifest_path = bundle_dir / "bundle_manifest.json"

    for required in (raw_path, chain_path, manifest_path):
        if not required.exists():
            raise FileNotFoundError(f"missing required bundle file: {required}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = manifest.get("files", {})

    raw_digest = sha256_hex(raw_path.read_bytes())
    chain_digest = sha256_hex(chain_path.read_bytes())

    if files.get("events.ndjson") != raw_digest:
        raise ValueError("manifest hash mismatch for events.ndjson")
    if files.get("events_chained.ndjson") != chain_digest:
        raise ValueError("manifest hash mismatch for events_chained.ndjson")

    chain_rows = load_ndjson(chain_path)
    validate_chain(chain_rows)

    tip = chain_rows[-1]["hash"] if chain_rows else ""
    if manifest.get("chain_tip_hash", "") != tip:
        raise ValueError("manifest chain_tip_hash mismatch")

    if manifest.get("event_count") != len(load_ndjson(raw_path)):
        raise ValueError("manifest event_count mismatch")

    print(f"tamper-evident bundle integrity check passed for {bundle_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
