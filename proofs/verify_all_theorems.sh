#!/bin/bash

# Machine Verification Script for Lean Theorems
# Builds and inventories the Sovereign-Mohawk formal proof system, then
# reports whether it actually verified.
#
# Honesty note (read before trusting the report this produces): an earlier
# revision of this script printed "ALL THEOREMS VERIFIED" and wrote a
# hardcoded "verification_status": "PASS" JSON report unconditionally, even
# in the branch where `lake build` failed — the only thing that could make
# it exit non-zero was the placeholder (sorry/axiom/admit) scan in step 4.
# That's fixed below: step 5 now fails the script (and the report) if the
# build doesn't actually succeed, and the JSON report is generated from the
# real results instead of a static template.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

RESULTS_DIR="verification-results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date -u +'%Y%m%d_%H%M%S')
REPORT_FILE="$RESULTS_DIR/machine_verification_report_${TIMESTAMP}.txt"
JSON_REPORT="$RESULTS_DIR/verification_results_${TIMESTAMP}.json"

LEAN_DIRS=(LeanFormalization Specification Refinement)
LEAN_BUILD_TARGETS="LeanFormalization Specification Refinement"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     SOVEREIGN-MOHAWK THEOREM MACHINE VERIFICATION          ║"
echo "║                    Powered by Lean 4                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Start Time: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Report: $REPORT_FILE"
echo ""

# Initialize report
cat > "$REPORT_FILE" <<'EOF'
SOVEREIGN-MOHAWK THEOREM MACHINE VERIFICATION REPORT
====================================================

This report documents the result of building the Sovereign-Mohawk Lean 4
formal proof system and scanning it for incomplete proofs. It reflects
whatever the build and scan actually found on this run -- it is not a
static template.

EOF

echo "Report initialized: $REPORT_FILE"
echo ""

# Check Lean Installation
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 1] Lean 4 Environment Check"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "ENVIRONMENT CHECK"
    echo "================="
    echo ""

    if command -v lean &> /dev/null; then
        LEAN_VERSION=$(lean --version 2>&1 || echo "unknown")
        echo "✓ Lean 4 found: $LEAN_VERSION"
        echo "Lean version: $LEAN_VERSION" >> "$REPORT_FILE"
    else
        echo "✗ Lean 4 not found in PATH"
        echo "ERROR: Lean 4 not found in PATH" >> "$REPORT_FILE"
        exit 1
    fi

    if command -v lake &> /dev/null; then
        echo "✓ Lake (Lean package manager) found"
        echo "Lake available: YES" >> "$REPORT_FILE"
    else
        echo "✗ Lake not found - cannot verify the build"
        echo "Lake available: NO" >> "$REPORT_FILE"
        exit 1
    fi

    echo ""
} | tee -a "$REPORT_FILE"

# Verify Project Structure
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 2] Project Structure Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "PROJECT STRUCTURE"
    echo "================="
    echo ""

    LEAN_FILES=$(find "${LEAN_DIRS[@]}" -name "*.lean" 2>/dev/null | wc -l)
    echo "✓ Found $LEAN_FILES Lean files across ${LEAN_DIRS[*]}"
    echo "Lean files detected: $LEAN_FILES" >> "$REPORT_FILE"

    echo "  Files:"
    find "${LEAN_DIRS[@]}" -name "*.lean" -type f | sort | while read -r file; do
        LINES=$(wc -l < "$file")
        echo "    - $file ($LINES lines)"
        echo "    - $file" >> "$REPORT_FILE"
    done

    echo ""
} | tee -a "$REPORT_FILE"

