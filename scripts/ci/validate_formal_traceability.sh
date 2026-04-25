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

declare -A module_to_theorems=()

trim() {
  echo "$1" | xargs
}

# Parse only numbered mapping rows from the markdown table.
while IFS='|' read -r _ row_num _ _ module_cell theorem_cell runtime_cell _ _; do
  row_num="$(trim "$row_num")"
  module_cell="${module_cell//\`/}"
  theorem_cell="${theorem_cell//\`/}"
  runtime_cell="${runtime_cell//\`/}"

  module_cell="$(trim "$module_cell")"
  theorem_cell="$(trim "$theorem_cell")"
  runtime_cell="$(trim "$runtime_cell")"

  [[ -z "$row_num" ]] && continue
  [[ -z "$module_cell" ]] && continue
  [[ -z "$theorem_cell" ]] && fail "Row $row_num has empty theorem reference cell"
  [[ "$module_cell" != LeanFormalization/* ]] && continue

  IFS=',' read -r -a module_items <<< "$module_cell"
  IFS=',' read -r -a theorem_items <<< "$theorem_cell"

  if [[ ${#module_items[@]} -eq ${#theorem_items[@]} ]]; then
    # Row maps one theorem symbol per Lean module (e.g. multi-module integration rows).
    for idx in "${!module_items[@]}"; do
      module_ref="$(trim "${module_items[$idx]}")"
      theorem_ref="$(trim "${theorem_items[$idx]}")"
      [[ -z "$module_ref" ]] && continue
      [[ -z "$theorem_ref" ]] && fail "Row $row_num has empty theorem mapping for module $module_ref"
      module_name="${module_ref##*/}"
      module_name="${module_name%.lean}"
      module_to_theorems["$module_name"]+="${theorem_ref},"
    done
  else
    # Default behavior: all theorem symbols in the row belong to the same module.
    module_name="${module_cell##*/}"
    module_name="${module_name%.lean}"
    module_to_theorems["$module_name"]+="${theorem_cell},"
  fi
done < <(awk 'BEGIN { FS = "|" } /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ { print }' "$MATRIX_FILE")

if [[ ${#module_to_theorems[@]} -eq 0 ]]; then
  fail "No theorem mappings parsed from traceability matrix"
fi

validated_theorems=0
for mod in "${!module_to_theorems[@]}"; do
  module_file="$ROOT_DIR/proofs/LeanFormalization/$mod.lean"
  [[ -f "$module_file" ]] || fail "Lean module file missing: $mod.lean"

  IFS=',' read -r -a theorem_names <<< "${module_to_theorems[$mod]}"
  for theorem_name in "${theorem_names[@]}"; do
    theorem_name="$(echo "$theorem_name" | xargs)"
    [[ -n "$theorem_name" ]] || continue
    if ! grep -qE "^[[:space:]]*(theorem|def|lemma|inductive|structure|class|abbrev)[[:space:]]+${theorem_name}\\b" "$module_file"; then
      fail "Missing theorem symbol '$theorem_name' in $mod.lean"
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
