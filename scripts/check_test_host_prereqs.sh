#!/usr/bin/env bash
set -euo pipefail

missing=()
for tool in kind kubectl docker; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "error: missing required host tools for local scale evidence: ${missing[*]}" >&2
  echo "install them, then rerun: make run-kind-scale-evidence" >&2
  exit 1
fi

echo "host prereqs OK: kind kubectl docker are available"
