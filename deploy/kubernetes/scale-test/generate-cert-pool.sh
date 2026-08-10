#!/usr/bin/env bash
# Generates a real CA, orchestrator leaf cert, and a 0-indexed pool of
# per-replica node-agent client certs -- the same openssl logic as
# docker-compose.yml's runtime-secrets-init service, adapted only in the
# client-cert-pool index base (0-indexed here to match Kubernetes
# StatefulSet pod ordinals; runtime-secrets-init's compose version is
# 1-indexed to match Docker Compose's --scale replica numbering).
#
# Usage:
#   MOHAWK_TPM_CLIENT_CERT_POOL_SIZE=500 OUT_DIR=/abs/path/to/output ./generate-cert-pool.sh
#
# Writes (all real, sensitive key material -- never commit the output):
#   $OUT_DIR/mohawk_api_token
#   $OUT_DIR/mohawk_tpm_ca_cert.pem, mohawk_tpm_ca_key.pem
#   $OUT_DIR/mohawk_tpm_orchestrator_cert.pem, mohawk_tpm_orchestrator_key.pem
#   $OUT_DIR/node-agent-certs/mohawk_tpm_client_<0..N-1>_cert.pem, _key.pem

set -euo pipefail

OUT_DIR="${OUT_DIR:?set OUT_DIR to an absolute output directory}"
POOL_SIZE="${MOHAWK_TPM_CLIENT_CERT_POOL_SIZE:-500}"

mkdir -p "$OUT_DIR/node-agent-certs"
umask 077

if [ ! -s "$OUT_DIR/mohawk_api_token" ]; then
  openssl rand -hex 24 > "$OUT_DIR/mohawk_api_token"
fi

if [ ! -s "$OUT_DIR/mohawk_tpm_ca_cert.pem" ] || [ ! -s "$OUT_DIR/mohawk_tpm_ca_key.pem" ]; then
  openssl req -x509 -newkey rsa:3072 \
    -keyout "$OUT_DIR/mohawk_tpm_ca_key.pem" \
    -out "$OUT_DIR/mohawk_tpm_ca_cert.pem" \
    -sha256 -days 365 -nodes \
    -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" >/dev/null 2>&1
fi

issue_leaf() {
  cn="$1"; cert="$2"; key="$3"; san="${4:-}"
  csr="${cert}.csr"; ext="${cert}.ext"
  if [ -s "$cert" ] && [ -s "$key" ]; then
    return
  fi
  openssl req -new -newkey rsa:3072 -nodes \
    -keyout "$key" -out "$csr" \
    -subj "/CN=${cn}/O=Sovereign-Mohawk Nodes" >/dev/null 2>&1
  if [ -n "$san" ]; then
    printf 'subjectAltName=%s\nextendedKeyUsage=serverAuth,clientAuth\n' "$san" > "$ext"
  fi
  openssl x509 -req -in "$csr" \
    -CA "$OUT_DIR/mohawk_tpm_ca_cert.pem" -CAkey "$OUT_DIR/mohawk_tpm_ca_key.pem" -CAcreateserial \
    -out "$cert" -days 365 -sha256 ${san:+-extfile "$ext"} >/dev/null 2>&1
  rm -f "$csr" "$ext"
  chmod 600 "$cert" "$key"
}

issue_leaf orchestrator \
  "$OUT_DIR/mohawk_tpm_orchestrator_cert.pem" \
  "$OUT_DIR/mohawk_tpm_orchestrator_key.pem" \
  "DNS:orchestrator,DNS:localhost,IP:127.0.0.1"

i=0
while [ "$i" -lt "$POOL_SIZE" ]; do
  issue_leaf "node-agent-${i}" \
    "$OUT_DIR/node-agent-certs/mohawk_tpm_client_${i}_cert.pem" \
    "$OUT_DIR/node-agent-certs/mohawk_tpm_client_${i}_key.pem"
  i=$((i+1))
done

echo "generated pool of $POOL_SIZE 0-indexed client certs under $OUT_DIR/node-agent-certs"