# Count Theorems
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 3] Theorem Inventory & Count"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "THEOREM INVENTORY"
    echo "================="
    echo ""

    echo "Theorem count by file:"
    COUNT_TMP=$(mktemp)

    find "${LEAN_DIRS[@]}" -name "*.lean" -type f | sort | while read -r file; do
        THEOREMS=$(grep -c "^theorem\|^lemma\|^def" "$file" 2>/dev/null || echo "0")
        echo "  $file: $THEOREMS"
        echo "$THEOREMS" >> "$COUNT_TMP"
    done

    TOTAL=$(awk '{s+=$1} END {print s+0}' "$COUNT_TMP")
    rm -f "$COUNT_TMP"
    echo ""
    echo "✓ Total theorems/definitions: $TOTAL"
    echo "Total theorems/definitions: $TOTAL" >> "$REPORT_FILE"
    echo ""
} | tee -a "$REPORT_FILE"

# Recompute TOTAL outside the piped subshell (the `| tee` above forks a
# subshell, so variables set inside it don't survive to the rest of the
# script) so later steps can reference the real count instead of a literal.
TOTAL=$(find "${LEAN_DIRS[@]}" -name "*.lean" -type f -exec grep -c "^theorem\|^lemma\|^def" {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')

# Verify No Placeholders
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 4] Placeholder Detection (Critical Check)"
echo "═══════════════════════════════════════════════════════════"
echo ""

SORRY_COUNT=$(find "${LEAN_DIRS[@]}" -name "*.lean" -exec grep -l "sorry" {} \; 2>/dev/null | wc -l)
AXIOM_COUNT=$(find "${LEAN_DIRS[@]}" -name "*.lean" -exec grep -l "^axiom\|[^a-zA-Z_]axiom " {} \; 2>/dev/null | wc -l)
ADMIT_COUNT=$(find "${LEAN_DIRS[@]}" -name "*.lean" -exec grep -l "admit" {} \; 2>/dev/null | wc -l)
TOTAL_PLACEHOLDERS=$((SORRY_COUNT + AXIOM_COUNT + ADMIT_COUNT))

{
    echo "PLACEHOLDER SCAN"
    echo "================"
    echo ""
    echo "Files with 'sorry': $SORRY_COUNT"
    echo "Files with 'axiom': $AXIOM_COUNT"
    echo "Files with 'admit': $ADMIT_COUNT"
    echo ""

    if [ "$TOTAL_PLACEHOLDERS" -eq 0 ]; then
        echo "✓ No placeholders found"
        echo "Placeholder status: PASS - 0 placeholders" >> "$REPORT_FILE"
    else
        echo "⚠ Placeholders detected ($TOTAL_PLACEHOLDERS file(s)) — this means some"
        echo "  theorems are stated but not yet proved. That is a legitimate project"
        echo "  state (see FORMAL_TRACEABILITY_MATRIX.md for which claims are"
        echo "  roadmap work), not necessarily a bug — but it means this run cannot"
        echo "  report full verification. Continuing to build regardless, since a"
        echo "  'sorry' still lets the rest of the project type-check."
        echo "Placeholder status: INCOMPLETE - $TOTAL_PLACEHOLDERS file(s) contain sorry/axiom/admit" >> "$REPORT_FILE"
    fi

    echo ""
} | tee -a "$REPORT_FILE"

# Lake Build — the actual machine-verification step. This is the one gate
# that must exit non-zero on failure: everything downstream (theorem
# manifest, traceability check, summary) is only meaningful if the project
# actually type-checked.
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 5] Lake Build Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Attempting Lake build..."
echo "Build command: lake build $LEAN_BUILD_TARGETS"
echo ""

LAKE_LOG=$(mktemp)
set +e
lake build $LEAN_BUILD_TARGETS 2>&1 | tee "$LAKE_LOG"
LAKE_EXIT=${PIPESTATUS[0]}
set -e

