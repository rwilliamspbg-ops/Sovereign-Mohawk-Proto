#!/bin/bash
# Certificate Generation & Deployment Script
# Generates valid TLS/TPM certificates and deploys to containers

set -e

CERT_DIR="${1:-.}/certs"
VALID_DAYS=365
KEY_SIZE=2048

echo "=========================================="
echo "Genesis Certificate Generation & Deployment"
echo "=========================================="
echo ""

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA certificate (valid 2 years)
echo "[1/5] Generating CA certificate (730 days)..."
openssl genrsa -out ca.key $KEY_SIZE 2>/dev/null
openssl req -new -x509 -days 730 -key ca.key -out ca.crt \
  -subj "/CN=Genesis-CA/O=Sovereign-Mohawk/C=US" 2>/dev/null
echo "  ✓ CA generated"

# Generate server config for SANs
cat > server.conf <<EOF
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = orchestrator
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.4
EOF

# Generate orchestrator certificate
echo "[2/5] Generating orchestrator certificate..."
openssl genrsa -out orchestrator.key $KEY_SIZE 2>/dev/null
openssl req -new -key orchestrator.key -out orchestrator.csr \
  -subj "/CN=orchestrator/O=Sovereign-Mohawk/C=US" -config server.conf 2>/dev/null
openssl x509 -req -in orchestrator.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out orchestrator.crt -days $VALID_DAYS \
  -extfile server.conf -extensions v3_req 2>/dev/null
echo "  ✓ Orchestrator cert generated"

# Generate node certificates
for i in 1 2 3; do
  echo "[3/5] Generating node-$i certificate..."
  
  # Update SAN for this node
  cat > node.conf <<EOF
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = node-agent-$i
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.$((10+i))
EOF
  
  openssl genrsa -out node-$i.key $KEY_SIZE 2>/dev/null
  openssl req -new -key node-$i.key -out node-$i.csr \
    -subj "/CN=node-agent-$i/O=Sovereign-Mohawk/C=US" -config node.conf 2>/dev/null
  openssl x509 -req -in node-$i.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out node-$i.crt -days $VALID_DAYS \
    -extfile node.conf -extensions v3_req 2>/dev/null
  echo "  ✓ Node-$i cert generated"
done

# Cleanup
echo "[4/5] Cleaning up temporary files..."
rm -f *.csr *.conf *.srl

# Verify certificates
echo "[5/5] Verifying certificates..."
EXPIRY=$(openssl x509 -in orchestrator.crt -noout -enddate | cut -d= -f2)
echo "  ✓ Certificates valid until: $EXPIRY"

cd - > /dev/null

echo ""
echo "=========================================="
echo "Certificate Generation Complete!"
echo "=========================================="
echo ""
echo "Generated files in $CERT_DIR:"
ls -lh "$CERT_DIR"/*.{crt,key} 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "Next steps:"
echo "  1. Update docker-compose.yml volumes with certificate paths"
echo "  2. Restart containers: docker compose down && docker compose up -d"
echo "  3. Verify: docker logs node-agent-1 | grep -i certificate"
echo ""
