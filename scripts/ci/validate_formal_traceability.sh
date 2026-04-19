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

while IFS='|' read -r _ claim_source module_cell theorem_cell runtime_cell _; do
  [[ -z "${module_cell// }" ]] && continue
  module_cell="${module_cell//\`/}"
  theorem_cell="${theorem_cell//\`/}"
  runtime_cell="${runtime_cell//\`/}"

  module_cell="$(echo "$module_cell" | xargs)"
  theorem_cell="$(echo "$theorem_cell" | xargs)"
  runtime_cell="$(echo "$runtime_cell" | xargs)"

  [[ "$module_cell" == "Lean Module" ]] && continue
  [[ "$module_cell" != LeanFormalization/* ]] && continue

  module_name="${module_cell##*/}"
  module_name="${module_name%.lean}"
  module_to_theorems["$module_name"]+="${theorem_cell}"
done < <(awk 'BEGIN { FS = "|" } /^\|/ { print }' "$MATRIX_FILE")

validated_theorems=0
for mod in "${!module_to_theorems[@]}"; do
  module_file="$ROOT_DIR/proofs/LeanFormalization/$mod.lean"
  [[ -f "$module_file" ]] || fail "Lean module file missing: $mod.lean"

  IFS=',' read -r -a theorem_names <<< "${module_to_theorems[$mod]}"
  for theorem_name in "${theorem_names[@]}"; do
    theorem_name="$(echo "$theorem_name" | xargs)"
    [[ -n "$theorem_name" ]] || continue
    if ! grep -nF "$theorem_name" "$module_file" | grep -qE '^[0-9]+:[[:space:]]*(theorem|def)[[:space:]]+'; then
      fail "Missing theorem symbol '$theorem_name' in $mod.lean"
    fi
    validated_theorems=$((validated_theorems + 1))
  done
done

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