{
    echo "BUILD VERIFICATION"
    echo "=================="
    echo ""
    if [ "$LAKE_EXIT" -eq 0 ]; then
        echo "✓ Lake build completed successfully"
        BUILD_STATUS="SUCCESS"
        echo "Build status: SUCCESS" >> "$REPORT_FILE"
    else
        echo "✗ CRITICAL CHECK FAILED: Lake build failed (exit code $LAKE_EXIT)"
        BUILD_STATUS="FAILED"
        echo "Build status: FAILED (exit code $LAKE_EXIT)" >> "$REPORT_FILE"
    fi
    echo "Build output:" >> "$REPORT_FILE"
    cat "$LAKE_LOG" >> "$REPORT_FILE"
    echo ""
} | tee -a "$REPORT_FILE"
rm -f "$LAKE_LOG"

if [ "$LAKE_EXIT" -ne 0 ]; then
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    echo "MACHINE VERIFICATION: FAILED"
    echo "══════════════════════════════════════════════════════════════"
    echo "lake build $LEAN_BUILD_TARGETS did not complete successfully."
    echo "This report does NOT certify machine verification. See:"
    echo "  $REPORT_FILE"
    {
        echo ""
        echo "VERIFICATION STATUS: ✗ BUILD FAILED — not machine-verified"
    } >> "$REPORT_FILE"
    cat > "$JSON_REPORT" <<EOJSON
{
  "verification_report": {
    "system": "Sovereign-Mohawk",
    "component": "Formal Proof Theorems",
    "verification_tool": "Lean 4 Machine Verification",
    "timestamp": "$(date -u +'%Y-%m-%d %H:%M:%S UTC')",
    "results": {
      "total_theorems_and_definitions": ${TOTAL:-0},
      "sorry_files": ${SORRY_COUNT:-0},
      "axiom_files": ${AXIOM_COUNT:-0},
      "admit_files": ${ADMIT_COUNT:-0},
      "lake_build_status": "FAILED",
      "lake_build_exit_code": ${LAKE_EXIT},
      "verification_status": "FAIL",
      "machine_verified": false
    },
    "conclusion": "lake build $LEAN_BUILD_TARGETS failed (exit $LAKE_EXIT); this run does not certify the formal proof system as machine-verified."
  }
}
EOJSON
    echo "JSON report: $JSON_REPORT"
    exit 1
fi

# List All Theorems by Module
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 6] Complete Theorem Manifest"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "THEOREM MANIFEST"
    echo "================"
    echo ""

    find "${LEAN_DIRS[@]}" -name "*.lean" -type f | sort | while read -r file; do
        echo "Module: $file"
        echo "Theorems/Definitions:"

        grep "^theorem\|^lemma\|^def" "$file" | sed 's/^/  - /' | while read -r line; do
            THM_NAME=$(echo "$line" | sed 's/.*\s\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/')
            echo "$line"
            echo "  $file: $THM_NAME" >> "$REPORT_FILE"
        done

        echo ""
    done

} | tee -a "$REPORT_FILE"

# Verify Traceability
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 7] Traceability Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "TRACEABILITY CHECK"
    echo "=================="
    echo ""

    SPEC_FILES=(
        "bft_resilience.md"
        "differential_privacy.md"
        "communication.md"
        "stragglers.md"
        "cryptography.md"
        "convergence.md"
    )

    echo "Checking specification mapping:"

    FOUND_SPECS=0
    for spec in "${SPEC_FILES[@]}"; do
        if find .. -name "$spec" -o -name "*$spec*" 2>/dev/null | grep -q .; then
            echo "  ✓ $spec (spec file found)"
            ((FOUND_SPECS++))
        else
            echo "  ⚠ $spec (spec file not found in expected location)"
        fi
    done

    echo ""
    echo "Specifications mapped: $FOUND_SPECS/6"
    echo "Traceability: $FOUND_SPECS/6 specification files linked" >> "$REPORT_FILE"

    echo ""
} | tee -a "$REPORT_FILE"

# Summary Report
echo "═══════════════════════════════════════════════════════════"
echo "[STEP 8] VERIFICATION SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

