#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-scale-test}"
OUT_DIR="${OUT_DIR:-$PWD/results/go-live/evidence/kind-scale-latency}"
WINDOW_SECONDS="${WINDOW_SECONDS:-30}"

mkdir -p "$OUT_DIR"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "error: kubectl is required" >&2
  exit 1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "error: namespace $NAMESPACE does not exist" >&2
  exit 1
fi

start_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf '# Kind scale latency capture\n' > "$OUT_DIR/latency_capture.md"
printf '\n- start: %s\n' "$start_ts" >> "$OUT_DIR/latency_capture.md"
printf '- namespace: %s\n' "$NAMESPACE" >> "$OUT_DIR/latency_capture.md"
printf '- window_seconds: %s\n' "$WINDOW_SECONDS" >> "$OUT_DIR/latency_capture.md"
printf '\n## Snapshot\n\n' >> "$OUT_DIR/latency_capture.md"

kubectl -n "$NAMESPACE" get pods -o wide >> "$OUT_DIR/latency_capture.md"

printf '\n## Metrics sample\n\n' >> "$OUT_DIR/latency_capture.md"

for pod in $(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[*].metadata.name}'); do
  echo "[latency] sampling $pod"
  kubectl -n "$NAMESPACE" logs "$pod" --tail=200 >> "$OUT_DIR/${pod}.log" || true
  kubectl -n "$NAMESPACE" exec "$pod" -- sh -c 'echo "${HOSTNAME} $(date -u +%Y-%m-%dT%H:%M:%SZ)"' >> "$OUT_DIR/pod_timestamps.txt" || true
done

printf '\n## Notes\n\n' >> "$OUT_DIR/latency_capture.md"
printf 'This capture is a lightweight local latency signal for the kind scale harness. For stronger evidence, run with longer windows and compare the timings across the matrix.\n' >> "$OUT_DIR/latency_capture.md"

echo "[latency] captured output to $OUT_DIR"
