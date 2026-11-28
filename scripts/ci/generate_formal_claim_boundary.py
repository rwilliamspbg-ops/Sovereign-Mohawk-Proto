#!/usr/bin/env python3
"""Generate (or --check) a one-page reviewer boundary doc from the matrix.

The doc `docs/FORMAL_CLAIM_BOUNDARY.md` has three matrix-derived sections --
What is proved / What is assumed / What is only tested -- and every bullet in
them is derived from a row of `proofs/FORMAL_TRACEABILITY_MATRIX.md` (the
authoritative status source) plus the claim taxonomy in
`proofs/theorem_claims.json`. A final reviewer-evidence section links checked-in
artifacts; those links are a static index, not matrix-derived statuses.

Nothing here judges whether a claim is *true*: it mechanically reads the
matrix's own Status / Notes / Evidence cells and reports what the matrix says
is machine-checked, what it says is assumed, and what it says is only tested
cross-language. Rows may appear in more than one section, because the matrix
itself records proved cores that are conditional on assumptions, or proved
Lean sides whose Go bridge is empirical rather than machine-checked.

Stdlib-only. Mirrors the `--repo-root` / `--check` interface of the other
generators in this directory (see generate_formal_validation_report.py).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MATRIX_REL = "proofs/FORMAL_TRACEABILITY_MATRIX.md"
CLAIMS_REL = "proofs/theorem_claims.json"
OUTPUT_REL = "docs/FORMAL_CLAIM_BOUNDARY.md"

EVIDENCE_ARTIFACTS = [
    (
        "WeightUpdateCircuit proof artifact",
        "../results/zk/weight-proof-latest.json",
        "real gnark Groth16 circuit (9569 constraints), measured prove/verify costs; not a knowledge-soundness proof",
    ),
    (
        "Byzantine partition probe",
        "../results/go-live/evidence/partition_probe_2026-08-10.json",
        "empirical BFT partition evidence, not a machine-checked claim",
    ),
    (
        "Transport congestion probe",
        "../results/go-live/evidence/transport_congestion_probe_2026-08-10.json",
        "empirical transport impairment evidence",
    ),
    (
        "Transport delay probe",
        "../results/go-live/evidence/transport_delay_probe_2026-08-10.json",
        "empirical transport impairment evidence",
    ),
    (
        "Transport impairment probe",
        "../results/go-live/evidence/transport_impairment_probe_2026-08-10.json",
        "empirical transport impairment evidence",
    ),
    ("Evidence package guide", "EVIDENCE_PACKAGE.md", "how the artifacts are produced and checked"),
]

# A matrix row may wrap across physical lines (long Notes cells). Rejoin those
# before parsing -- the same rule check_claim_transitions.py uses. Parsing
# physical lines would stop the table at its first wrapped row (row 2).
ROW_RE = re.compile(r"^\|(.+)\|\s*$", re.DOTALL)
SEP_RE = re.compile(r"^\|[\s:|-]+\|\s*$")
NUMBERED_ROW_RE = re.compile(r"^\d+$")

# --- Classification rules -------------------------------------------------
# These are *rules over matrix text*, not hard-coded row lists: a matrix edit
# automatically moves a row between sections on the next regeneration.

# "Only tested": the row's own cells say the cross-language correspondence is
# empirical, by definition/inspection, or formula-level -- not a machine-checked
# equality against Go. Searched over every cell (the phrase can sit in the
# Evidence cell as well as Notes).
ONLY_TESTED_RE = re.compile(
    r"empirically_"
    r"|formula_level_correspondence_only"
    r"|correspondence is by inspection"
    r"|correspondence is by definition"
    r"|matched by definition rather than by a machine.checked equality",
    re.IGNORECASE,
)

# "Proved": the Status cell leads with a machine-checked marker (or states a
# derived identity). Leading-token match avoids false positives from the word
# "proved" inside negations such as "NOT proved".
PROVED_STATUS_RE = re.compile(
    r"^\s*`?\s*("
    r"fully[ _]formalized"
    r"|measure_theoretic_verified"
    r"|model_verified"
    r"|verified"
    r"|hypothesis_necessity_proved"
    r"|structural_refinement"
    r"|bridge_fully_formalized"
    r"|group_law_partially_formalized"
    r"|bridge_partial"
    r"|machine.check"
    r"|mass_conservation_proved"
    r"|circuit_relation_modeled"
    r"|gaussian_rdp_derived"
    r"|fixed_vacuous_stub"
    r"|refinement_rebuilt"
    r"|phase\s*\d+[a-z]?\s*model"
    r")",
    re.IGNORECASE,
)
DERIVED_STATUS_RE = re.compile(r"\bderived\b|\bno residual hypothesis\b", re.IGNORECASE)

# "Assumed": explicit hypotheses / model assumptions the proof consumes. Each
# entry is (short label shown in the doc, pattern). Matched over the whole row.
ASSUMPTION_RULES: list[tuple[str, str]] = [
    ("SchnorrDLHard", r"SchnorrDLHard"),
    ("Ed25519GroupLaws", r"Ed25519GroupLaws"),
    ("FloatOrderLaws", r"FloatOrderLaws"),
    ("Fact (Nat.Prime ...)", r"Fact \(Nat\.Prime"),
    ("assumed", r"\bassumed\b"),
    ("assumption", r"\bassumption\b"),
    ("explicit hypothesis", r"\bexplicit hypothesis\b"),
    ("unbiasedness", r"\bunbiasedness\b"),
    ("clustering/separation model", r"clustering|separation model"),
    ("i.i.d. model", r"i\.i\.d"),
    ("uniform-challenge RO", r"uniform.challenge"),
    ("descent lemma hypothesis", r"descent lemma"),
    ("constants as parameter", r"constants are a parameter"),
    ("witnessed acceptance", r"\bwitnessed\b"),
    ("conditional on invariants", r"\bconditional\b"),
    ("not proved / not unconditional", r"NOT proved|not unconditional"),
    (
        "scope limit (not claimed/formalized/refined/recovered)",
        r"NOT claimed|NOT formalized|NOT refined|NOT recovered",
    ),
]

# Named standing assumptions: derived from the matrix text, reported in the
# doc and returned by residual_hypotheses() for machine consumers.
STANDING_ASSUMPTIONS: list[tuple[str, str]] = [
    ("FloatOrderLaws", r"FloatOrderLaws"),
    ("Fact (Nat.Prime q)", r"Fact \(Nat\.Prime"),
    ("SchnorrDLHard", r"SchnorrDLHard"),
    ("Ed25519GroupLaws", r"Ed25519GroupLaws"),
]


def logical_table_rows(text: str) -> list[str]:
    """Rejoin wrapped markdown rows into one string per logical row."""
    rows: list[str] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|"):
            parts = [lines[i]]
            j = i
            while j + 1 < len(lines) and not "\n".join(parts).rstrip().endswith("|"):
                j += 1
                parts.append(lines[j])
            rows.append("\n".join(parts))
            i = j + 1
        else:
            i += 1
    return rows


def flat(cell: str) -> str:
    """Collapse a cell to one line, keeping it safe for a markdown bullet."""
    return re.sub(r"\s+", " ", cell).strip()


def parse_main_table(matrix_text: str) -> tuple[list[dict], int]:
    """Return (rows, status_column_index) for the numbered main table."""
    parsed: list[list[str]] = []
    for raw in logical_table_rows(matrix_text):
        match = ROW_RE.match(raw)
        if match:
            parsed.append([cell.strip() for cell in match.group(1).split("|")])

    header = next((c for c in parsed if c and c[0] == "#" and "Status" in c), None)
    if header is None:
        raise ValueError("no main traceability table (header with 'Status') found in matrix")
    status_col = header.index("Status")

    start = parsed.index(header) + 1
    while start < len(parsed) and SEP_RE.match("|" + "|".join(parsed[start]) + "|"):
        start += 1

    rows: list[dict] = []
    for cells in parsed[start:]:
        if not cells or not NUMBERED_ROW_RE.match(cells[0]):
            break  # end of the main numbered table
        if len(cells) <= status_col:
            raise ValueError(f"matrix row {cells[0]} has no Status cell")
        notes = flat(cells[status_col + 1]) if len(cells) > status_col + 1 else ""
        rows.append(
            {
                "id": int(cells[0]),
                "claim": flat(cells[1]),
                "status": flat(cells[status_col]),
                "notes": notes,
                "text": " ".join(flat(c) for c in cells),
            }
        )

    ids = [row["id"] for row in rows]
    if ids != list(range(1, len(rows) + 1)):
        raise ValueError(f"matrix main-table ids are not 1..N contiguous: {ids}")
    if not rows:
        raise ValueError("matrix main table has no data rows")
    return rows, status_col


def classify(rows: list[dict]) -> dict[str, list[dict]]:
    buckets: dict[str, list[dict]] = {"proved": [], "assumed": [], "only_tested": []}
    for row in rows:
        only_tested = ONLY_TESTED_RE.search(row["text"]) is not None
        proved = (
            PROVED_STATUS_RE.search(row["status"]) is not None
            or DERIVED_STATUS_RE.search(row["status"]) is not None
        ) and not only_tested

        tags: list[str] = []
        for label, pattern in ASSUMPTION_RULES:
            if re.search(pattern, row["text"], re.IGNORECASE) and label not in tags:
                tags.append(label)

        if proved:
            buckets["proved"].append(row)
        if tags:
            entry = dict(row)
            entry["assumption_tags"] = tags
            buckets["assumed"].append(entry)
        if only_tested:
            buckets["only_tested"].append(row)
    return buckets


def residual_hypotheses(matrix_text: str) -> list[str]:
    """Named standing assumptions actually present in the matrix text."""
    return [name for name, pattern in STANDING_ASSUMPTIONS if re.search(pattern, matrix_text)]


def short(text: str, limit: int = 96) -> str:
    text = flat(text).replace("|", "\\|")
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def code(text: str, limit: int = 72) -> str:
    """Inline-code a cell that may already contain backticks/bold markers."""
    cleaned = short(text, limit).replace("`", "").replace("**", "")
    return f"`{cleaned}`"


def render(
    rows: list[dict],
    buckets: dict[str, list[dict]],
    claims_count: int,
    residuals: list[str],
    matrix_rel: str,
    claims_rel: str,
) -> str:
    n = len(rows)
    lines: list[str] = []
    lines.append("# Formal Claim Boundary")
    lines.append("")
    lines.append(
        f"> Generated by `scripts/ci/generate_formal_claim_boundary.py` from "
        f"`{matrix_rel}` ({n} rows) and the claim taxonomy in `{claims_rel}` "
        f"({claims_count} records). Do not hand-edit; re-run the generator."
    )
    lines.append("")
    lines.append(
        "One-page reviewer map of what the formalization actually establishes. "
        "Every bullet is a traceability-matrix row, classified mechanically from "
        "its own Status / Notes / Evidence cells. Sections may overlap: a "
        "machine-checked core can be conditional on an assumption, and a proved "
        "Lean side can have an empirical-only Go bridge. Counts are derived."
    )
    lines.append("")

    # Section 1 -- proved.
    lines.append("## What is proved")
    lines.append("")
    lines.append(
        f"{len(buckets['proved'])} of {n} rows carry a machine-checked core recorded "
        "in the matrix Status cell (Lean theorem, proved bound, derived identity, "
        "or closed refinement):"
    )
    lines.append("")
    for row in buckets["proved"]:
        lines.append(f"- Row {row['id']} — {short(row['claim'])} — {code(row['status'])}")
    lines.append("")

    # Section 2 -- assumed.
    lines.append("## What is assumed")
    lines.append("")
    lines.append(
        f"{len(buckets['assumed'])} rows rest on an explicit hypothesis or model "
        "assumption the proof consumes rather than discharges. The named standing "
        "assumptions visible in the matrix are:"
    )
    lines.append("")
    for name in residuals:
        consuming = [
            r["id"]
            for r in rows
            if re.search(dict(STANDING_ASSUMPTIONS)[name], r["text"], re.IGNORECASE)
        ]
        lines.append(f"- `{name}` — matrix row(s) {', '.join(str(i) for i in consuming)}")
    lines.append("")
    lines.append("Rows with an assumed or conditional guarantee:")
    lines.append("")
    for row in buckets["assumed"]:
        tags = "; ".join(row["assumption_tags"])
        lines.append(f"- Row {row['id']} — {short(row['claim'])} — {short(tags, 96)}")
    lines.append("")

    # Section 3 -- only tested.
    lines.append("## What is only tested")
    lines.append("")
    lines.append(
        f"{len(buckets['only_tested'])} rows justify their cross-language claim by "
        "empirical testing or a by-definition / by-inspection correspondence, not "
        "by a machine-checked equality against the Go runtime:"
    )
    lines.append("")
    for row in buckets["only_tested"]:
        lines.append(f"- Row {row['id']} — {short(row['claim'])} — {code(row['status'])}")
    lines.append("")
    # Section 4 -- static reviewer evidence index.
    lines.append("## Reviewer evidence index")
    lines.append("")
    lines.append(
        "Checked-in artifacts behind the empirical and cost claims above. "
        "These are repository files, not live measurements: the ZK costs come "
        "from the real circuit, knowledge soundness is external, and setup is "
        "an in-process simulated MPC ceremony:"
    )
    lines.append("")
    for label, link, note in EVIDENCE_ARTIFACTS:
        lines.append(f"- {label}: [`{link}`]({link}) — {note}")
    lines.append("")
    return "\n".join(lines)


def compute(repo_root: Path) -> str:
    matrix_path = repo_root / MATRIX_REL
    claims_path = repo_root / CLAIMS_REL
    for path in (matrix_path, claims_path):
        if not path.exists():
            raise FileNotFoundError(f"missing required input: {path}")
    matrix_text = matrix_path.read_text(encoding="utf-8")
    claims = json.loads(claims_path.read_text(encoding="utf-8"))
    claims_count = len(claims.get("claims", []))
    rows, _ = parse_main_table(matrix_text)
    buckets = classify(rows)
    residuals = residual_hypotheses(matrix_text)
    return render(rows, buckets, claims_count, residuals, MATRIX_REL, CLAIMS_REL)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate (or --check) the one-page formal claim boundary doc"
    )
    parser.add_argument("--repo-root", default=".", help="Repository root directory")
    parser.add_argument(
        "--output", default=OUTPUT_REL, help="Output path (relative to repo root unless absolute)"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the output file differs from the regenerated content",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output = Path(args.output)
    if not output.is_absolute():
        output = repo_root / output

    computed = compute(repo_root)

    if args.check:
        if not output.exists():
            raise FileNotFoundError(f"missing boundary doc for --check: {output}")
        # Universal-newline read: a CRLF checkout must not create a false drift.
        current = output.read_text(encoding="utf-8")
        if current != computed:
            print(f"formal claim boundary mismatch: {output}")
            print("regenerate with:")
            print("  python3 scripts/ci/generate_formal_claim_boundary.py")
            return 1
        print(f"formal claim boundary check passed: {output}")
        return 0

    # Explicit LF so generated output is identical on Windows and Linux CI.
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(computed)
    print(f"wrote formal claim boundary: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
