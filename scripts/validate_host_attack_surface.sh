#!/usr/bin/env bash
set -euo pipefail

# Comma-separated allowed externally listening TCP ports.
# Defaults include common managed dev-container ports to avoid false positives in CI/Codespaces.
ALLOWED_PUBLIC_PORTS_RAW="${MOHAWK_ALLOWED_PUBLIC_PORTS:-2000,2222}"

declare -A ALLOWED=()
IFS=',' read -r -a raw_ports <<< "$ALLOWED_PUBLIC_PORTS_RAW"
for p in "${raw_ports[@]}"; do
  p="${p//[[:space:]]/}"
  [[ -z "$p" ]] && continue
  if [[ "$p" =~ ^[0-9]+$ ]]; then
    ALLOWED["$p"]=1
  fi
done

if ! command -v ss >/dev/null 2>&1; then
  echo "[host-attack-surface] missing 'ss' command"
  exit 1
fi

mapfile -t listeners < <(ss -tlnH | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)

violations=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  local_addr="$(awk '{print $4}' <<< "$line")"
  # local_addr example: 0.0.0.0:2222 or [::]:2222 or 127.0.0.1:9090
  host_part="${local_addr%:*}"
  port_part="${local_addr##*:}"

  if [[ "$host_part" == "0.0.0.0" || "$host_part" == "[::]" || "$host_part" == "*" ]]; then
    if [[ -z "${ALLOWED[$port_part]:-}" ]]; then
      violations+=("$local_addr")
    fi
  fi
done < <(ss -tlnH)

if (( ${#violations[@]} > 0 )); then
  echo "[host-attack-surface] unexpected public listeners detected:"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo
  echo "[host-attack-surface] allowed ports are: ${ALLOWED_PUBLIC_PORTS_RAW:-<none>}"
  echo "[host-attack-surface] set MOHAWK_ALLOWED_PUBLIC_PORTS to adjust policy if required"
  exit 1
fi

echo "[host-attack-surface] host public listener policy passed"