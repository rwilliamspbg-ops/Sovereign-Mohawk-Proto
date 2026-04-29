#!/usr/bin/env python3
"""Audit Lean theorem dependencies and local import cycles."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

DECL_RE = re.compile(r"^(?:\s*)(?:theorem|lemma)\s+([A-Za-z0-9_']+)\b")
IMPORT_RE = re.compile(r"^\s*import\s+(.+)$")
TOP_LEVEL_RE = re.compile(
    r"^\s*(?:theorem|lemma|def|structure|class|inductive|abbrev|opaque)\s+[A-Za-z0-9_']+\b"
)


def strip_inline_comment(line: str) -> str:
    if "--" not in line:
        return line
    return line.split("--", 1)[0]


def load_lean_files(repo_root: Path) -> list[Path]:
    return sorted((repo_root / "proofs" / "LeanFormalization").glob("*.lean"))


def module_name_for(file_path: Path) -> str:
    return file_path.stem


def parse_imports(lines: list[str]) -> list[str]:
    imports: list[str] = []
    for line in lines:
        match = IMPORT_RE.match(line)
        if not match:
            continue
        imports.extend(item.strip() for item in match.group(1).split())
    return sorted(set(imports))


def theorem_blocks(lines: list[str]) -> list[tuple[str, int, int]]:
    blocks: list[tuple[str, int, int]] = []
    index = 0
    while index < len(lines):
        match = DECL_RE.match(lines[index])
        if not match:
            index += 1
            continue

        name = match.group(1)
        end = index + 1
        while end < len(lines):
            candidate = strip_inline_comment(lines[end]).rstrip("\n")
            if TOP_LEVEL_RE.match(candidate):
                break
            end += 1
        blocks.append((name, index, end))
        index = end
    return blocks


def detect_cycles(graph: dict[str, list[str]]) -> list[list[str]]:
    visited: set[str] = set()
    active: set[str] = set()
    stack: list[str] = []
    cycles: list[list[str]] = []

    def visit(node: str) -> None:
        if node in active:
            if node in stack:
                cycle_start = stack.index(node)
                cycles.append(stack[cycle_start:] + [node])
            return
        if node in visited:
            return
        visited.add(node)
        active.add(node)
        stack.append(node)
        for neighbor in graph.get(node, []):
            visit(neighbor)
        stack.pop()
        active.remove(node)

    for node in sorted(graph):
        visit(node)
    return cycles


def compute_report(repo_root: Path) -> dict:
    files = load_lean_files(repo_root)
    module_names = {module_name_for(path) for path in files}
    matrix_text = (repo_root / "proofs" / "FORMAL_TRACEABILITY_MATRIX.md").read_text(
        encoding="utf-8"
    )

    module_graph: dict[str, list[str]] = {}
    theorem_entries: list[dict] = []
    theorem_names: list[str] = []
    theorem_bodies: dict[str, str] = {}

    for file_path in files:
        lines = file_path.read_text(encoding="utf-8").splitlines()
        imports = [
            item
            for item in parse_imports(lines)
            if item.startswith("LeanFormalization.")
        ]
        local_imports = [
            item.split(".", 1)[1]
            for item in imports
            if item.split(".", 1)[1] in module_names
        ]
        module_graph[module_name_for(file_path)] = sorted(set(local_imports))

        for name, start, end in theorem_blocks(lines):
            theorem_names.append(name)
            theorem_bodies[name] = "\n".join(
                strip_inline_comment(line) for line in lines[start:end]
            )
            theorem_entries.append(
                {
                    "name": name,
                    "file": file_path.relative_to(repo_root).as_posix(),
                    "matrix_used": name in matrix_text,
                }
            )

    inbound_refs: dict[str, int] = {name: 0 for name in theorem_names}
    for source_name, body in theorem_bodies.items():
        for target_name in theorem_names:
            if target_name == source_name:
                continue
            if re.search(rf"\b{re.escape(target_name)}\b", body) is not None:
                inbound_refs[target_name] += 1

    public_theorems = [entry for entry in theorem_entries if entry["matrix_used"]]
    orphaned_theorems = [
        entry["name"]
        for entry in theorem_entries
        if inbound_refs.get(entry["name"], 0) == 0 and not entry["matrix_used"]
    ]

    return {
        "schema_version": "lean_dependency_audit.v1",
        "module_graph": module_graph,
        "cycles": detect_cycles(module_graph),
        "public_theorem_count": len(public_theorems),
        "orphaned_theorems": orphaned_theorems,
        "orphaned_theorem_count": len(orphaned_theorems),
        "theorem_count": len(theorem_entries),
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit Lean theorem dependencies")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument(
        "--output",
        default="results/proofs/theorem_dependency_audit.json",
        help="Output JSON path",
    )
    parser.add_argument(
        "--fail-on-orphans",
        action="store_true",
        help="Fail when public theorems are not referenced by the matrix or other proofs",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output = Path(args.output)
    if not output.is_absolute():
        output = repo_root / output

    report = compute_report(repo_root)
    write_json(output, report)

    print(f"wrote theorem dependency audit: {output}")
    print(f"  - modules: {len(report['module_graph'])}")
    print(f"  - theorems: {report['theorem_count']}")
    print(f"  - public theorems: {report['public_theorem_count']}")
    print(f"  - orphaned theorems: {report['orphaned_theorem_count']}")

    if report["cycles"]:
        print("circular import cycles detected:")
        for cycle in report["cycles"]:
            print(f"  - {' -> '.join(cycle)}")
        return 1

    if args.fail_on_orphans and report["orphaned_theorems"]:
        print("orphaned theorem symbols detected:")
        for name in report["orphaned_theorems"]:
            print(f"  - {name}")
        return 1

    if report["orphaned_theorems"]:
        print("orphaned theorem symbols (warning only):")
        for name in report["orphaned_theorems"]:
            print(f"  - {name}")

    print("theorem dependency audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
