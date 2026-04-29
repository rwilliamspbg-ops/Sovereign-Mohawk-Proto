#!/usr/bin/env python3
"""Verify integrity of the formal verification bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_hex(path.read_bytes())


def merkle_root_hex(leaves: list[str]) -> str:
    if not leaves:
        return sha256_hex(b"")
    level = [bytes.fromhex(item) for item in leaves]
    while len(level) > 1:
        next_level: list[bytes] = []
        i = 0
        while i < len(level):
            left = level[i]
            right = level[i + 1] if i + 1 < len(level) else left
            next_level.append(hashlib.sha256(left + right).digest())
            i += 2
        level = next_level
    return level[0].hex()


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify formal verification bundle")
    parser.add_argument(
        "--bundle-dir",
        default="results/proofs/formal-verification-bundle",
        help="Bundle directory containing bundle_manifest.json",
    )
    args = parser.parse_args()

    bundle_dir = Path(args.bundle_dir).resolve()
    manifest_path = bundle_dir / "bundle_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"missing manifest: {manifest_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = manifest.get("files", {})
    if not isinstance(files, dict) or not files:
        raise ValueError("manifest files map is missing or empty")

    leaf_hashes: list[str] = []
    for rel_path, expected_hash in sorted(files.items()):
        file_path = bundle_dir / rel_path
        if not file_path.exists():
            raise FileNotFoundError(f"manifest references missing file: {file_path}")
        digest = file_sha256(file_path)
        if digest != expected_hash:
            raise ValueError(
                f"hash mismatch for {rel_path}: expected {expected_hash}, got {digest}"
            )
        leaf_hashes.append(sha256_hex(f"{rel_path}:{digest}".encode("utf-8")))

    expected_root = str(manifest.get("bundle_merkle_root", ""))
    actual_root = merkle_root_hex(leaf_hashes)
    if actual_root != expected_root:
        raise ValueError(
            f"bundle Merkle root mismatch: expected {expected_root}, got {actual_root}"
        )

    report_rel = "results/proofs/formal_validation_report.json"
    report_path = bundle_dir / report_rel
    if not report_path.exists():
        raise FileNotFoundError(f"bundle missing formal report: {report_path}")

    report = json.loads(report_path.read_text(encoding="utf-8"))
    report_root = str(report.get("input_merkle_root", ""))
    manifest_root = str(manifest.get("report_input_merkle_root", ""))
    if report_root != manifest_root:
        raise ValueError(
            "report_input_merkle_root mismatch between report and bundle manifest"
        )

    for item in report.get("inputs", []):
        rel_path = str(item.get("path", ""))
        expected_hash = str(item.get("sha256", ""))
        if not rel_path or not expected_hash:
            raise ValueError(
                "invalid report input entry in formal_validation_report.json"
            )
        manifest_hash = files.get(rel_path)
        if manifest_hash is None:
            raise ValueError(f"bundle manifest missing report input file: {rel_path}")
        if manifest_hash != expected_hash:
            raise ValueError(
                f"report input hash mismatch for {rel_path}: report={expected_hash}, manifest={manifest_hash}"
            )

    print(f"formal verification bundle check passed: {bundle_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
