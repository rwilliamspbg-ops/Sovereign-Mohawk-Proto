#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPLICAS_LIST="${REPLICAS_LIST:-100,300,500}"
CLUSTER_NAME="${CLUSTER_NAME:-sovereign-mohawk-scale-test}"
NAMESPACE="${NAMESPACE:-scale-test}"
CERT_DIR="${CERT_DIR:-${TMPDIR:-/tmp}/mohawk-scale-test-certs}"
KIND_CONFIG_TEMPLATE="${ROOT_DIR}/deploy/kubernetes/scale-test/kind-config.yaml"
KIND_CONFIG="${ROOT_DIR}/.tmp/kind-scale-matrix-config.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd kind
require_cmd kubectl
require_cmd docker

parse_list() {
  local raw="$1"
  local IFS=','
  for item in $raw; do
    item="${item//[[:space:]]/}"
    if [[ -n "$item" ]]; then
      echo "$item"
    fi
  done
}

ensure_cluster() {
  mkdir -p "$CERT_DIR"
  mkdir -p "$(dirname "$KIND_CONFIG")"
  cp "$KIND_CONFIG_TEMPLATE" "$KIND_CONFIG"
  perl -0pi -e "s#/REPLACE/WITH/ABSOLUTE/PATH/TO/cert-pool-output/node-agent-certs#$CERT_DIR/node-agent-certs#g" "$KIND_CONFIG"

  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    echo "[matrix] reusing kind cluster: $CLUSTER_NAME"
    return
  fi

  echo "[matrix] creating kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
}

ensure_cert_pool() {
  local max_replicas="$1"
  local last_cert="$CERT_DIR/node-agent-certs/mohawk_tpm_client_$((max_replicas - 1))_cert.pem"
  mkdir -p "$CERT_DIR"
  if [[ ! -s "$last_cert" ]]; then
    echo "[matrix] generating certificate pool for max replicas: $max_replicas"
    MOHAWK_TPM_CLIENT_CERT_POOL_SIZE="$max_replicas" OUT_DIR="$CERT_DIR" bash "$ROOT_DIR/deploy/kubernetes/scale-test/generate-cert-pool.sh"
  fi
}

ensure_images() {
  if ! docker image inspect local/node-agent:scale-test >/dev/null 2>&1; then
    echo "[matrix] building local/node-agent:scale-test"
    docker build -f "$ROOT_DIR/cmd/node-agent/Dockerfile" -t local/node-agent:scale-test "$ROOT_DIR"
  fi

  if ! docker image inspect local/orchestrator:scale-test >/dev/null 2>&1; then
    echo "[matrix] building local/orchestrator:scale-test"
    docker build -f "$ROOT_DIR/cmd/orchestrator/Dockerfile" -t local/orchestrator:scale-test "$ROOT_DIR"
  fi

  kind load docker-image local/node-agent:scale-test --name "$CLUSTER_NAME"
  kind load docker-image local/orchestrator:scale-test --name "$CLUSTER_NAME"

  CONTROL_PLANE="${CLUSTER_NAME}-control-plane"
  if ! docker exec "$CONTROL_PLANE" crictl image inspect ipfs/kubo:v0.28.0 >/dev/null 2>&1; then
    echo "[matrix] pulling ipfs image into kind node"
    docker exec "$CONTROL_PLANE" crictl pull ipfs/kubo:v0.28.0
  fi
}

ensure_deployment() {
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
}

collect_result() {
  local replicas="$1"
  echo "[matrix] running scale check at ${replicas} replicas"
  kubectl -n "$NAMESPACE" scale statefulset node-agent --replicas="$replicas"
  kubectl -n "$NAMESPACE" rollout status statefulset/node-agent --timeout=600s
  READY_REPLICAS="$(kubectl -n "$NAMESPACE" get statefulset node-agent -o jsonpath='{.status.readyReplicas}')"
  if [[ "$READY_REPLICAS" != "$replicas" ]]; then
    echo "error: expected $replicas ready replicas, got $READY_REPLICAS" >&2
    return 1
  fi

  local out="$ROOT_DIR/results/go-live/evidence/kind-scale-matrix"
  mkdir -p "$out"
  kubectl -n "$NAMESPACE" get pods -o wide > "$out/pods_${replicas}.txt"
  kubectl -n "$NAMESPACE" get statefulset node-agent -o yaml > "$out/statefulset_${replicas}.yaml"
  printf '%s,%s\n' "$replicas" "$READY_REPLICAS" >> "$out/summary.csv"
  echo "[matrix] ${replicas} replicas ready"
}

max_replicas=0
while IFS= read -r count; do
  if [[ -n "$count" ]]; then
    if (( count > max_replicas )); then
      max_replicas="$count"
    fi
  fi
done < <(parse_list "$REPLICAS_LIST")

ensure_cert_pool "$max_replicas"
ensure_cluster
ensure_images
ensure_deployment

mkdir -p "$ROOT_DIR/results/go-live/evidence/kind-scale-matrix"
: > "$ROOT_DIR/results/go-live/evidence/kind-scale-matrix/summary.csv"

while IFS= read -r count; do
  [[ -n "$count" ]] || continue
  collect_result "$count"
done < <(parse_list "$REPLICAS_LIST")

echo "[matrix] complete. Summary in $ROOT_DIR/results/go-live/evidence/kind-scale-matrix/"
