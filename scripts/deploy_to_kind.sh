#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-sovereign-mohawk}"
NAMESPACE="${MOHAWK_NAMESPACE:-sovereign-mohawk}"
RELEASE_NAME="${MOHAWK_RELEASE_NAME:-sovereign-mohawk}"
CHART_PATH="${MOHAWK_CHART_PATH:-helm/sovereign-mohawk}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd"
    exit 1
  fi
}

require_cmd kind
require_cmd kubectl
require_cmd helm

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "[deploy-to-kind] creating kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME"
else
  echo "[deploy-to-kind] using existing kind cluster: $CLUSTER_NAME"
fi

echo "[deploy-to-kind] ensuring namespace exists: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "[deploy-to-kind] deploying helm chart: $CHART_PATH"
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --set orchestrator.replicaCount=1 \
  --set nodeAgent.replicaCount=2 \
  --set prometheus.enabled=true \
  --set grafana.enabled=true

echo "[deploy-to-kind] waiting for orchestrator deployment rollout"
kubectl rollout status deployment/"$RELEASE_NAME"-orchestrator -n "$NAMESPACE" --timeout=180s || true

echo "[deploy-to-kind] done"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get svc -n $NAMESPACE"
