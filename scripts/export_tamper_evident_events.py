#!/usr/bin/env python3
"""Export tamper-evident audit events for deployers.

Builds an exportable bundle with a chained NDJSON log and manifest checksums.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tarfile
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json_bytes(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def prom_query(base_url: str, query: str) -> dict:
    params = urllib.parse.urlencode({"query": query})
    url = f"{base_url.rstrip('/')}/api/v1/query?{params}"
    with urllib.request.urlopen(url, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if payload.get("status") != "success":
        raise RuntimeError(f"prometheus query failed: {query}")
    data = payload.get("data", {})
    result = data.get("result", [])
    return {"query": query, "result": result}


def load_ledger_audit_status(audit_file: Path) -> dict:
    if not audit_file.exists():
        return {
            "audit_file": str(audit_file),
            "present": False,
            "record_count": 0,
            "chain_link_ok": False,
            "tip_hash": "",
        }

    lines = [
        line.strip()
        for line in audit_file.read_text(encoding="utf-8", errors="ignore").splitlines()
        if line.strip()
    ]
    prev = ""
    chain_ok = True
    tip = ""

    for line in lines:
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            chain_ok = False
            continue
        rec_prev = str(rec.get("prev_hash", ""))
        rec_hash = str(rec.get("hash", ""))
        if rec_prev != prev:
            chain_ok = False
        if len(rec_hash) != 64:
            chain_ok = False
        prev = rec_hash
        tip = rec_hash

    return {
        "audit_file": str(audit_file),
        "present": True,
        "record_count": len(lines),
        "chain_link_ok": chain_ok,
        "tip_hash": tip,
        "file_sha256": sha256_hex(audit_file.read_bytes()),
    }


def append_chained(records: list[dict]) -> list[dict]:
    prev = ""
    out: list[dict] = []
    for index, rec in enumerate(records):
        payload = {
            "index": index,
            "event": rec,
            "prev_hash": prev,
        }
        rec_hash = sha256_hex(canonical_json_bytes(payload))
        payload["hash"] = rec_hash
        out.append(payload)
        prev = rec_hash
    return out


def write_ndjson(path: Path, values: list[dict]) -> None:
    lines = [json.dumps(v, sort_keys=True) for v in values]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Export tamper-evident audit events bundle")
    parser.add_argument("--prom-url", default="http://localhost:9090", help="Prometheus base URL")
    parser.add_argument(
        "--output-dir",
        default="results/forensics/tamper-evident-events",
        help="Output directory",
    )
    parser.add_argument(
        "--ledger-audit-file",
        default="data/utility-ledger/audit.jsonl",
        help="Ledger audit chain path",
    )
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    events: list[dict] = []

    def event(kind: str, source: str, payload: dict) -> None:
        events.append(
            {
                "event_type": kind,
                "source": source,
                "observed_at": iso_now(),
                "payload": payload,
            }
        )

    prom_queries = {
        "gradient_aggregation_workers": "mohawk_aggregation_workers",
        "zk_verification_success_total": 'sum(mohawk_proof_verifications_total{result="success"})',
        "zk_verification_failure_total": 'sum(mohawk_proof_verifications_total{result="failure"})',
        "byzantine_honest_ratio_min_10m": "min_over_time(mohawk_consensus_honest_ratio[10m])",
        "privacy_budget_target_epsilon": "2.0",
    }

    for key, query in prom_queries.items():
        if key == "privacy_budget_target_epsilon":
            event(
                "privacy_budget",
                "runtime_policy",
                {
                    "target_epsilon": 2.0,
                    "target_delta": 1e-5,
                    "source": "internal/dp_config.go",
                },
            )
            continue
        try:
            result = prom_query(args.prom_url, query)
            event(key, "prometheus", result)
        except Exception as exc:  # noqa: BLE001
            event(key, "prometheus", {"query": query, "error": str(exc)})

    ledger_status = load_ledger_audit_status(Path(args.ledger_audit_file))
    event("ledger_audit_chain_status", "utility_ledger", ledger_status)

    raw_path = out_dir / "events.ndjson"
    chained_path = out_dir / "events_chained.ndjson"
    manifest_path = out_dir / "bundle_manifest.json"
    tar_path = out_dir / "tamper_evident_events_bundle.tar.gz"

    write_ndjson(raw_path, events)
    chained = append_chained(events)
    write_ndjson(chained_path, chained)

    manifest = {
        "generated_at": iso_now(),
        "event_count": len(events),
        "chain_tip_hash": chained[-1]["hash"] if chained else "",
        "files": {
            "events.ndjson": sha256_hex(raw_path.read_bytes()),
            "events_chained.ndjson": sha256_hex(chained_path.read_bytes()),
        },
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(raw_path, arcname=raw_path.name)
        tar.add(chained_path, arcname=chained_path.name)
        tar.add(manifest_path, arcname=manifest_path.name)

    print(f"tamper-evident bundle written to {tar_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
