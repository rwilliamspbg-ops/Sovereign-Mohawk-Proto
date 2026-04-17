#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FULL_VALIDATION_DIR="${ROOT_DIR}/test-results/full-validation"
ARCHIVE_DIR="${ROOT_DIR}/results/archive/full-validation"
DEFAULT_SUMMARY_OUT="${ROOT_DIR}/captured_artifacts/artifact_evidence_summary.md"
DEFAULT_MANIFEST_OUT="${ROOT_DIR}/captured_artifacts/artifact_manifest_latest.json"

KEEP_PER_PROFILE=3
ENABLE_ARCHIVE=0
ENABLE_PRUNE=0
APPLY_CHANGES=0
WRITE_SUMMARY=0
SUMMARY_OUT="${DEFAULT_SUMMARY_OUT}"
MANIFEST_OUT="${DEFAULT_MANIFEST_OUT}"

usage() {
  cat <<'EOF'
Usage: scripts/manage_artifacts.sh [options]

Options:
  --keep N               Keep latest N runs per profile (default: 3)
  --archive              Archive old validation runs into results/archive/full-validation
  --prune                Delete old validation runs (without archiving)
  --summary              Write artifact summary + manifest files
  --summary-out PATH     Summary markdown output path
  --manifest-out PATH    Manifest JSON output path
  --apply                Apply archive/prune changes (default is dry-run)
  --help                 Show this help

Examples:
  scripts/manage_artifacts.sh --keep 3 --archive
  scripts/manage_artifacts.sh --keep 3 --archive --apply
  scripts/manage_artifacts.sh --summary --apply
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      KEEP_PER_PROFILE="$2"
      shift 2
      ;;
    --archive)
      ENABLE_ARCHIVE=1
      shift
      ;;
    --prune)
      ENABLE_PRUNE=1
      shift
      ;;
    --summary)
      WRITE_SUMMARY=1
      shift
      ;;
    --summary-out)
      SUMMARY_OUT="$2"
      shift 2
      ;;
    --manifest-out)
      MANIFEST_OUT="$2"
      shift 2
      ;;
    --apply)
      APPLY_CHANGES=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$KEEP_PER_PROFILE" =~ ^[0-9]+$ ]] || [[ "$KEEP_PER_PROFILE" -lt 1 ]]; then
  echo "--keep must be an integer >= 1" >&2
  exit 1
fi

if [[ "$ENABLE_ARCHIVE" -eq 1 && "$ENABLE_PRUNE" -eq 1 ]]; then
  echo "Use either --archive or --prune, not both." >&2
  exit 1
fi

if [[ ! -d "${FULL_VALIDATION_DIR}" ]]; then
  echo "Missing directory: ${FULL_VALIDATION_DIR}" >&2
  exit 1
fi

detect_profile() {
  local json_file="$1"
  if grep -q '"profile"[[:space:]]*:[[:space:]]*"fast"' "$json_file"; then
    echo "fast"
  elif grep -q '"profile"[[:space:]]*:[[:space:]]*"deep"' "$json_file"; then
    echo "deep"
  else
    echo "unknown"
  fi
}

collect_stems() {
  find "${FULL_VALIDATION_DIR}" -maxdepth 1 -type f -name 'full_validation_*.json' -printf '%f\n' \
    | sed 's/\.json$//' \
    | sort
}

latest_stem_for_profile() {
  local profile="$1"
  local stems
  stems="$(collect_stems)"
  local latest=""
  while IFS= read -r stem; do
    [[ -z "$stem" ]] && continue
    local json_file="${FULL_VALIDATION_DIR}/${stem}.json"
    if [[ "$(detect_profile "$json_file")" == "$profile" ]]; then
      latest="$stem"
    fi
  done <<< "$stems"
  echo "$latest"
}

filter_old_stems_for_profile() {
  local profile="$1"
  local stems
  stems="$(collect_stems)"
  local profile_stems=()
  while IFS= read -r stem; do
    [[ -z "$stem" ]] && continue
    local json_file="${FULL_VALIDATION_DIR}/${stem}.json"
    if [[ "$(detect_profile "$json_file")" == "$profile" ]]; then
      profile_stems+=("$stem")
    fi
  done <<< "$stems"

  local count="${#profile_stems[@]}"
  if [[ "$count" -le "$KEEP_PER_PROFILE" ]]; then
    return 0
  fi

  local remove_count=$((count - KEEP_PER_PROFILE))
  local i
  for ((i = 0; i < remove_count; i++)); do
    echo "${profile_stems[$i]}"
  done
}

readarray -t OLD_FAST < <(filter_old_stems_for_profile "fast")
readarray -t OLD_DEEP < <(filter_old_stems_for_profile "deep")
OLD_STEMS=("${OLD_FAST[@]}" "${OLD_DEEP[@]}")

print_retention_plan() {
  local profile="$1"
  local total=0
  local keep=0
  local remove=0
  local stems
  stems="$(collect_stems)"
  while IFS= read -r stem; do
    [[ -z "$stem" ]] && continue
    local json_file="${FULL_VALIDATION_DIR}/${stem}.json"
    if [[ "$(detect_profile "$json_file")" == "$profile" ]]; then
      total=$((total + 1))
    fi
  done <<< "$stems"

  if [[ "$total" -gt "$KEEP_PER_PROFILE" ]]; then
    remove=$((total - KEEP_PER_PROFILE))
    keep="$KEEP_PER_PROFILE"
  else
    keep="$total"
  fi

  echo "profile=${profile} total=${total} keep=${keep} old=${remove}"
}