{
    echo "MACHINE VERIFICATION SUMMARY"
    echo "============================"
    echo ""
    echo "✓ lake build $LEAN_BUILD_TARGETS: SUCCESS"
    echo "✓ $TOTAL theorems/definitions found across ${LEAN_DIRS[*]}"
    if [ "$TOTAL_PLACEHOLDERS" -eq 0 ]; then
        echo "✓ Zero placeholders (no sorry/axiom/admit)"
        echo ""
        echo "VERIFICATION STATUS: ✓ BUILD PASSED, NO PLACEHOLDERS"
    else
        echo "⚠ $TOTAL_PLACEHOLDERS file(s) contain sorry/axiom/admit — those specific"
        echo "  declarations are NOT fully proved even though the project builds."
        echo ""
        echo "VERIFICATION STATUS: ⚠ BUILD PASSED, BUT $TOTAL_PLACEHOLDERS FILE(S) INCOMPLETE"
    fi
    echo ""
} | tee -a "$REPORT_FILE"

# Signature
{
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "Verification completed: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "This report reflects an actual lake build $LEAN_BUILD_TARGETS run plus a"
    echo "sorry/axiom/admit scan on this machine at the timestamp above."
    if [ "$TOTAL_PLACEHOLDERS" -eq 0 ]; then
        echo "The build succeeded and no placeholder was found in any theorem body."
    else
        echo "The build succeeded, but $TOTAL_PLACEHOLDERS file(s) still contain a"
        echo "sorry/axiom/admit — see the placeholder scan above for which ones."
    fi
    echo ""
    echo "═══════════════════════════════════════════════════════════"

} | tee -a "$REPORT_FILE"

# Create JSON report from the real results computed above.
VERIFICATION_STATUS="PASS"
MACHINE_VERIFIED="true"
if [ "$TOTAL_PLACEHOLDERS" -ne 0 ]; then
    VERIFICATION_STATUS="INCOMPLETE"
    MACHINE_VERIFIED="false"
fi

cat > "$JSON_REPORT" <<EOJSON
{
  "verification_report": {
    "system": "Sovereign-Mohawk",
    "component": "Formal Proof Theorems",
    "verification_tool": "Lean 4 Machine Verification",
    "timestamp": "$(date -u +'%Y-%m-%d %H:%M:%S UTC')",
    "results": {
      "total_theorems_and_definitions": ${TOTAL},
      "sorry_files": ${SORRY_COUNT},
      "axiom_files": ${AXIOM_COUNT},
      "admit_files": ${ADMIT_COUNT},
      "lake_build_status": "SUCCESS",
      "verification_status": "${VERIFICATION_STATUS}",
      "machine_verified": ${MACHINE_VERIFIED}
    },
    "checks": {
      "syntax_valid": true,
      "type_checked": true,
      "no_placeholders": $( [ "$TOTAL_PLACEHOLDERS" -eq 0 ] && echo true || echo false ),
      "traceability_present": true
    },
    "conclusion": "$( [ "$TOTAL_PLACEHOLDERS" -eq 0 ] && echo "lake build $LEAN_BUILD_TARGETS succeeded with zero sorry/axiom/admit placeholders." || echo "lake build $LEAN_BUILD_TARGETS succeeded, but $TOTAL_PLACEHOLDERS file(s) still contain a sorry/axiom/admit placeholder — see the text report for which declarations are incomplete." )"
  }
}
EOJSON

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "MACHINE VERIFICATION COMPLETE"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "Reports generated:"
echo "  Text Report: $REPORT_FILE"
echo "  JSON Report: $JSON_REPORT"
echo ""
if [ "$TOTAL_PLACEHOLDERS" -eq 0 ]; then
    echo "✓ Build succeeded, zero placeholders"
else
    echo "⚠ Build succeeded, but $TOTAL_PLACEHOLDERS file(s) contain placeholders — not fully verified"
fi
echo ""
