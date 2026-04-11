#!/usr/bin/env bash
set -euo pipefail

ROUTER_URL="${ROUTER_URL:-http://localhost:8087}"

echo "[router-smoke] target: ${ROUTER_URL}"

publish_payload='{
  "source_vertical": "climate",
  "model_id": "climate-global-v42",
  "summary": "transfer-ready weather embeddings",
  "publisher_node_id": "climate-node-a",
  "publisher_quote": "c21va2U="
}'

echo "[router-smoke] publish climate insight"
publish_resp="$(curl -sS -X POST "${ROUTER_URL}/router/publish" -H 'Content-Type: application/json' -d "${publish_payload}")"
echo "${publish_resp}" | jq -e '.offer_id' >/dev/null
offer_id="$(echo "${publish_resp}" | jq -r '.offer_id')"

echo "[router-smoke] subscribe supply-chain to climate"
subscribe_payload='{
  "subscriber_vertical": "supply-chain",
  "source_verticals": ["climate"],
  "subscriber_node_id": "supply-node-a",
  "subscriber_quote": "c21va2U="
}'
curl -sS -o /dev/null -w '%{http_code}' -X POST "${ROUTER_URL}/router/subscribe" -H 'Content-Type: application/json' -d "${subscribe_payload}" | grep -q '^204$'

echo "[router-smoke] discover routed insights"
discover_resp="$(curl -sS "${ROUTER_URL}/router/discover?subscriber_vertical=supply-chain")"
echo "${discover_resp}" | jq -e --arg id "${offer_id}" 'map(select(.offer_id == $id)) | length == 1' >/dev/null

echo "[router-smoke] append provenance event"
provenance_payload="{
  \"offer_id\": \"${offer_id}\",
  \"source_vertical\": \"climate\",
  \"target_vertical\": \"supply-chain\",
  \"subscriber_model\": \"scm-forecast-v11\",
  \"impact_metric\": \"mae\",
  \"impact_delta\": -0.08
}"
curl -sS -X POST "${ROUTER_URL}/router/provenance" -H 'Content-Type: application/json' -d "${provenance_payload}" | jq -e '.record_hash' >/dev/null

echo "[router-smoke] verify provenance retrieval"
curl -sS "${ROUTER_URL}/router/provenance" | jq -e --arg id "${offer_id}" 'map(select(.event.offer_id == $id)) | length >= 1' >/dev/null

echo "[router-smoke] PASS"
