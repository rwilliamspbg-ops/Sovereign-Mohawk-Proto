#!/usr/bin/env python3
"""Basic refinement alignment checks between Lean specification and Go implementation.

This script provides a machine-enforced drift check for critical symbols/files.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REQUIRED_LEAN_FILES = {
    "Specification/System.lean": [
        "structure Node",
        "structure Swarm",
        "structure Message",
        "structure RDPState",
        "def honestGradient",
        "def multiKrumSelectImpl",
        "def totalBytes",
        "def rdpCompose",
    ],
    "Specification/Privacy.lean": [
        "def composeRDP",
        "def rdpAccountant",
        "theorem composeRDP_append",
        "theorem composeRDP_nonneg",
    ],
    "Specification/Communication.lean": [
        "def hierarchicalProtocol",
        "def communicationUpperBound",
        "theorem communication_bound",
    ],
    "Refinement/MultiKrum.lean": [
        "def krumSpec",
        "def krumImpl",
        "theorem krum_impl_refines_spec",
    ],
    "Refinement/RDPAccountant.lean": [
        "def accountantSpec",
        "def accountantImpl",
        "theorem accountant_impl_refines_spec",
    ],
    "Refinement/Transport.lean": [
        "def transportSpecBytes",
        "def transportImplBytes",
        "theorem transport_impl_bounded",
    ],
    "Refinement/Ledger.lean": [
        "def transferSpec",
        "def transferImpl",
        "theorem transfer_impl_refines_spec",
    ],
}

REQUIRED_GO_FILES = {
    "internal/multikrum.go": [
        r"func\s+MultiKrumSelect\s*\(\s*updates\s+\[\]\[\]float64\s*,\s*f\s+int\s*,\s*m\s+int\s*\)\s*\(\s*\[\]int\s*,\s*\[\]float64\s*,\s*error\s*\)",
        r"func\s+MultiKrumAggregate\s*\(\s*updates\s+\[\]\[\]float64\s*,\s*f\s+int\s*,\s*m\s+int\s*\)\s*\(\s*\[\]float64\s*,\s*\[\]int\s*,\s*\[\]float64\s*,\s*error\s*\)",
    ],
    "internal/rdp_accountant.go": [
        r"func\s+\(\s*a\s+\*RDPAccountant\s*\)\s+RecordStepRat\s*\(\s*epsilon\s+\*big\.Rat\s*\)",
        r"func\s+\(\s*a\s+\*RDPAccountant\s*\)\s+CheckBudget\s*\(\s*\)\s*error",
    ],
    "internal/network/transport.go": [
        r"func\s+NewHost\s*\(\s*ctx\s+context\.Context\s*,\s*cfg\s+Config\s*\)\s*\(\s*corehost\.Host\s*,\s*error\s*\)",
    ],
    "internal/token/ledger.go": [
        r"func\s+\(\s*l\s+\*Ledger\s*\)\s+TransferWithControls\s*\(\s*from\s+string\s*,\s*to\s+string\s*,\s*amount\s+float64\s*,\s*memo\s+string\s*,\s*idempotencyKey\s+string\s*,\s*nonce\s+uint64\s*\)\s*\(\s*Tx\s*,\s*error\s*\)",
    ],
}


def ensure_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"missing required file: {path}")


def check_lean_symbols(proofs_root: Path) -> dict[str, list[str]]:
    missing: dict[str, list[str]] = {}
    for rel_file, symbols in REQUIRED_LEAN_FILES.items():
        abs_file = proofs_root / rel_file
        ensure_file(abs_file)
        text = abs_file.read_text(encoding="utf-8")
        not_found = [symbol for symbol in symbols if symbol not in text]
        if not_found:
            missing[rel_file] = not_found
    return missing


def check_go_symbols(repo_root: Path) -> dict[str, list[str]]:
    missing: dict[str, list[str]] = {}
    for rel_file, patterns in REQUIRED_GO_FILES.items():
        abs_file = repo_root / rel_file
        ensure_file(abs_file)
        text = abs_file.read_text(encoding="utf-8")
        not_found = [
            pattern for pattern in patterns if re.search(pattern, text) is None
        ]
        if not_found:
            missing[rel_file] = not_found
    return missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Lean/Go refinement alignment")
    parser.add_argument("--lean", required=True, help="Path to Lean specification file")
    parser.add_argument(
        "--go",
        required=True,
        help="Path to repository root or internal directory",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    args = parser.parse_args()

    lean_file = Path(args.lean).resolve()
    ensure_file(lean_file)

    go_path = Path(args.go).resolve()
    if go_path.name == "internal":
        repo_root = go_path.parent
    else:
        repo_root = go_path

    # Expecting --lean to point to proofs/Specification/System.lean or a sibling file.
    # We use it to resolve the proofs root and validate all required spec/refinement files.
    proofs_root = lean_file.parents[1]
    lean_missing = check_lean_symbols(proofs_root)
    go_missing = check_go_symbols(repo_root)

    ok = not lean_missing and not go_missing
    result = {
        "ok": ok,
        "lean_file": str(lean_file),
        "proofs_root": str(proofs_root),
        "lean_files_checked": sorted(REQUIRED_LEAN_FILES.keys()),
        "go_files_checked": sorted(REQUIRED_GO_FILES.keys()),
        "lean_missing": lean_missing,
        "go_missing": go_missing,
    }

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        if ok:
            print("refinement check passed")
        else:
            print("refinement check failed")
            if lean_missing:
                print("  missing Lean symbols:")
                for rel_file, symbols in lean_missing.items():
                    print(f"    - {rel_file}")
                    for symbol in symbols:
                        print(f"      - {symbol}")
            if go_missing:
                print("  missing Go symbols:")
                for rel_file, patterns in go_missing.items():
                    print(f"    - {rel_file}")
                    for pattern in patterns:
                        print(f"      - {pattern}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
