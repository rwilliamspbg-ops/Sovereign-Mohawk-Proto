#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${MOHAWK_NAMESPACE:-sovereign-mohawk}"
RELEASE_NAME="${MOHAWK_RELEASE_NAME:-sovereign-mohawk}"
CHART_PATH="${MOHAWK_CHART_PATH:-./helm/sovereign-mohawk}"

if ! command -v helm >/dev/null 2>&1; then
  echo "error: helm is required"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "error: kubectl is required"
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE"

echo "installed release '$RELEASE_NAME' in namespace '$NAMESPACE'"
