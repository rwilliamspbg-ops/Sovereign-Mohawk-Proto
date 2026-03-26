#!/usr/bin/env bash
set -euo pipefail

MIN_RMEM_MAX="${MOHAWK_MIN_RMEM_MAX:-8388608}"
MIN_RMEM_DEFAULT="${MOHAWK_MIN_RMEM_DEFAULT:-262144}"
MIN_WMEM_MAX="${MOHAWK_MIN_WMEM_MAX:-8388608}"
MIN_WMEM_DEFAULT="${MOHAWK_MIN_WMEM_DEFAULT:-262144}"

read_sysctl_value() {
  local key="$1"
  local path="/proc/sys/${key//./\/}"
  if [[ -r "$path" ]]; then
    tr -d '[:space:]' < "$path"
    return 0
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n "$key" 2>/dev/null | tr -d '[:space:]'
    return 0
  fi
  return 1
}

validate_minimum() {
  local key="$1"
  local minimum="$2"
  local current
  if ! current="$(read_sysctl_value "$key")"; then
    echo "[host-preflight] missing sysctl: $key"
    return 1
  fi
  if ! [[ "$current" =~ ^[0-9]+$ ]]; then
    echo "[host-preflight] non-numeric sysctl value: $key=$current"
    return 1
  fi
  if (( current < minimum )); then
    echo "[host-preflight] insufficient $key=$current (minimum $minimum)"
    return 1
  fi
  echo "[host-preflight] ok $key=$current (minimum $minimum)"
  return 0
}

failures=0
validate_minimum "net.core.rmem_max" "$MIN_RMEM_MAX" || failures=$((failures+1))
validate_minimum "net.core.rmem_default" "$MIN_RMEM_DEFAULT" || failures=$((failures+1))
validate_minimum "net.core.wmem_max" "$MIN_WMEM_MAX" || failures=$((failures+1))
validate_minimum "net.core.wmem_default" "$MIN_WMEM_DEFAULT" || failures=$((failures+1))

if (( failures > 0 )); then
  cat <<EOF

[host-preflight] kernel UDP/socket buffers are below production target.
[host-preflight] apply on host (requires root):
  sudo sysctl -w net.core.rmem_max=$MIN_RMEM_MAX
  sudo sysctl -w net.core.rmem_default=$MIN_RMEM_DEFAULT
  sudo sysctl -w net.core.wmem_max=$MIN_WMEM_MAX
  sudo sysctl -w net.core.wmem_default=$MIN_WMEM_DEFAULT

[host-preflight] to persist across reboot, add these keys to /etc/sysctl.conf
or a file in /etc/sysctl.d/, then run: sudo sysctl --system
EOF
  exit 1
fi

echo "[host-preflight] UDP/socket kernel tuning gate passed"
