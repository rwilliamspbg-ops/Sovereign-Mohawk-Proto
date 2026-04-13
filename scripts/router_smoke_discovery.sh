#!/usr/bin/env bash
set -euo pipefail
set -x

ROUTER_URL="${ROUTER_URL:-http://localhost:8087}"

echo "[router-smoke] target: ${ROUTER_URL}"

publish_payload='{
  "source_vertical": "climate",
  "model_id": "climate-global-v42",
  "summary": "transfer-ready weather embeddings",
  "publisher_node_id": "climate-node-a",
  "publisher_quote": [99,50,49,118,97,50,85,61]
}'

echo "[router-smoke] publish climate insight"
publish_resp="$(curl -sS -w '\nHTTP_STATUS:%{http_code}' -X POST "${ROUTER_URL}/router/publish" -H 'Content-Type: application/json' -d "${publish_payload}")"
echo "${publish_resp}"
publish_status=$(echo "$publish_resp" | awk -FHTTP_STATUS: '{print $2}' | tr -d '\n')
publish_body=$(echo "$publish_resp" | sed '/HTTP_STATUS:/d')
if [ "$publish_status" != "200" ]; then
  echo "[router-smoke][ERROR] publish failed with status $publish_status"
  exit 1
fi
echo "$publish_body" | jq -e '.offer_id' >/dev/null
offer_id="$(echo "$publish_body" | jq -r '.offer_id')"

echo "[router-smoke] subscribe supply-chain to climate"
subscribe_payload='{
  "subscriber_vertical": "supply-chain",
  "source_verticals": ["climate"],
  "subscriber_node_id": "supply-node-a",
  "subscriber_quote": [99,50,49,118,97,50,85,61]
}'
subscribe_resp="$(curl -sS -w '\nHTTP_STATUS:%{http_code}' -X POST "${ROUTER_URL}/router/subscribe" -H 'Content-Type: application/json' -d "${subscribe_payload}")"
echo "${subscribe_resp}"
subscribe_status=$(echo "$subscribe_resp" | awk -FHTTP_STATUS: '{print $2}' | tr -d '\n')
if [ "$subscribe_status" != "204" ]; then
  echo "[router-smoke][ERROR] subscribe failed with status $subscribe_status"
  exit 1
fi

echo "[router-smoke] discover routed insights"
discover_resp="$(curl -sS -w '\nHTTP_STATUS:%{http_code}' "${ROUTER_URL}/router/discover?subscriber_vertical=supply-chain")"
echo "${discover_resp}"
discover_status=$(echo "$discover_resp" | awk -FHTTP_STATUS: '{print $2}' | tr -d '\n')
discover_body=$(echo "$discover_resp" | sed '/HTTP_STATUS:/d')
if [ "$discover_status" != "200" ]; then
  echo "[router-smoke][ERROR] discover failed with status $discover_status"
  exit 1
fi
echo "$discover_body" | jq -e --arg id "$offer_id" 'map(select(.offer_id == $id)) | length == 1' >/dev/null

echo "[router-smoke] append provenance event"
provenance_payload="{\n  \"offer_id\": \"${offer_id}\",\n  \"source_vertical\": \"climate\",\n  \"target_vertical\": \"supply-chain\",\n  \"subscriber_model\": \"scm-forecast-v11\",\n  \"impact_metric\": \"mae\",\n  \"impact_delta\": -0.08\n}"
provenance_resp="$(curl -sS -w '\nHTTP_STATUS:%{http_code}' -X POST "${ROUTER_URL}/router/provenance" -H 'Content-Type: application/json' -d "${provenance_payload}")"
echo "${provenance_resp}"
provenance_status=$(echo "$provenance_resp" | awk -FHTTP_STATUS: '{print $2}' | tr -d '\n')
provenance_body=$(echo "$provenance_resp" | sed '/HTTP_STATUS:/d')
if [ "$provenance_status" != "200" ]; then
  echo "[router-smoke][ERROR] provenance append failed with status $provenance_status"
  exit 1
fi
echo "$provenance_body" | jq -e '.record_hash' >/dev/null

echo "[router-smoke] verify provenance retrieval"
verify_resp="$(curl -sS -w '\nHTTP_STATUS:%{http_code}' "${ROUTER_URL}/router/provenance")"
echo "${verify_resp}"
verify_status=$(echo "$verify_resp" | awk -FHTTP_STATUS: '{print $2}' | tr -d '\n')
verify_body=$(echo "$verify_resp" | sed '/HTTP_STATUS:/d')
if [ "$verify_status" != "200" ]; then
  echo "[router-smoke][ERROR] provenance verify failed with status $verify_status"
  exit 1
fi
echo "$verify_body" | jq -e --arg id "$offer_id" 'map(select(.event.offer_id == $id)) | length >= 1' >/dev/null

echo "[router-smoke] PASS"