echo "Artifact retention policy"
echo "- keep_per_profile=${KEEP_PER_PROFILE}"
echo "- $(print_retention_plan fast)"
echo "- $(print_retention_plan deep)"

if [[ "$ENABLE_ARCHIVE" -eq 1 || "$ENABLE_PRUNE" -eq 1 ]]; then
  if [[ "${#OLD_STEMS[@]}" -eq 0 || ( "${#OLD_STEMS[@]}" -eq 1 && -z "${OLD_STEMS[0]}" ) ]]; then
    echo "No old validation runs to process."
  else
    FILES_TO_PROCESS=()
    for stem in "${OLD_STEMS[@]}"; do
      [[ -z "$stem" ]] && continue
      FILES_TO_PROCESS+=("test-results/full-validation/${stem}.json")
      FILES_TO_PROCESS+=("test-results/full-validation/${stem}.md")
    done

    echo "Validation files selected: ${#FILES_TO_PROCESS[@]}"
    printf ' - %s\n' "${FILES_TO_PROCESS[@]}"

    if [[ "$APPLY_CHANGES" -eq 1 ]]; then
      if [[ "$ENABLE_ARCHIVE" -eq 1 ]]; then
        mkdir -p "${ARCHIVE_DIR}"
        archive_name="full_validation_archive_$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
        archive_path="${ARCHIVE_DIR}/${archive_name}"
        (
          cd "${ROOT_DIR}"
          tar -czf "$archive_path" "${FILES_TO_PROCESS[@]}"
        )
        rm -f "${FILES_TO_PROCESS[@]/#/${ROOT_DIR}/}"
        echo "Archived and removed old runs: ${archive_path}"
      else
        rm -f "${FILES_TO_PROCESS[@]/#/${ROOT_DIR}/}"
        echo "Removed old validation runs."
      fi
    else
      echo "Dry-run mode: add --apply to execute archive/prune changes."
    fi
  fi
fi

if [[ "$WRITE_SUMMARY" -eq 1 ]]; then
  latest_fast="$(latest_stem_for_profile "fast")"
  latest_deep="$(latest_stem_for_profile "deep")"

  latest_tpm="$(find "${ROOT_DIR}/results/go-live/evidence" -maxdepth 1 -type f -name 'tpm_closure_summary_*.md' -printf '%f\n' | sort | tail -n 1 || true)"
  latest_router="$(find "${ROOT_DIR}/results/go-live/evidence" -maxdepth 1 -type f -name 'router_integration_published_images_*.md' -printf '%f\n' | sort | tail -n 1 || true)"
  latest_scale="$(find "${ROOT_DIR}/results/metrics" -maxdepth 1 -type f -name 'scaling_evidence_spotlight_*.md' -printf '%f\n' | sort | tail -n 1 || true)"

  mkdir -p "$(dirname "$SUMMARY_OUT")" "$(dirname "$MANIFEST_OUT")"

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$SUMMARY_OUT" <<EOF
# Artifact Evidence Summary

- Generated (UTC): ${generated_at}
- Retention policy: keep latest ${KEEP_PER_PROFILE} validation runs per profile

## Canonical Validation Runs

| Profile | Latest JSON | Latest Markdown |
| --- | --- | --- |
| fast | ${latest_fast:+test-results/full-validation/${latest_fast}.json} | ${latest_fast:+test-results/full-validation/${latest_fast}.md} |
| deep | ${latest_deep:+test-results/full-validation/${latest_deep}.json} | ${latest_deep:+test-results/full-validation/${latest_deep}.md} |

## Curated Evidence Pointers

- TPM closure summary: ${latest_tpm:+results/go-live/evidence/${latest_tpm}}
- Router integration evidence: ${latest_router:+results/go-live/evidence/${latest_router}}
- Scaling spotlight: ${latest_scale:+results/metrics/${latest_scale}}
- Release performance index: results/metrics/release_performance_evidence.md
- OpenAPI contract: results/api/openapi.json
- Forensics report: results/forensics/byzantine_rejections_local.md
- Forensics metrics: results/forensics/byzantine_forensics_metrics_local.json
EOF

  cat > "$MANIFEST_OUT" <<EOF
{
  "generated_utc": "${generated_at}",
  "retention": {
    "keep_per_profile": ${KEEP_PER_PROFILE},
    "full_validation_dir": "test-results/full-validation"
  },
  "canonical_runs": {
    "fast": {
      "json": "${latest_fast:+test-results/full-validation/${latest_fast}.json}",
      "markdown": "${latest_fast:+test-results/full-validation/${latest_fast}.md}"
    },
    "deep": {
      "json": "${latest_deep:+test-results/full-validation/${latest_deep}.json}",
      "markdown": "${latest_deep:+test-results/full-validation/${latest_deep}.md}"
    }
  },
  "evidence_categories": {
    "release": "results/metrics/release_performance_evidence.md",
    "go_live": "${latest_tpm:+results/go-live/evidence/${latest_tpm}}",
    "router": "${latest_router:+results/go-live/evidence/${latest_router}}",
    "scale": "${latest_scale:+results/metrics/${latest_scale}}",
    "forensics": "results/forensics/byzantine_rejections_local.md",
    "api": "results/api/openapi.json"
  }
}
EOF

  echo "Wrote summary: ${SUMMARY_OUT}"
  echo "Wrote manifest: ${MANIFEST_OUT}"
fi
