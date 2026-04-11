package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/router"
)

func TestHTTPFlowAllowRoute(t *testing.T) {
	policy := router.NewPolicyEngine()
	policy.Allow("climate", "supply-chain")
	r := router.New(
		policy,
		func(_ string, _ []byte) error { return nil },
		func(_ string, _ []byte, _ [32]byte) (bool, error) { return true, nil },
	)
	mux := buildMux(r)

	publishBody := map[string]any{
		"source_vertical":     "climate",
		"model_id":            "climate-global-v3",
		"summary":             "embeddings",
		"expected_proof_root": "",
		"publisher_node_id":   "publisher-a",
		"publisher_quote":     []byte("ok"),
		"proof_payload":       []byte("proof"),
	}
	resp := performJSON(t, mux, http.MethodPost, "/router/publish", publishBody)
	if resp.Code != http.StatusOK {
		t.Fatalf("publish status=%d body=%s", resp.Code, resp.Body.String())
	}

	subscribeBody := map[string]any{
		"subscriber_vertical": "supply-chain",
		"source_verticals":    []string{"climate"},
		"subscriber_node_id":  "subscriber-a",
		"subscriber_quote":    []byte("ok"),
	}
	resp = performJSON(t, mux, http.MethodPost, "/router/subscribe", subscribeBody)
	if resp.Code != http.StatusNoContent {
		t.Fatalf("subscribe status=%d body=%s", resp.Code, resp.Body.String())
	}

	resp = performJSON(t, mux, http.MethodGet, "/router/discover?subscriber_vertical=supply-chain", nil)
	if resp.Code != http.StatusOK {
		t.Fatalf("discover status=%d body=%s", resp.Code, resp.Body.String())
	}
	var offers []router.InsightOffer
	if err := json.Unmarshal(resp.Body.Bytes(), &offers); err != nil {
		t.Fatalf("decode discover response: %v", err)
	}
	if len(offers) != 1 {
		t.Fatalf("expected 1 offer, got %d", len(offers))
	}

	recordBody := map[string]any{
		"offer_id":         offers[0].OfferID,
		"source_vertical":  "climate",
		"target_vertical":  "supply-chain",
		"subscriber_model": "scm-forecast-v9",
		"impact_metric":    "mae",
		"impact_delta":     -0.21,
	}
	resp = performJSON(t, mux, http.MethodPost, "/router/provenance", recordBody)
	if resp.Code != http.StatusOK {
		t.Fatalf("provenance post status=%d body=%s", resp.Code, resp.Body.String())
	}

	resp = performJSON(t, mux, http.MethodGet, "/router/provenance", nil)
	if resp.Code != http.StatusOK {
		t.Fatalf("provenance get status=%d body=%s", resp.Code, resp.Body.String())
	}
	var records []router.ProvenanceRecord
	if err := json.Unmarshal(resp.Body.Bytes(), &records); err != nil {
		t.Fatalf("decode provenance response: %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("expected 1 provenance record, got %d", len(records))
	}
}

func TestHTTPFlowDenyRoute(t *testing.T) {
	policy := router.NewPolicyEngine()
	policy.Allow("oncology", "supply-chain")
	policy.Block("oncology", "supply-chain")
	r := router.New(
		policy,
		func(_ string, _ []byte) error { return nil },
		func(_ string, _ []byte, _ [32]byte) (bool, error) { return true, nil },
	)
	mux := buildMux(r)

	subscribeBody := map[string]any{
		"subscriber_vertical": "supply-chain",
		"source_verticals":    []string{"oncology"},
		"subscriber_node_id":  "subscriber-b",
		"subscriber_quote":    []byte("ok"),
	}
	resp := performJSON(t, mux, http.MethodPost, "/router/subscribe", subscribeBody)
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected denied subscription 400, got %d body=%s", resp.Code, resp.Body.String())
	}
}

func performJSON(t *testing.T, mux *http.ServeMux, method, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var payload []byte
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal request body: %v", err)
		}
		payload = encoded
	}
	req := httptest.NewRequest(method, path, bytes.NewReader(payload))
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp := httptest.NewRecorder()
	mux.ServeHTTP(resp, req)
	return resp
}
