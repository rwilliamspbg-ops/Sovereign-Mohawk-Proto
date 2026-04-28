#!/usr/bin/env python3
"""Extract deterministic Lean proof metrics for regression tracking."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Iterable

TACTICS = [
    "simpa",
    "simp",
    "rw",
    "rfl",
    "omega",
    "linarith",
    "nlinarith",
    "norm_num",
    "native_decide",
    "decide",
    "ring",
    "ring_nf",
    "gcongr",
    "cases",
    "constructor",
    "intro",
    "exact",
    "have",
    "unfold",
    "contradiction",
    "refine",
    "apply",
    "use",
]

DECL_RE = re.compile(r"^(?P<indent>\s*)(?:theorem|lemma)\s+(?P<name>[A-Za-z0-9_']+)\b")
TOP_LEVEL_RE = re.compile(
    r"^\s*(?:theorem|lemma|def|structure|class|inductive|abbrev|opaque)\s+[A-Za-z0-9_']+\b"
)
IMPORT_RE = re.compile(r"^\s*import\s+(.+)$")


def strip_inline_comment(line: str) -> str:
    if "--" not in line:
        return line
    return line.split("--", 1)[0]


def leading_spaces(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def load_lean_files(repo_root: Path) -> list[Path]:
    lean_dir = repo_root / "proofs" / "LeanFormalization"
    return sorted(lean_dir.glob("*.lean"))


def parse_imports(lines: list[str]) -> list[str]:
    imports: list[str] = []
    for line in lines:
        match = IMPORT_RE.match(line)
        if not match:
            continue
        for item in match.group(1).split():
            imports.append(item.strip())
    return sorted(set(imports))


def collect_theorem_names(files: Iterable[Path]) -> set[str]:
    names: set[str] = set()
    for file_path in files:
        for line in file_path.read_text(encoding="utf-8").splitlines():
            match = DECL_RE.match(line)
            if match:
                names.add(match.group("name"))
    return names


def theorem_blocks(lines: list[str]) -> list[tuple[str, int, int]]:
    blocks: list[tuple[str, int, int]] = []
    index = 0
    while index < len(lines):
        match = DECL_RE.match(lines[index])
        if not match:
            index += 1
            continue

        name = match.group("name")
        start = index
        end = index + 1
        while end < len(lines):
            candidate = strip_inline_comment(lines[end]).rstrip("\n")
            if TOP_LEVEL_RE.match(candidate):
                break
            end += 1
        blocks.append((name, start, end))
        index = end
    return blocks


def proof_depth(block_lines: list[str]) -> int:
    proof_start = 0
    for idx, line in enumerate(block_lines):
        stripped = strip_inline_comment(line).strip()
        if stripped.endswith(":= by") or stripped == ":= by" or stripped == "by":
            proof_start = idx + 1
            break

    proof_lines = [strip_inline_comment(line) for line in block_lines[proof_start:]]
    indent_levels = [leading_spaces(line) for line in proof_lines if line.strip()]
    if not indent_levels:
        return 1
    min_indent = min(indent_levels)
    relative_depth = max((indent - min_indent) // 2 for indent in indent_levels)
    return max(1, relative_depth + 1)


def count_tactics(body_text: str) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for tactic in TACTICS:
        counts[tactic] = len(re.findall(rf"\b{re.escape(tactic)}\b", body_text))
    return {name: count for name, count in counts.items() if count > 0}


def theorem_dependencies(body_text: str, theorem_names: set[str], current_name: str) -> list[str]:
    dependencies = []
    for name in sorted(theorem_names):
        if name == current_name:
            continue
        if re.search(rf"\b{re.escape(name)}\b", body_text) is not None:
            dependencies.append(name)
    return dependencies


def compute_metrics(repo_root: Path) -> dict:
    files = load_lean_files(repo_root)
    theorem_names = collect_theorem_names(files)

    file_entries: list[dict] = []
    theorem_entries: list[dict] = []
    total_tactics = 0

    for file_path in files:
        lines = file_path.read_text(encoding="utf-8").splitlines()
        imports = parse_imports(lines)
        blocks = theorem_blocks(lines)
        file_theorems: list[str] = []

        for name, start, end in blocks:
            block_lines = lines[start:end]
            cleaned_block = "\n".join(strip_inline_comment(line) for line in block_lines)
            tactics = count_tactics(cleaned_block)
            deps = theorem_dependencies(cleaned_block, theorem_names, name)
            depth = proof_depth(block_lines)
            tactic_count = sum(tactics.values())
            total_tactics += tactic_count
            file_theorems.append(name)
            theorem_entries.append(
                {
                    "name": name,
                    "file": file_path.relative_to(repo_root).as_posix(),
                    "imports": imports,
                    "proof_depth": depth,
                    "tactic_count": tactic_count,
                    "tactics": tactics,
                    "dependencies": deps,
                }
            )

        file_entries.append(
            {
                "file": file_path.relative_to(repo_root).as_posix(),
                "imports": imports,
                "theorem_count": len(file_theorems),
                "theorems": file_theorems,
            }
        )

    theorem_entries.sort(key=lambda item: (item["file"], item["name"]))
    file_entries.sort(key=lambda item: item["file"])

    return {
        "schema_version": "lean_proof_metrics.v1",
        "summary": {
            "file_count": len(file_entries),
            "theorem_count": len(theorem_entries),
            "tactic_count": total_tactics,
        },
        "files": file_entries,
        "theorems": theorem_entries,
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Lean proof metrics")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument(
        "--output",
        default="results/proofs/lean_proof_metrics.json",
        help="Output JSON path",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the output file differs from the computed metrics",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output = Path(args.output)
    if not output.is_absolute():
        output = repo_root / output

    computed = compute_metrics(repo_root)

    if args.check:
        if not output.exists():
            raise FileNotFoundError(f"missing metrics file for --check: {output}")
        current = json.loads(output.read_text(encoding="utf-8"))
        if current != computed:
            print(f"Lean proof metrics mismatch: {output}")
            print("regenerate with:")
            print("  python3 scripts/extract_lean_proof_metrics.py")
            return 1
        print(f"Lean proof metrics check passed: {output}")
        return 0

    write_json(output, computed)
    print(f"wrote Lean proof metrics: {output}")
    print(f"  - files: {computed['summary']['file_count']}")
    print(f"  - theorems: {computed['summary']['theorem_count']}")
    print(f"  - tactic occurrences: {computed['summary']['tactic_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
