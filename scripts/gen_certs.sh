#!/bin/bash
# Generate valid TLS certificates for Genesis nodes
# Fixes "certificate has expired or is not yet valid" error

set -e

CERT_DIR="${1:-.}/certs"
VALID_DAYS=365

mkdir -p "$CERT_DIR"

echo "=========================================="
echo "Generating Valid Certificates"
echo "=========================================="
echo ""

# Generate CA certificate (valid for 2 years)
echo "[1/4] Generating CA certificate..."
openssl req -new -x509 -days 730 -nodes -out "$CERT_DIR/ca.crt" -keyout "$CERT_DIR/ca.key" \
  -subj "/CN=Genesis-CA/O=Sovereign-Mohawk/C=US" 2>/dev/null || true

# Generate server certificate for orchestrator
echo "[2/4] Generating orchestrator certificate..."
openssl req -new -nodes -out "$CERT_DIR/orchestrator.csr" -keyout "$CERT_DIR/orchestrator.key" \
  -subj "/CN=orchestrator/O=Sovereign-Mohawk/C=US" 2>/dev/null || true
openssl x509 -req -in "$CERT_DIR/orchestrator.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
  -CAcreateserial -out "$CERT_DIR/orchestrator.crt" -days "$VALID_DAYS" \
  -extfile <(printf "subjectAltName=DNS:orchestrator,DNS:localhost,IP:127.0.0.1") 2>/dev/null || true

# Generate certificates for each node
for i in 1 2 3; do
  echo "[3/4] Generating node-agent-$i certificate..."
  openssl req -new -nodes -out "$CERT_DIR/node-$i.csr" -keyout "$CERT_DIR/node-$i.key" \
    -subj "/CN=node-agent-$i/O=Sovereign-Mohawk/C=US" 2>/dev/null || true
  openssl x509 -req -in "$CERT_DIR/node-$i.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/node-$i.crt" -days "$VALID_DAYS" \
    -extfile <(printf "subjectAltName=DNS:node-agent-$i,DNS:localhost,IP:127.0.0.1") 2>/dev/null || true
done

echo "[4/4] Cleaning up CSR files..."
rm -f "$CERT_DIR"/*.csr "$CERT_DIR"/*.srl

echo ""
echo "=========================================="
echo "Certificate generation complete!"
echo "=========================================="
echo ""
echo "Generated files:"
ls -lh "$CERT_DIR"/ | grep -E "\.(crt|key|pem)" || true
echo ""
echo "Next: Restart containers with new certificates"
echo "  docker compose restart node-agent-1 node-agent-2 node-agent-3"
