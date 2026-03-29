#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: scripts/extract_byzantine_forensics.sh [--since DURATION] [--output FILE] [--metrics-json FILE] [--containers CSV]

Extracts rejected gradient submissions from container logs for threat-intel review.

Options:
  --since DURATION   Docker log window (default: 30m)
  --output FILE      Output markdown report path (default: results/forensics/byzantine_rejections_report.md)
  --metrics-json FILE
                     Optional JSON metrics output path for automation
  --containers CSV   Comma-separated containers/services to inspect
                     Default: node-agent-1,node-agent-2,node-agent-3,orchestrator
  -h, --help         Show this help

The script scans for gradient-related failures and accepted=false acknowledgements.
EOF
}

SINCE="30m"
OUTPUT="results/forensics/byzantine_rejections_report.md"
METRICS_JSON=""
CONTAINERS_CSV="node-agent-1,node-agent-2,node-agent-3,orchestrator"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --since" >&2
        exit 1
      fi
      SINCE="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --output" >&2
        exit 1
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --metrics-json)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --metrics-json" >&2
        exit 1
      fi
      METRICS_JSON="$2"
      shift 2
      ;;
    --containers)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --containers" >&2
        exit 1
      fi
      CONTAINERS_CSV="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
TMP_LOGS="$(mktemp)"
trap 'rm -f "$TMP_LOGS"' EXIT

IFS=',' read -r -a containers <<<"$CONTAINERS_CSV"
if [[ ${#containers[@]} -eq 0 ]]; then
  echo "no containers specified" >&2
  exit 1
fi

found_any=0
for c in "${containers[@]}"; do
  c="$(echo "$c" | xargs)"
  if [[ -z "$c" ]]; then
    continue
  fi

  if ! docker ps --format '{{.Names}}' | grep -Fx "$c" >/dev/null 2>&1; then
    continue
  fi

  found_any=1
  {
    echo "===== container:${c} ====="
    docker logs --since "$SINCE" "$c" 2>&1 || true
    echo
  } >>"$TMP_LOGS"
done

if [[ $found_any -eq 0 ]]; then
  echo "no matching running containers found for forensics extraction" >&2
  exit 1
fi

reject_patterns='accepted=false|Gradient: submission failed|Gradient: KEX mismatch|kex mismatch|unsupported kex mode|kex public key bytes mismatch'
reject_lines_file="$(mktemp)"
trap 'rm -f "$TMP_LOGS" "$reject_lines_file"' EXIT

grep -Ei "$reject_patterns" "$TMP_LOGS" >"$reject_lines_file" || true

total_events="$(wc -l <"$reject_lines_file" | xargs)"
total_lines="$(wc -l <"$TMP_LOGS" | xargs)"
accepted_false_count="$(grep -Eic 'accepted=false' "$reject_lines_file" || true)"
submission_failed_count="$(grep -Eic 'Gradient: submission failed' "$reject_lines_file" || true)"
kex_mismatch_count="$(grep -Eic 'KEX mismatch|kex mismatch' "$reject_lines_file" || true)"
unsupported_kex_count="$(grep -Eic 'unsupported kex mode' "$reject_lines_file" || true)"
kex_key_size_mismatch_count="$(grep -Eic 'kex public key bytes mismatch|KEX key-size mismatch' "$reject_lines_file" || true)"
event_ratio_percent="0.00"

if [[ "$total_lines" != "0" ]]; then
  event_ratio_percent="$(awk -v e="$total_events" -v t="$total_lines" 'BEGIN { printf "%.2f", (e/t)*100 }')"
fi

{
  echo "# Byzantine Forensics Rejection Report"
  echo
  echo "- Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- Log window: ${SINCE}"
  echo "- Containers scanned: ${CONTAINERS_CSV}"
  echo "- Total log lines scanned: ${total_lines}"
  echo "- Rejection/failure events: ${total_events}"

  if [[ "$total_lines" != "0" ]]; then
    echo "- Event ratio of scanned lines: ${event_ratio_percent}%"
  fi

  echo
  echo "## Event Buckets"
  echo
  echo "| Bucket | Count |"
  echo "| --- | ---: |"
  echo "| accepted=false | ${accepted_false_count} |"
  echo "| submission failed | ${submission_failed_count} |"
  echo "| KEX mismatch | ${kex_mismatch_count} |"
  echo "| unsupported KEX mode | ${unsupported_kex_count} |"
  echo "| KEX key size mismatch | ${kex_key_size_mismatch_count} |"

  echo
  echo "## Top Rejection Lines"
  echo
  if [[ "$total_events" == "0" ]]; then
    echo "No rejection lines found for selected window."
  else
    awk '{counts[$0]++} END {for (line in counts) printf "%7d %s\n", counts[line], line}' "$reject_lines_file" \
      | sort -rn \
      | head -n 25 \
      | sed 's/^/- /'
  fi

  echo
  echo "## Recommendations"
  echo
  echo "1. Compare the rejection event count with the expected Byzantine budget for the round."
  echo "2. Cross-check with metric: mohawk_consensus_honest_ratio."
  echo "3. If KEX mismatch dominates, run scripts/quantum_kex_rotation_drill.sh to normalize modes."
  echo "4. Archive this report with incident artifacts for threat-intel follow-up."
} >"$OUTPUT"

if [[ -n "$METRICS_JSON" ]]; then
  mkdir -p "$(dirname "$METRICS_JSON")"
  {
    echo "{"
    echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," 
    echo "  \"since\": \"$SINCE\"," 
    echo "  \"containers\": \"$CONTAINERS_CSV\"," 
    echo "  \"total_lines\": $total_lines,"
    echo "  \"total_events\": $total_events,"
    echo "  \"event_ratio_percent\": $event_ratio_percent,"
    echo "  \"buckets\": {"
    echo "    \"accepted_false\": $accepted_false_count,"
    echo "    \"submission_failed\": $submission_failed_count,"
    echo "    \"kex_mismatch\": $kex_mismatch_count,"
    echo "    \"unsupported_kex_mode\": $unsupported_kex_count,"
    echo "    \"kex_key_size_mismatch\": $kex_key_size_mismatch_count"
    echo "  }"
    echo "}"
  } >"$METRICS_JSON"
  echo "forensics metrics written to $METRICS_JSON"
fi

echo "forensics report written to $OUTPUT"
