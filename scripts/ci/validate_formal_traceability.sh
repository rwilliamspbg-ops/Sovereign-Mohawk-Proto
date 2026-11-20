#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX_FILE="$ROOT_DIR/proofs/FORMAL_TRACEABILITY_MATRIX.md"
ENTRY_FILE="$ROOT_DIR/proofs/LeanFormalization.lean"

fail() {
  echo "ERROR: $1"
  exit 1
}

if [[ ! -f "$MATRIX_FILE" ]]; then
  fail "Missing traceability matrix: $MATRIX_FILE"
fi

if [[ ! -f "$ENTRY_FILE" ]]; then
  fail "Missing Lean entry file: $ENTRY_FILE"
fi

mapfile -t expected_modules < <(
  grep -oE 'LeanFormalization/Theorem[0-9]+[A-Za-z]*\.lean' "$MATRIX_FILE" |
    sed -E 's|LeanFormalization/||; s|\.lean$||' |
    sort -u
)

if [[ ${#expected_modules[@]} -eq 0 ]]; then
  fail "No Lean modules found in traceability matrix"
fi

for mod in "${expected_modules[@]}"; do
  if ! grep -q "import LeanFormalization.$mod" "$ENTRY_FILE"; then
    fail "Lean entry file missing import for module $mod"
  fi
  if ! grep -q "LeanFormalization/$mod\.lean" "$MATRIX_FILE"; then
    fail "Traceability matrix missing Lean module row for $mod"
  fi
done

# Rows are grouped by their Lean-module cell, which may list ONE module
# (`LeanFormalization/Theorem1BFT.lean`) or SEVERAL (`Refinement/MultiKrum.lean`,
# `Specification/System.lean`). A theorem symbol is accepted if it is declared in
# ANY module of the group. Previously only `LeanFormalization/*` cells were
# considered and the path was hard-coded to `proofs/LeanFormalization/`, so every
# `Refinement/` and `Specification/` row -- including the ZK-circuit row 22 --
# silently escaped the check while the summary still reported a symbol count.
declare -A group_to_theorems=()

trim() {
  echo "$1" | xargs
}

# Parse only numbered mapping rows from the markdown table.
while IFS='|' read -r _ row_num _ _ module_cell theorem_cell runtime_cell _ _; do
  row_num="$(trim "$row_num")"
  module_cell="${module_cell//\`}"
  theorem_cell="${theorem_cell//\`}"
  runtime_cell="${runtime_cell//\`}"

  module_cell="$(trim "$module_cell")"
  theorem_cell="$(trim "$theorem_cell")"
  runtime_cell="$(trim "$runtime_cell")"

  [[ -z "$row_num" ]] && continue
  [[ -z "$module_cell" ]] && continue
  [[ -z "$theorem_cell" ]] && fail "Row $row_num has empty theorem reference cell"
  [[ "$module_cell" != LeanFormalization/* && "$module_cell" != Refinement/* \
     && "$module_cell" != Specification/* ]] && continue

  group_to_theorems["$module_cell"]+="$theorem_cell,"
done < <(awk 'BEGIN { FS = "|" } /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ { print }' "$MATRIX_FILE")

if [[ ${#group_to_theorems[@]} -eq 0 ]]; then
  fail "No theorem mappings parsed from traceability matrix"
fi

validated_theorems=0
for group in "${!group_to_theorems[@]}"; do
  IFS=',' read -r -a module_items <<< "$group"
  module_files=()
  for module_ref in "${module_items[@]}"; do
    module_ref="$(trim "$module_ref")"
    [[ -z "$module_ref" ]] && continue
    module_file="$ROOT_DIR/proofs/$module_ref"
    [[ -f "$module_file" ]] || fail "Lean module file missing: $module_ref"
    module_files+=("$module_file")
  done
  [[ ${#module_files[@]} -eq 0 ]] && continue

  IFS=',' read -r -a theorem_names <<< "${group_to_theorems[$group]}"
  for theorem_name in "${theorem_names[@]}"; do
    theorem_name="$(echo "$theorem_name" | xargs)"
    [[ -n "$theorem_name" ]] || continue
    found=0
    for module_file in "${module_files[@]}"; do
      if grep -qE "^[[:space:]]*((noncomputable|protected|private|unsafe|partial|local)[[:space:]]+)*(theorem|def|lemma|inductive|structure|class|abbrev)[[:space:]]+${theorem_name}\b" "$module_file"; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      fail "Missing theorem symbol '$theorem_name' in $group"
    fi
    validated_theorems=$((validated_theorems + 1))
  done
done

if [[ $validated_theorems -le 0 ]]; then
  fail "No theorem symbols validated; parser output is invalid"
fi

mapfile -t runtime_refs < <(
  grep -oE '[^[:space:]]+\.(go|py)::[A-Za-z0-9_]+' "$MATRIX_FILE" |
    tr -d '\`' |
    sort -u
)

if [[ ${#runtime_refs[@]} -eq 0 ]]; then
  fail "No runtime test references found in traceability matrix"
fi

validated_runtime_tests=0
for token in "${runtime_refs[@]}"; do
  rel_file="${token%%::*}"
  test_name="${token#*::}"
  abs_file="$ROOT_DIR/$rel_file"
  if [[ ! -f "$abs_file" ]]; then
    fail "Runtime test file missing: $rel_file"
  fi
  case "$abs_file" in
    *.go)
      if ! grep -qE "func[[:space:]]+$test_name[[:space:]]*\(" "$abs_file"; then
        fail "Runtime test symbol missing: $test_name in $rel_file"
      fi
      ;;
    *.py)
      if ! grep -qE "def[[:space:]]+$test_name[[:space:]]*\(" "$abs_file"; then
        fail "Runtime test symbol missing: $test_name in $rel_file"
      fi
      ;;
    *)
      fail "Unsupported runtime test file type: $rel_file"
      ;;
  esac
  if ! grep -qF "$token" "$MATRIX_FILE"; then
    fail "Traceability matrix missing runtime test reference $token"
  fi
  validated_runtime_tests=$((validated_runtime_tests + 1))
done

echo "Traceability validation passed."
echo "  - ${#expected_modules[@]} Lean modules imported and present"
echo "  - $validated_theorems theorem symbols validated"
echo "  - $validated_runtime_tests runtime test references validated"
