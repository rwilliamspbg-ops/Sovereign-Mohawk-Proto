#!/usr/bin/env python3
"""Build a reproducible formal verification bundle.

The bundle contains proofs, traceability evidence, machine-checkable report,
and a manifest with SHA256 hashes + Merkle root for independent verification.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tarfile
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


def load_report(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_manifest(bundle_dir: Path, file_map: dict[str, str], report: dict) -> dict:
    leaf_hashes = [
        sha256_hex(f"{path}:{digest}".encode("utf-8"))
        for path, digest in sorted(file_map.items())
    ]
    return {
        "schema_version": "formal_verification_bundle.v1",
        "bundle_dir": bundle_dir.name,
        "file_count": len(file_map),
        "files": dict(sorted(file_map.items())),
        "bundle_merkle_root": merkle_root_hex(leaf_hashes),
        "report_input_merkle_root": report.get("input_merkle_root", ""),
        "toolchain_lock": report.get("toolchain_lock", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build formal verification bundle")
    parser.add_argument("--repo-root", default=".", help="Repository root directory")
    parser.add_argument(
        "--report",
        default="results/proofs/formal_validation_report.json",
        help="Machine-checkable report path",
    )
    parser.add_argument(
        "--bundle-dir",
        default="results/proofs/formal-verification-bundle",
        help="Output bundle directory",
    )
    parser.add_argument(
        "--bundle-tar",
        default="results/proofs/formal-verification-bundle.tar.gz",
        help="Output tar.gz path",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    report_path = repo_root / args.report
    bundle_dir = repo_root / args.bundle_dir
    bundle_tar = repo_root / args.bundle_tar

    if not report_path.exists():
        raise FileNotFoundError(f"missing report file: {report_path}")

    report = load_report(report_path)

    required_artifacts = [
        Path("results/proofs/formal_theorem_index.txt"),
        Path("results/proofs/formal_traceability_matrix_snapshot.md"),
        Path("results/proofs/formal_placeholder_scan.txt"),
    ]

    report_inputs = [Path(item["path"]) for item in report.get("inputs", [])]
    include_paths = sorted(
        set(required_artifacts + report_inputs), key=lambda item: item.as_posix()
    )

    for rel_path in include_paths:
        src = repo_root / rel_path
        if not src.exists():
            raise FileNotFoundError(f"missing bundle input: {src}")

    report_bundle_rel = Path("results/proofs/formal_validation_report.json")
    if not report_path.exists():
        raise FileNotFoundError(f"missing report file: {report_path}")

    if bundle_dir.exists():
        shutil.rmtree(bundle_dir)
    bundle_dir.mkdir(parents=True, exist_ok=True)

    # The bundle must contain the exact report selected by --report at the
    # canonical path expected by verifiers.
    canonical_report_rel = Path("results/proofs/formal_validation_report.json")

    manifest_files: dict[str, str] = {}
    for rel_path in include_paths:
        src = (
            report_path if rel_path == canonical_report_rel else (repo_root / rel_path)
        )
        dst = bundle_dir / rel_path
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        manifest_files[rel_path.as_posix()] = file_sha256(dst)

    report_dst = bundle_dir / report_bundle_rel
    report_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(report_path, report_dst)
    manifest_files[report_bundle_rel.as_posix()] = file_sha256(report_dst)

    manifest = build_manifest(bundle_dir, manifest_files, report)
    manifest_path = bundle_dir / "bundle_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    bundle_tar.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(bundle_tar, mode="w:gz") as archive:
        archive.add(bundle_dir, arcname=bundle_dir.name)

    print(f"wrote bundle directory: {bundle_dir}")
    print(f"wrote bundle manifest: {manifest_path}")
    print(f"wrote bundle archive: {bundle_tar}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
