#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-rwilliamspbg-ops}"
REPO="${REPO:-Sovereign-Mohawk-Proto}"
BRANCH="${BRANCH:-main}"

# Requires a GitHub token with repo admin permissions.
# Example:
#   export GITHUB_TOKEN=ghp_xxx
#   bash scripts/apply_branch_protection.sh

PAYLOAD=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Build and Test / build-and-test",
      "Integrity Guard - Linter / lint",
      "Mainnet Readiness Gate / readiness-gate",
      "Mainnet Chaos Gate / chaos-matrix",
      "Performance Gate / performance-gate",
      "Monitoring Smoke Gate / monitoring-smoke",
      "Release Performance Evidence / release-performance-evidence",
      "Bridge Compression Benchmark / bridge-compression-benchmark",
      "FedAvg Benchmark Compare / fedavg-benchmark-compare",
      "Proof-Driven Design Verification / proof-audit",
      "Capability Sync / sync-check"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)

echo "Applying branch protection for ${OWNER}/${REPO}:${BRANCH}"
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  --input - <<<"${PAYLOAD}"

echo "Branch protection updated successfully."
