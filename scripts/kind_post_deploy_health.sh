#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${MOHAWK_NAMESPACE:-sovereign-mohawk}"
RELEASE_NAME="${MOHAWK_RELEASE_NAME:-sovereign-mohawk}"
TIMEOUT_SECONDS="${KIND_HEALTH_TIMEOUT_SECONDS:-180}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd"
    exit 1
  fi
}

require_cmd kubectl

echo "[kind-health] checking deployment availability"
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=Available \
  deployment/"$RELEASE_NAME"-orchestrator \
  --timeout="${TIMEOUT_SECONDS}s"

echo "[kind-health] checking pod readiness"
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=Ready \
  pod -l app.kubernetes.io/instance="$RELEASE_NAME" \
  --timeout="${TIMEOUT_SECONDS}s"

echo "[kind-health] ensuring service endpoints exist"
SERVICE_NAME="${RELEASE_NAME}-orchestrator"
if ! kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}' >/dev/null 2>&1; then
  echo "error: orchestrator service endpoints are not ready"
  kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" || true
  exit 1
fi

echo "[kind-health] PASS"
