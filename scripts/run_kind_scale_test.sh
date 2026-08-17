#!/usr/bin/env bash
set -euo pipefail

REPLICAS="${REPLICAS:-500}"
CLUSTER_NAME="${CLUSTER_NAME:-sovereign-mohawk-scale-test}"
NAMESPACE="${NAMESPACE:-scale-test}"
CERT_DIR="${CERT_DIR:-${TMPDIR:-/tmp}/mohawk-scale-test-certs}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND_CONFIG_TEMPLATE="${ROOT_DIR}/deploy/kubernetes/scale-test/kind-config.yaml"
GEN_CERT_SCRIPT="${ROOT_DIR}/deploy/kubernetes/scale-test/generate-cert-pool.sh"
KIND_CONFIG="${ROOT_DIR}/.tmp/kind-scale-test-config.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd kind
require_cmd kubectl
require_cmd docker

mkdir -p "$CERT_DIR"
mkdir -p "$(dirname "$KIND_CONFIG")"
cp "$KIND_CONFIG_TEMPLATE" "$KIND_CONFIG"
perl -0pi -e "s#/REPLACE/WITH/ABSOLUTE/PATH/TO/cert-pool-output/node-agent-certs#$CERT_DIR/node-agent-certs#g" "$KIND_CONFIG"

LAST_CERT="$CERT_DIR/node-agent-certs/mohawk_tpm_client_$((REPLICAS - 1))_cert.pem"
if [[ ! -s "$LAST_CERT" ]]; then
  echo "[scale-test] generating certificate pool for $REPLICAS replicas"
  MOHAWK_TPM_CLIENT_CERT_POOL_SIZE="$REPLICAS" OUT_DIR="$CERT_DIR" bash "$GEN_CERT_SCRIPT"
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "[scale-test] creating kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
else
  echo "[scale-test] reusing kind cluster: $CLUSTER_NAME"
fi

if ! docker image inspect local/node-agent:scale-test >/dev/null 2>&1; then
  echo "[scale-test] building node-agent image"
  docker build -f "$ROOT_DIR/cmd/node-agent/Dockerfile" -t local/node-agent:scale-test "$ROOT_DIR"
fi

if ! docker image inspect local/orchestrator:scale-test >/dev/null 2>&1; then
  echo "[scale-test] building orchestrator image"
  docker build -f "$ROOT_DIR/cmd/orchestrator/Dockerfile" -t local/orchestrator:scale-test "$ROOT_DIR"
fi

kind load docker-image local/node-agent:scale-test --name "$CLUSTER_NAME"
kind load docker-image local/orchestrator:scale-test --name "$CLUSTER_NAME"

CONTROL_PLANE="${CLUSTER_NAME}-control-plane"
if ! docker exec "$CONTROL_PLANE" crictl image inspect ipfs/kubo:v0.28.0 >/dev/null 2>&1; then
  echo "[scale-test] pulling ipfs image into kind node"
  docker exec "$CONTROL_PLANE" crictl pull ipfs/kubo:v0.28.0
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create secret generic mohawk-shared-secrets \
  --from-file=mohawk_api_token="$CERT_DIR/mohawk_api_token" \
  --from-file=mohawk_tpm_ca_cert.pem="$CERT_DIR/mohawk_tpm_ca_cert.pem" \
  --from-file=mohawk_tpm_orchestrator_cert.pem="$CERT_DIR/mohawk_tpm_orchestrator_cert.pem" \
  --from-file=mohawk_tpm_orchestrator_key.pem="$CERT_DIR/mohawk_tpm_orchestrator_key.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$ROOT_DIR/deploy/kubernetes/scale-test/01-orchestrator.yaml"
kubectl apply -f "$ROOT_DIR/deploy/kubernetes/scale-test/02-ipfs.yaml"

kubectl -n "$NAMESPACE" wait --for=condition=Ready pod -l app=orchestrator --timeout=180s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod -l app=ipfs --timeout=180s

kubectl apply -f "$ROOT_DIR/deploy/kubernetes/scale-test/03-node-agent.yaml"

kubectl -n "$NAMESPACE" scale statefulset node-agent --replicas="$REPLICAS"
kubectl -n "$NAMESPACE" rollout status statefulset/node-agent --timeout=600s

READY_REPLICAS="$(kubectl -n "$NAMESPACE" get statefulset node-agent -o jsonpath='{.status.readyReplicas}')"
if [[ "$READY_REPLICAS" != "$REPLICAS" ]]; then
  echo "error: expected $REPLICAS ready replicas, got $READY_REPLICAS" >&2
  exit 1
fi

echo "[scale-test] success: $READY_REPLICAS/$REPLICAS node-agent replicas are ready"
echo "[scale-test] namespace: $NAMESPACE"
echo "[scale-test] cert dir: $CERT_DIR"
echo "[scale-test] next commands:"
echo "  kubectl -n $NAMESPACE get pods"
echo "  docker exec $CONTROL_PLANE crictl stats"
