#!/usr/bin/env python3
"""Refresh proof freshness metadata used by security audit gates."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Refresh proof artifact freshness metadata."
    )
    parser.add_argument("--repo-root", default=".", help="Repository root directory")
    parser.add_argument(
        "--output",
        default="results/proofs/proof_freshness.json",
        help="Output freshness metadata path",
    )
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    capabilities = root / "capabilities.json"
    verification_log = root / "proofs/VERIFICATION_LOG.md"

    if not capabilities.exists():
        raise SystemExit(f"missing file: {capabilities}")
    if not verification_log.exists():
        raise SystemExit(f"missing file: {verification_log}")

    now = datetime.now(timezone.utc).replace(microsecond=0)
    payload = {
        "refreshed_at": now.isoformat().replace("+00:00", "Z"),
        "verification_log_sha256": sha256(verification_log),
        "capabilities_sha256": sha256(capabilities),
    }

    out = root / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
