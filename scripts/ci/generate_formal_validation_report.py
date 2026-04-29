#!/usr/bin/env python3
"""Generate or validate a machine-checkable formal validation report.

The report is deterministic and derived from repository inputs so CI can enforce
that documentation-level formal claims match current proof/test artifacts.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_hex(path.read_bytes())


def merkle_root_hex(leaves: list[str]) -> str:
    """Compute SHA256 Merkle root from hex digests.

    Leaves are 64-char lowercase hex SHA256 digests. For odd levels, duplicate
    the final node to keep the tree balanced.
    """

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


def parse_entry_imports(entry_file: Path) -> list[str]:
    modules: list[str] = []
    for line in entry_file.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^import\s+LeanFormalization\.([A-Za-z0-9_]+)\s*$", line)
        if match:
            modules.append(match.group(1))
    return sorted(set(modules))


def parse_matrix_runtime_refs(matrix_file: Path) -> list[str]:
    text = matrix_file.read_text(encoding="utf-8")
    refs = re.findall(r"[^\s`]+\.(?:go|py)::[A-Za-z0-9_]+", text)
    return sorted(set(refs))


def load_theorem_claims(claims_file: Path) -> dict:
    return json.loads(claims_file.read_text(encoding="utf-8"))


def parse_mathlib_ref(lakefile: Path) -> str:
    for line in lakefile.read_text(encoding="utf-8").splitlines():
        if "mathlib4.git" in line and "@" in line:
            match = re.search(r'@\s*"([^"]+)"', line)
            if match:
                return match.group(1)
    return "unknown"


def parse_go_version(go_mod: Path) -> str:
    for line in go_mod.read_text(encoding="utf-8").splitlines():
        if line.startswith("go "):
            return line.split(maxsplit=1)[1].strip()
    return "unknown"


def parse_go_module_version(go_mod: Path, module: str) -> str:
    pattern = re.compile(rf"^\s*{re.escape(module)}\s+([^\s]+)")
    for line in go_mod.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            return match.group(1)
    return "unknown"


def parse_module_theorems(module_file: Path) -> list[str]:
    symbols: list[str] = []
    pattern = re.compile(r"^\s*(?:theorem|lemma|def)\s+([A-Za-z0-9_']+)")
    for line in module_file.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            symbols.append(match.group(1))
    return sorted(set(symbols))


def compute_report(repo_root: Path) -> dict:
    proof_root = repo_root / "proofs"
    entry_file = proof_root / "LeanFormalization.lean"
    matrix_file = proof_root / "FORMAL_TRACEABILITY_MATRIX.md"
    claims_file = proof_root / "theorem_claims.json"
    lakefile = proof_root / "lakefile.lean"
    lean_toolchain = proof_root / "lean-toolchain"
    go_mod = repo_root / "go.mod"
    capabilities = repo_root / "capabilities.json"

    required = [
        entry_file,
        matrix_file,
        claims_file,
        lakefile,
        lean_toolchain,
        go_mod,
        capabilities,
    ]
    for path in required:
        if not path.exists():
            raise FileNotFoundError(f"missing required input: {path}")

    modules = parse_entry_imports(entry_file)
    if not modules:
        raise ValueError("no Lean modules found in LeanFormalization.lean")

    module_files = [
        proof_root / "LeanFormalization" / f"{module}.lean" for module in modules
    ]
    for path in module_files:
        if not path.exists():
            raise FileNotFoundError(f"missing Lean module file: {path}")

    input_paths = [
        Path("capabilities.json"),
        Path("go.mod"),
        Path("proofs/FORMAL_TRACEABILITY_MATRIX.md"),
        Path("proofs/LeanFormalization.lean"),
        Path("proofs/lakefile.lean"),
        Path("proofs/lean-toolchain"),
        Path("proofs/theorem_claims.json"),
    ]
    input_paths.extend(
        Path(f"proofs/LeanFormalization/{module}.lean") for module in modules
    )

    input_entries: list[dict] = []
    leaf_hashes: list[str] = []
    for rel_path in sorted(input_paths, key=lambda item: item.as_posix()):
        abs_path = repo_root / rel_path
        digest = file_sha256(abs_path)
        input_entries.append({"path": rel_path.as_posix(), "sha256": digest})
        leaf_hashes.append(
            sha256_hex(f"{rel_path.as_posix()}:{digest}".encode("utf-8"))
        )

    module_summary: list[dict] = []
    theorem_symbol_total = 0
    for module in modules:
        rel_path = Path(f"proofs/LeanFormalization/{module}.lean")
        symbols = parse_module_theorems(repo_root / rel_path)
        theorem_symbol_total += len(symbols)
        module_summary.append(
            {
                "module": f"LeanFormalization.{module}",
                "file": rel_path.as_posix(),
                "symbol_count": len(symbols),
                "symbols": symbols,
            }
        )

    runtime_refs = parse_matrix_runtime_refs(matrix_file)
    theorem_claims = load_theorem_claims(claims_file)
    claims = theorem_claims.get("claims", [])
    status_counts: dict[str, int] = {}
    for claim in claims:
        status = claim.get("status", "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1

    return {
        "schema_version": "formal_validation_report.v1",
        "toolchain_lock": {
            "lean_toolchain": lean_toolchain.read_text(encoding="utf-8").strip(),
            "mathlib4_ref": parse_mathlib_ref(lakefile),
            "go_version": parse_go_version(go_mod),
            "zk_backend_gnark_crypto": parse_go_module_version(
                go_mod, "github.com/consensys/gnark-crypto"
            ),
        },
        "inputs": input_entries,
        "input_merkle_root": merkle_root_hex(leaf_hashes),
        "traceability": {
            "matrix_path": "proofs/FORMAL_TRACEABILITY_MATRIX.md",
            "claims_path": "proofs/theorem_claims.json",
            "runtime_reference_count": len(runtime_refs),
            "runtime_references": runtime_refs,
        },
        "claim_status": {
            "claim_count": len(claims),
            "status_counts": status_counts,
        },
        "lean_modules": module_summary,
        "summary": {
            "module_count": len(module_summary),
            "theorem_symbol_count": theorem_symbol_total,
            "input_file_count": len(input_entries),
        },
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate or validate formal validation report"
    )
    parser.add_argument("--repo-root", default=".", help="Repository root directory")
    parser.add_argument(
        "--output",
        default="results/proofs/formal_validation_report.json",
        help="Output report path (relative to repo root unless absolute)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if output file content differs from regenerated report",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output = Path(args.output)
    if not output.is_absolute():
        output = repo_root / output

    computed = compute_report(repo_root)

    if args.check:
        if not output.exists():
            raise FileNotFoundError(f"missing report file for --check: {output}")
        current = json.loads(output.read_text(encoding="utf-8"))
        if current != computed:
            print(f"formal validation report mismatch: {output}")
            print("regenerate with:")
            print("  python3 scripts/ci/generate_formal_validation_report.py")
            return 1
        print(f"formal validation report check passed: {output}")
        return 0

    write_json(output, computed)
    print(f"wrote formal validation report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
