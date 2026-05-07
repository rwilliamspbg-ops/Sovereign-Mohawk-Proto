#!/bin/bash
# Test Execution and Analysis Script
# Sovereign-Mohawk Phase 1-4 Complete Test Suite

set -e

PROJECT_DIR="C:\Users\rwill\Sovereign-Mohawk-Proto"
REPORT_FILE="$PROJECT_DIR\TEST_EXECUTION_RESULTS.txt"
ANALYSIS_FILE="$PROJECT_DIR\TEST_EXECUTION_ANALYSIS.md"

echo "========================================"
echo "SOVEREIGN-MOHAWK TEST EXECUTION"
echo "Phase 1-4 Complete Suite"
echo "========================================"
echo ""

# Record start time
START_TIME=$(date +%s)
echo "Start Time: $(date)"
echo "Working Directory: $PROJECT_DIR"
echo ""

# Build project
echo "Step 1: Building project..."
if go build ./internal 2>&1 | head -20; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi
echo ""

# Run tests with verbose output
echo "Step 2: Running complete test suite (228 tests)..."
echo "This may take 15-18 minutes..."
echo ""

# Run tests and capture output
go test ./internal -v -run "TestPhase" -timeout 600s 2>&1 | tee "$REPORT_FILE"

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "========================================"
echo "TEST EXECUTION COMPLETE"
echo "========================================"
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo "Report saved to: $REPORT_FILE"
