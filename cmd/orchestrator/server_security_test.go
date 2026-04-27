package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
)

func TestAuthorizeAdmin_FailClosedWhenTokenMissing(t *testing.T) {
	t.Setenv("MOHAWK_ALLOW_UNAUTH_ADMIN", "")
	s := &Server{AdminToken: ""}
	req := httptest.NewRequest(http.MethodPost, "/ledger/migration/config", nil)
	rr := httptest.NewRecorder()

	ok := s.authorizeAdmin(rr, req)
	if ok {
		t.Fatal("expected authorization to fail when admin token is missing")
	}
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rr.Code)
	}
}

func TestAuthorizeAdmin_AllowOverride(t *testing.T) {
	t.Setenv("MOHAWK_ALLOW_UNAUTH_ADMIN", "true")
	s := &Server{AdminToken: ""}
	req := httptest.NewRequest(http.MethodPost, "/ledger/migration/config", nil)
	rr := httptest.NewRecorder()

	if !s.authorizeAdmin(rr, req) {
		t.Fatal("expected authorization to pass with explicit insecure override")
	}
}

func TestHandleAttest_RejectsOversizedBody(t *testing.T) {
	s := &Server{}
	pad := strings.Repeat("A", int(maxJSONRequestBodyBytes)+1024)
	body := `{"node_id":"node-1","quote":"` + pad + `"}`
	req := httptest.NewRequest(http.MethodPost, "/attest", strings.NewReader(body))
	rr := httptest.NewRecorder()

	s.HandleAttest(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for oversized payload, got %d", rr.Code)
	}
}

func TestHandleCheckpointPut_RedactsBackendError(t *testing.T) {
	ipfsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "backend auth token leaked", http.StatusInternalServerError)
	}))
	defer ipfsServer.Close()

	s := &Server{Checkpoints: ipfs.NewBackend(ipfsServer.URL)}
	req := httptest.NewRequest(http.MethodPost, "/checkpoints/put", strings.NewReader(`{"name":"state.json","payload":"abc"}`))
	rr := httptest.NewRecorder()

	s.HandleCheckpointPut(rr, req)

	if rr.Code != http.StatusBadGateway {
		t.Fatalf("expected 502, got %d", rr.Code)
	}
	body := rr.Body.String()
	if !strings.Contains(body, "checkpoint storage failed") {
		t.Fatalf("expected redacted backend message, got %q", body)
	}
	if strings.Contains(body, "backend auth token leaked") {
		t.Fatalf("response leaked backend details: %q", body)
	}
}

func TestHandleCheckpointGet_RedactsBackendError(t *testing.T) {
	ipfsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "cid lookup exposed internals", http.StatusInternalServerError)
	}))
	defer ipfsServer.Close()

	s := &Server{Checkpoints: ipfs.NewBackend(ipfsServer.URL)}
	req := httptest.NewRequest(http.MethodGet, "/checkpoints/get?cid=abc123", nil)
	rr := httptest.NewRecorder()

	s.HandleCheckpointGet(rr, req)

	if rr.Code != http.StatusBadGateway {
		t.Fatalf("expected 502, got %d", rr.Code)
	}
	body := rr.Body.String()
	if !strings.Contains(body, "checkpoint retrieval failed") {
		t.Fatalf("expected redacted backend message, got %q", body)
	}
	if strings.Contains(body, "cid lookup exposed internals") {
		t.Fatalf("response leaked backend details: %q", body)
	}
}

func TestHandleMeshPlan_ReturnsGenericValidationError(t *testing.T) {
	s := &Server{MeshDimensions: 1024}
	req := httptest.NewRequest(http.MethodGet, "/mesh/plan?total_nodes=100&dimensions=0", nil)
	rr := httptest.NewRecorder()

	s.HandleMeshPlan(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}
	body := rr.Body.String()
	if !strings.Contains(body, "invalid mesh parameters") {
		t.Fatalf("expected generic error message, got %q", body)
	}
}

func TestHandleCheckpointGet_SuccessReturnsPayloadJSON(t *testing.T) {
	ipfsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("payload-data"))
	}))
	defer ipfsServer.Close()

	s := &Server{Checkpoints: ipfs.NewBackend(ipfsServer.URL)}
	req := httptest.NewRequest(http.MethodGet, "/checkpoints/get?cid=abc123", nil)
	rr := httptest.NewRecorder()

	s.HandleCheckpointGet(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	var response map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Fatalf("expected valid json response: %v", err)
	}
	if response["payload"] != "payload-data" {
		t.Fatalf("unexpected payload %q", response["payload"])
	}
}
