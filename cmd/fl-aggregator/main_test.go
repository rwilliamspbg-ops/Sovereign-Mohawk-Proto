package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandleSubmit_RequiresAuthWhenConfigured(t *testing.T) {
	t.Setenv("FL_AGGREGATOR_AUTH_TOKEN", "token-123")
	req := httptest.NewRequest(http.MethodPost, "/fl/submit", strings.NewReader(`{"node_id":"n1","grads":[1,2,3]}`))
	rr := httptest.NewRecorder()

	handleSubmit(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rr.Code)
	}
}

func TestHandleSubmit_AcceptsValidBearerToken(t *testing.T) {
	t.Setenv("FL_AGGREGATOR_AUTH_TOKEN", "token-123")
	req := httptest.NewRequest(http.MethodPost, "/fl/submit", strings.NewReader(`{"node_id":"n1","grads":[1,2,3]}`))
	req.Header.Set("Authorization", "Bearer token-123")
	rr := httptest.NewRecorder()

	handleSubmit(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}

func TestHandleSubmit_RejectsOversizedBody(t *testing.T) {
	pad := strings.Repeat("a", int(maxRequestBodyBytes)+1024)
	body := `{"node_id":"n1","grads":[1],"pad":"` + pad + `"}`
	req := httptest.NewRequest(http.MethodPost, "/fl/submit", strings.NewReader(body))
	rr := httptest.NewRecorder()

	handleSubmit(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for oversized payload, got %d", rr.Code)
	}
}

func TestHandleSubmit_FailsWhenFormalByzantineCheckFails(t *testing.T) {
	t.Setenv("FL_AGGREGATOR_TOTAL_NODES", "10")
	t.Setenv("FL_AGGREGATOR_MALICIOUS_NODES", "6")
	req := httptest.NewRequest(http.MethodPost, "/fl/submit", strings.NewReader(`{"node_id":"n1","grads":[1,2,3]}`))
	rr := httptest.NewRecorder()

	handleSubmit(rr, req)

	if rr.Code != http.StatusFailedDependency {
		t.Fatalf("expected 424 for formal check failure, got %d", rr.Code)
	}
}

func TestHandleSubmit_PassesWhenFormalByzantineCheckPasses(t *testing.T) {
	t.Setenv("FL_AGGREGATOR_TOTAL_NODES", "101")
	t.Setenv("FL_AGGREGATOR_MALICIOUS_NODES", "40")
	req := httptest.NewRequest(http.MethodPost, "/fl/submit", strings.NewReader(`{"node_id":"n1","grads":[1,2,3]}`))
	rr := httptest.NewRecorder()

	handleSubmit(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}
