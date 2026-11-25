#!/usr/bin/env bash
# Tests for scripts/tpm_pcr_policy_gate.sh using a deterministic PCR reader mock.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/scripts/tpm_pcr_policy_gate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/mock_pcrread.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  sha256:0) printf '  sha256:\n    0 : 0xAAAA\n' ;;
  sha256:1) printf '  sha256:\n    1 : 0xBBBB\n' ;;
  *) echo "unexpected PCR: $1" >&2; exit 1 ;;
esac
EOF
chmod +x "$TMP/mock_pcrread.sh"
export TPM2PCRREAD="$TMP/mock_pcrread.sh"

cat > "$TMP/good.policy" <<'EOF'
# measured boot policy
sha256 0 AAAA
sha256 1 bbbb
EOF
cat > "$TMP/bad.policy" <<'EOF'
sha256 0 DEAD
EOF
cat > "$TMP/malformed.policy" <<'EOF'
sha1 0 AAAA
EOF

echo "== match =="
out="$(TPM2PCRREAD="$TMP/mock_pcrread.sh" "$GATE" "$TMP/good.policy" -- printf '%s' GATE_OK)"
[[ "$out" == "GATE_OK" ]] || { echo "FAIL: command did not run on match"; exit 1; }

echo "== mismatch =="
set +e
TPM2PCRREAD="$TMP/mock_pcrread.sh" "$GATE" "$TMP/bad.policy" -- printf '%s' LEAKED > "$TMP/bad.out" 2>&1
rc=$?
set -e
[[ "$rc" -eq 3 ]] || { echo "FAIL: mismatch exit=$rc, want 3"; exit 1; }
! grep -q LEAKED "$TMP/bad.out" || { echo "FAIL: command ran despite mismatch"; exit 1; }
grep -q 'PCR 0 mismatch' "$TMP/bad.out" || { echo "FAIL: no mismatch diagnostic"; exit 1; }

echo "== malformed policy =="
set +e
TPM2PCRREAD="$TMP/mock_pcrread.sh" "$GATE" "$TMP/malformed.policy" -- true >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || { echo "FAIL: malformed exit=$rc, want 2"; exit 1; }

echo "ALL_TPM_GATE_TESTS_PASS"
