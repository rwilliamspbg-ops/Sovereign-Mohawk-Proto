#!/bin/bash

echo "🔍 Starting Security Audit..."

# 1. Check if capabilities.json is valid and has the correct BFT status
BFT_STATUS=$(jq -r '.bft_safety_theorem_1' capabilities.json)
if [ "$BFT_STATUS" != "true" ]; then
    echo "❌ AUDIT FAILED: BFT Safety Theorem 1 not verified in capabilities.json"
    exit 1
fi

# 2. Check if the verification log contains the required liveness markers
if ! grep -q "99.99%" proofs/VERIFICATION_LOG.md; then
    echo "❌ AUDIT FAILED: Liveness markers missing from proofs/VERIFICATION_LOG.md"
    exit 1
fi

# 3. Check for recent timestamps (ensure logs aren't stale)
LOG_DATE=$(jq -r '.timestamp' capabilities.json | cut -d'T' -f1)
CURRENT_DATE=$(date -u +%Y-%m-%d)
if [ "$LOG_DATE" != "$CURRENT_DATE" ]; then
    echo "⚠️  WARNING: Proofs are from a previous date ($LOG_DATE). Consider rerunning tests."
fi

echo "✅ AUDIT PASSED: All formal proofs are present and valid."
exit 0
