#!/usr/bin/env bash
# Gate a command on measured TPM PCR values.
#
# Usage:
#   TPM2PCRREAD="sudo -n tpm2_pcrread" \
#     scripts/tpm_pcr_policy_gate.sh <policy-file> [-- <command> [args...]]
#
# Policy file format (blank lines and # comments allowed):
#   sha256 <pcr-index> <expected-hex>
#
# Exit codes: 0 = policy matched (and command ran successfully, if given),
# 2 = usage/IO error, 3 = PCR mismatch (command is NOT executed).
set -euo pipefail

POLICY_FILE="${1:-}"
if [[ -z "$POLICY_FILE" || ! -r "$POLICY_FILE" ]]; then
  echo "tpm-pcr-gate: policy file missing or unreadable: $POLICY_FILE" >&2
  exit 2
fi
shift
if [[ "${1:-}" == "--" ]]; then
  shift
fi

read -r -a PCR_READER <<< "${TPM2PCRREAD:-tpm2_pcrread}"
if ! command -v "${PCR_READER[0]}" >/dev/null 2>&1; then
  echo "tpm-pcr-gate: PCR reader not found: ${PCR_READER[0]}" >&2
  exit 2
fi

checked=0
while read -r bank index expected _rest; do
  [[ -z "${bank:-}" || "$bank" == \#* ]] && continue
  if [[ "$bank" != "sha256" || ! "$index" =~ ^[0-9]+$ || -z "${expected:-}" ]]; then
    echo "tpm-pcr-gate: malformed policy line: $bank $index ${expected:-}" >&2
    exit 2
  fi

  output="$("${PCR_READER[@]}" "sha256:${index}")" || {
    echo "tpm-pcr-gate: could not read PCR ${index}" >&2
    exit 2
  }
  actual="$(printf '%s\n' "$output" \
    | awk -v idx="$index" '$1 == idx && $2 == ":" { sub(/^0x/, "", $3); print toupper($3); exit }')"
  if [[ -z "$actual" ]]; then
    echo "tpm-pcr-gate: PCR ${index} missing from reader output" >&2
    exit 2
  fi

  if [[ "${actual^^}" != "${expected^^}" ]]; then
    echo "tpm-pcr-gate: PCR ${index} mismatch (expected ${expected^^}, got ${actual^^})" >&2
    exit 3
  fi
  checked=$((checked + 1))
done < "$POLICY_FILE"

if [[ "$checked" -eq 0 ]]; then
  echo "tpm-pcr-gate: policy contains no PCR entries" >&2
  exit 2
fi
echo "tpm-pcr-gate: ${checked} PCR(s) matched policy" >&2

if [[ "$#" -gt 0 ]]; then
  exec "$@"
fi
