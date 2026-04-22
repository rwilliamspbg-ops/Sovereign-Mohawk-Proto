#!/usr/bin/env python3
"""Basic refinement alignment checks between Lean specification and Go implementation.

This script provides a machine-enforced drift check for critical symbols/files.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REQUIRED_LEAN_SYMBOLS = [
    "structure Node",
    "structure Swarm",
    "def honestGradient",
    "def multiKrumSelectImpl",
]

REQUIRED_GO_FILES = {
    "internal/multikrum.go": [r"func\s+MultiKrumSelect\s*\(", r"func\s+MultiKrumAggregate\s*\("],
    "internal/rdp_accountant.go": [
        r"func\s+\(a \*RDPAccountant\)\s+RecordStepRat\s*\(",
        r"func\s+\(a \*RDPAccountant\)\s+CheckBudget\s*\(",
    ],
    "internal/network/transport.go": [r"func\s+NewHost\s*\("],
    "internal/token/ledger.go": [r"func\s+\(l \*Ledger\)\s+TransferWithControls\s*\("],
}


def ensure_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"missing required file: {path}")


def check_lean_symbols(lean_text: str) -> list[str]:
    missing: list[str] = []
    for symbol in REQUIRED_LEAN_SYMBOLS:
        if symbol not in lean_text:
            missing.append(symbol)
    return missing


def check_go_symbols(repo_root: Path) -> dict[str, list[str]]:
    missing: dict[str, list[str]] = {}
    for rel_file, patterns in REQUIRED_GO_FILES.items():
        abs_file = repo_root / rel_file
        ensure_file(abs_file)
        text = abs_file.read_text(encoding="utf-8")
        not_found = [pattern for pattern in patterns if re.search(pattern, text) is None]
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

    lean_text = lean_file.read_text(encoding="utf-8")
    lean_missing = check_lean_symbols(lean_text)
    go_missing = check_go_symbols(repo_root)

    ok = not lean_missing and not go_missing
    result = {
        "ok": ok,
        "lean_file": str(lean_file),
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
                for item in lean_missing:
                    print(f"    - {item}")
            if go_missing:
                print("  missing Go symbols:")
                for rel_file, patterns in go_missing.items():
                    print(f"    - {rel_file}")
                    for pattern in patterns:
                        print(f"      - {pattern}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
