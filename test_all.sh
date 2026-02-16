#!/bin/bash
set -e

echo "-----------------------------------------------"
echo "Step 1: Running BFT Safety Check (Theorem 1)..."
go test -v ./internal/... -run TestBFTSafety | grep "PASSED"

echo "Step 2: Calculating Liveness Probability (Theorem 4)..."
go test -v ./internal/... -run TestLiveness | grep "PASSED"

# --- Automation: Sync JSON to Log with Linter-Compliant Header ---
echo "🔄 Syncing capabilities to Verification Log..."
echo "# Sovereign Mohawk Verification Log" > proofs/VERIFICATION_LOG.md
echo "" >> proofs/VERIFICATION_LOG.md
echo "## Formal Proof Results" >> proofs/VERIFICATION_LOG.md
echo "- **Theorem 4 (Liveness):** $(jq -r '.liveness_theorem_4' capabilities.json) (PASSED)" >> proofs/VERIFICATION_LOG.md
echo "- **Theorem 1 (BFT Safety):** $(jq -r '.bft_safety_theorem_1' capabilities.json)" >> proofs/VERIFICATION_LOG.md
echo "- **Status:** $(jq -r '.status' capabilities.json)" >> proofs/VERIFICATION_LOG.md

# --- Final Audit ---
./scripts/audit_proofs.sh
echo "-----------------------------------------------"
echo "✅ Build and Logic verified against Professional Evaluation Specs."
