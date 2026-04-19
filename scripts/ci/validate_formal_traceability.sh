#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX_FILE="$ROOT_DIR/proofs/FORMAL_TRACEABILITY_MATRIX.md"
ENTRY_FILE="$ROOT_DIR/proofs/LeanFormalization.lean"

if [[ ! -f "$MATRIX_FILE" ]]; then
  echo "ERROR: Missing traceability matrix: $MATRIX_FILE"
  exit 1
fi

if [[ ! -f "$ENTRY_FILE" ]]; then
  echo "ERROR: Missing Lean entry file: $ENTRY_FILE"
  exit 1
fi

# Ensure all six formal theorem modules are imported by the entry file.
expected_modules=(
  "Theorem1BFT"
  "Theorem2RDP"
  "Theorem3Communication"
  "Theorem4Liveness"
  "Theorem5Cryptography"
  "Theorem6Convergence"
)

for mod in "${expected_modules[@]}"; do
  if ! grep -q "import LeanFormalization.$mod" "$ENTRY_FILE"; then
    echo "ERROR: Lean entry file missing import for module $mod"
    exit 1
  fi
  if ! grep -q "LeanFormalization/$mod.lean" "$MATRIX_FILE"; then
    echo "ERROR: Traceability matrix missing Lean module row for $mod"
    exit 1
  fi
done

# Ensure runtime evidence links are present for each theorem row.
expected_runtime_tests=(
  "internal/multikrum_test.go::TestMultiKrumSelect"
  "test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget"
  "test/manifest_test.go::TestValidateCommunicationComplexity_Valid"
  "test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass"
  "test/zk_verifier_test.go::TestVerifyZKProof"
  "test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below"
)

for token in "${expected_runtime_tests[@]}"; do
  if ! grep -q "$token" "$MATRIX_FILE"; then
    echo "ERROR: Traceability matrix missing runtime test reference $token"
    exit 1
  fi
done

# Ensure referenced runtime test files actually exist and contain the listed test names.
while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  rel_file="${token%%::*}"
  test_name="${token#*::}"
  abs_file="$ROOT_DIR/$rel_file"
  if [[ ! -f "$abs_file" ]]; then
    echo "ERROR: Runtime test file missing: $rel_file"
    exit 1
  fi
  if ! grep -q "func $test_name(" "$abs_file"; then
    echo "ERROR: Runtime test symbol missing: $test_name in $rel_file"
    exit 1
  fi
done < <(printf "%s\n" "${expected_runtime_tests[@]}")

echo "Traceability validation passed."
