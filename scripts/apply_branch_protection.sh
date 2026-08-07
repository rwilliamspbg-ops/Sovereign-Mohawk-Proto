#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-rwilliamspbg-ops}"
REPO="${REPO:-Sovereign-Mohawk-Proto}"
BRANCH="${BRANCH:-main}"

# Requires a GitHub token with repo admin permissions.
# Example:
#   export GITHUB_TOKEN=ghp_xxx
#   bash scripts/apply_branch_protection.sh
#
# Note: this payload is kept in sync with the LIVE required_status_checks on
# `main` (verified via `gh api repos/${OWNER}/${REPO}/branches/main/protection`
# as of 2026-08-07), not with workflow/job names by inspection alone -- a
# prior version of this script (last touched 2026-08-04, PR #139) drifted
# from live state: it required the legacy, non-required
# "Proof-Driven Design Verification / verify-lean-formalization" job instead
# of `full-validation-fast` (the job PR #139 itself made the real Lean
# build+lint gate), and it omitted several checks that were live-required at
# the time (go-test, both CodeQL analyzers, pin-check, artifact-sync-check,
# govulncheck, trivy-fs, go-vulncheck, dependency-review). Running that
# version would have silently downgraded branch protection. The contexts
# below use the same short job-id form GitHub's protection API itself
# reports (not "Workflow Name / job-id"), matching how they actually appear
# in `required_status_checks.contexts` live. `enforce_admins` and
# `required_pull_request_reviews` are also brought in line with live state
# (no admin enforcement, no required-review count currently configured) --
# review those two independently before changing them here, since they are
# repo review-policy decisions, not CI-verification gates like the rest of
# this script. `required_pull_request_reviews` must be explicitly `null`,
# not omitted: GitHub's PUT branch-protection endpoint rejects a request
# that leaves this key out entirely ("required_pull_request_reviews"
# wasn't supplied", HTTP 422) even though its GET response simply omits
# the key when unconfigured -- GET's response shape is not a reliable
# guide to what PUT requires; confirmed by hitting this for real.

PAYLOAD=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "build-and-test",
      "go-test",
      "lint",
      "markdown-link-check",
      "Analyze (CodeQL) (go)",
      "Analyze (CodeQL) (python)",
      "full-validation-fast",
      "pin-check",
      "artifact-sync-check",
      "validate-sync",
      "govulncheck",
      "trivy-fs",
      "go-vulncheck",
      "dependency-review"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
)

echo "Applying branch protection for ${OWNER}/${REPO}:${BRANCH}"
# No leading slash on the endpoint: under Git Bash on Windows, MSYS
# rewrites an argument starting with "/" as a filesystem path (e.g.
# "/repos/..." becomes "C:/Program Files/Git/repos/..."), breaking gh's
# API call. gh accepts the endpoint with or without the leading slash;
# omitting it avoids the rewrite on every shell, not just Windows.
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  --input - <<<"${PAYLOAD}"

echo "Branch protection updated successfully."
