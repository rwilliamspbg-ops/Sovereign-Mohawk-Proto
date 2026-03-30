#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ONLY=true
if [[ "${1:-}" == "--persist" ]]; then
  RUNTIME_ONLY=false
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage:
  scripts/host_tuning.sh           Apply recommended sysctl values for current runtime session.
  scripts/host_tuning.sh --persist Apply values and write /etc/sysctl.d/99-mohawk-network.conf.

Environment overrides:
  MOHAWK_MIN_RMEM_MAX
  MOHAWK_MIN_RMEM_DEFAULT
  MOHAWK_MIN_WMEM_MAX
  MOHAWK_MIN_WMEM_DEFAULT
EOF
  exit 0
fi

MIN_RMEM_MAX="${MOHAWK_MIN_RMEM_MAX:-8388608}"
MIN_RMEM_DEFAULT="${MOHAWK_MIN_RMEM_DEFAULT:-262144}"
MIN_WMEM_MAX="${MOHAWK_MIN_WMEM_MAX:-8388608}"
MIN_WMEM_DEFAULT="${MOHAWK_MIN_WMEM_DEFAULT:-262144}"
PERSIST_FILE="/etc/sysctl.d/99-mohawk-network.conf"

if [[ "$EUID" -ne 0 ]]; then
  echo "error: run as root (example: sudo bash scripts/host_tuning.sh --persist)"
  exit 1
fi

sysctl -w net.core.rmem_max="$MIN_RMEM_MAX"
sysctl -w net.core.rmem_default="$MIN_RMEM_DEFAULT"
sysctl -w net.core.wmem_max="$MIN_WMEM_MAX"
sysctl -w net.core.wmem_default="$MIN_WMEM_DEFAULT"

if [[ "$RUNTIME_ONLY" == "false" ]]; then
  cat > "$PERSIST_FILE" <<EOF
net.core.rmem_max=$MIN_RMEM_MAX
net.core.rmem_default=$MIN_RMEM_DEFAULT
net.core.wmem_max=$MIN_WMEM_MAX
net.core.wmem_default=$MIN_WMEM_DEFAULT
EOF
  sysctl --system >/dev/null
  echo "persisted tuning in $PERSIST_FILE"
fi

echo "host tuning applied successfully"
