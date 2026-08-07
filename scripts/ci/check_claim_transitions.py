#!/usr/bin/env python3
"""Fail a PR that silently changes a formal-verification claim's Status.

Every row of proofs/FORMAL_TRACEABILITY_MATRIX.md's main table and its
Workstream 4 table carries a Status column asserting how far that claim's
Lean proof goes (fully_formalized, surrogate_verified_with_gaussian_axiom,
model_verified, and so on). Changing that value -- closing a sorry,
demoting a claim, narrowing its scope -- is exactly the kind of transition
this repo's formal-verification effort exists to keep honest: closed for
real, or explicitly demoted and explained, never silently inflated or
silently downgraded without a record.

This script diffs the matrix's Status columns between a base ref (default
origin/main) and the working tree. For every row whose Status changed, it
requires a matching, newly-added heading in proofs/CLAIM_TRANSITIONS.md --
"newly added" so a generic entry can't be pre-seeded once and reused to
wave through unrelated future changes.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

MATRIX_PATH = "proofs/FORMAL_TRACEABILITY_MATRIX.md"
TRANSITIONS_PATH = Path("proofs/CLAIM_TRANSITIONS.md")

ROW_RE = re.compile(r"^\|(.+)\|\s*$")
SEP_RE = re.compile(r"^\|[\s:|-]+\|\s*$")
# Matches a markdown heading of any level starting with a real YYYY-MM-DD
# date, followed somewhere on the same line by "Row <id>". Requiring a real
# date (not just "##") is deliberate: proofs/CLAIM_TRANSITIONS.md's own
# "Entry format" section shows the template heading
# "## <date> -- Row <id> ..." inside a code fence, with the literal text
# "<date>" -- a naive "^##\s+...Row" pattern matches that template line
# itself as a false positive. A real ISO date can never collide with it.
# Heading level and any "-> " status text are intentionally not required:
# real entries use "###" nested under "## Log" and put the old -> new
# status text in the body (see the two log entries below), not the
# heading -- only the row id is actually consumed by callers.
#
# Group 1 captures the WHOLE heading line (through end of line via `.*$`),
# not just the prefix up to "Row <id>" -- deliberate, and previously a
# real bug: two same-day headings for the same row (e.g. two 2026-08-07
# entries both for "Row 1") share an identical PREFIX up through "Row 1",
# so using only that prefix as a dedup key collapsed two genuinely
# distinct headings into one set entry, even though re.finditer correctly
# found both as separate matches. The full line (which differs after the
# row id -- different short descriptions) is what's actually unique.
TRANSITION_HEADING_RE = re.compile(
    r"^(#{1,6}\s+\d{4}-\d{2}-\d{2}.*?\bRow\s+(\S+).*)$", re.MULTILINE
)


def parse_tables(text: str) -> dict[str, str]:
    """Return {"<table_idx>:<row_key>": status_value} for every data row of
    every pipe-table in the matrix that has a 'Status' column. row_key is
    that row's first-column value (the claim/theorem id), which the matrix
    itself already treats as a stable identifier."""
    statuses: dict[str, str] = {}
    lines = text.splitlines()
    table_idx = -1
    i = 0
    while i < len(lines):
        header_match = ROW_RE.match(lines[i])
        if header_match and i + 1 < len(lines) and SEP_RE.match(lines[i + 1]):
            table_idx += 1
            headers = [c.strip() for c in header_match.group(1).split("|")]
            j = i + 2
            if "Status" not in headers:
                while j < len(lines) and ROW_RE.match(lines[j]):
                    j += 1
                i = j
                continue
            status_col = headers.index("Status")
            while j < len(lines) and ROW_RE.match(lines[j]):
                cells = [c.strip() for c in ROW_RE.match(lines[j]).group(1).split("|")]
                if len(cells) > status_col:
                    statuses[f"{table_idx}:{cells[0]}"] = cells[status_col]
                j += 1
            i = j
            continue
        i += 1
    return statuses


def git_show(ref: str, path: str) -> str | None:
    proc = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True,
        encoding="utf-8",
        check=False,
    )
    return proc.stdout if proc.returncode == 0 else None


def transition_log_headings(text: str) -> set[tuple[str, str]]:
    """Return {(full_heading_match_text, row_id)} for every entry heading.

    Keying on the full matched text (not just the row id) is deliberate: a
    row can legitimately transition more than once over the project's
    life (e.g. row 1 gained a Technique-A entry, then later a separate
    Technique-B entry). Row id alone, deduplicated via a plain set, cannot
    tell "this row already had some entry" apart from "this row's Status
    changed AGAIN and needs a NEW entry" -- confirmed as a real bug: once
    a row had any logged entry, this used to silently accept future
    Status changes on that same row with no new entry required at all.
    Each entry's own heading line (which always includes a date, and
    differs after the row id in its short description) is unique in
    practice, so a genuinely new transition's heading will not collide
    with an old one even when the row id repeats.
    """
    return {(m.group(1), m.group(2)) for m in TRANSITION_HEADING_RE.finditer(text)}


def new_transition_log_row_ids(base_ref: str) -> set[str]:
    # .as_posix(), not str(): on Windows, str(Path(...)) yields
    # backslash-separated paths ("proofs\CLAIM_TRANSITIONS.md"), which
    # `git show <ref>:<path>` silently fails to resolve (git's ref:path
    # syntax always wants forward slashes) -- confirmed as a real bug:
    # git_show returned None on every call on Windows, and the `or ""`
    # fallback below masked it as "no prior entries," making every
    # heading in the working tree look "new" regardless of whether it
    # already existed at base_ref. Invisible in a single-entry file
    # (removing the only entry still correctly showed nothing new either
    # way) but silently wrong the moment a row gained a second, later
    # transition -- exactly the case that surfaced this.
    base_text = git_show(base_ref, TRANSITIONS_PATH.as_posix())
    if base_text is None:
        print(
            f"warning: could not read {TRANSITIONS_PATH} at {base_ref} -- "
            "treating it as having no prior entries. Expected only if this "
            "file predates base_ref; if base_ref is known-good and recent, "
            "this likely means a real read failure, not an absent file.",
            file=sys.stderr,
        )
        base_text = ""
    head_text = TRANSITIONS_PATH.read_text(encoding="utf-8") if TRANSITIONS_PATH.exists() else ""
    base_headings = transition_log_headings(base_text)
    head_headings = transition_log_headings(head_text)
    new_headings = head_headings - base_headings
    return {row_id for _, row_id in new_headings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-ref",
        default="origin/main",
        help="Git ref to diff the matrix against (default: origin/main).",
    )
    args = parser.parse_args()

    base_matrix = git_show(args.base_ref, MATRIX_PATH)
    if base_matrix is None:
        print(
            f"No base matrix found at {args.base_ref}:{MATRIX_PATH} -- "
            "skipping (nothing to diff against)."
        )
        return 0

    head_matrix = Path(MATRIX_PATH).read_text(encoding="utf-8")

    base_statuses = parse_tables(base_matrix)
    head_statuses = parse_tables(head_matrix)

    changed = {
        key: (base_statuses[key], head_statuses[key])
        for key in head_statuses
        if key in base_statuses and base_statuses[key] != head_statuses[key]
    }

    if not changed:
        print("No claim Status transitions in this diff.")
        return 0

    logged_row_ids = new_transition_log_row_ids(args.base_ref)

    missing = [
        (key.split(":", 1)[1], old, new)
        for key, (old, new) in changed.items()
        if key.split(":", 1)[1] not in logged_row_ids
    ]

    if missing:
        print(
            "Claim Status transition(s) found with no matching new entry in " f"{TRANSITIONS_PATH}:"
        )
        for row_id, old, new in missing:
            print(f"  - Row {row_id}: {old!r} -> {new!r}")
        print(
            "\nAdd a heading of the form "
            "'### <YYYY-MM-DD> -- Row <id> (<claim short name>): "
            f"<short description>' to {TRANSITIONS_PATH} (see its own "
            "'Entry format' section), with the old -> new status and a "
            "short rationale in the body below it, before merging."
        )
        return 1

    print(
        f"All {len(changed)} claim Status transition(s) have a matching "
        f"new {TRANSITIONS_PATH} entry."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
