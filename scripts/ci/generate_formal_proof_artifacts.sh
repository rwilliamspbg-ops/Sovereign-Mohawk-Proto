#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/results/proofs"
ENTRY_FILE="$ROOT_DIR/proofs/LeanFormalization.lean"
MATRIX_FILE="$ROOT_DIR/proofs/FORMAL_TRACEABILITY_MATRIX.md"

mkdir -p "$OUT_DIR"

# Build theorem index from imported theorem modules.
INDEX_FILE="$OUT_DIR/formal_theorem_index.txt"
{
  echo "formal_theorem_index_generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "entry_file=proofs/LeanFormalization.lean"
  echo "modules="
  sed -n 's/^import LeanFormalization\.//p' "$ENTRY_FILE" | sed 's/$/.lean/'
} > "$INDEX_FILE"

# Capture a deterministic copy of the current traceability matrix.
cp "$MATRIX_FILE" "$OUT_DIR/formal_traceability_matrix_snapshot.md"

# Placeholder scan output for auditability.
PLACEHOLDER_REPORT="$OUT_DIR/formal_placeholder_scan.txt"
if grep -RIn "\bsorry\b\|\baxiom\b\|\badmit\b" "$ROOT_DIR/proofs/LeanFormalization" "$ROOT_DIR/proofs"/*.lean > "$PLACEHOLDER_REPORT"; then
  echo "placeholders_found=true" >> "$PLACEHOLDER_REPORT"
else
  echo "placeholders_found=false" > "$PLACEHOLDER_REPORT"
fi

echo "Formal proof artifacts written to $OUT_DIR"
