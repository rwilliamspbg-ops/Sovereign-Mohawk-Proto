package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAggregateHandler_RequiresAuthWhenConfigured(t *testing.T) {
	t.Setenv("AGGREGATOR_AUTH_TOKEN", "token-123")
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(`[{"id":"n1","value":1}]`))
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rr.Code)
	}
}

func TestAggregateHandler_AcceptsValidBearerToken(t *testing.T) {
	t.Setenv("AGGREGATOR_AUTH_TOKEN", "token-123")
	t.Setenv("AGGREGATOR_TOTAL_NODES", "101")
	t.Setenv("AGGREGATOR_MALICIOUS_NODES", "40")
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(`[{"id":"n1","value":1}]`))
	req.Header.Set("Authorization", "Bearer token-123")
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}

func TestAggregateHandler_RejectsOversizedBody(t *testing.T) {
	t.Setenv("AGGREGATOR_TOTAL_NODES", "101")
	t.Setenv("AGGREGATOR_MALICIOUS_NODES", "40")
	pad := strings.Repeat("a", int(maxRequestBodyBytes)+1024)
	body := `[{"id":"n1","value":1,"pad":"` + pad + `"}]`
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(body))
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for oversized payload, got %d", rr.Code)
	}
}

func TestAggregateHandler_FailsWhenFormalByzantineInputsMissing(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(`[{"id":"n1","value":1}]`))
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusFailedDependency {
		t.Fatalf("expected 424 when formal check inputs are missing, got %d", rr.Code)
	}
}

func TestAggregateHandler_FailsWhenFormalByzantineCheckFails(t *testing.T) {
	t.Setenv("AGGREGATOR_TOTAL_NODES", "10")
	t.Setenv("AGGREGATOR_MALICIOUS_NODES", "6")
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(`[{"id":"n1","value":1}]`))
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusFailedDependency {
		t.Fatalf("expected 424 for formal check failure, got %d", rr.Code)
	}
}

func TestAggregateHandler_PassesWhenFormalByzantineCheckPasses(t *testing.T) {
	t.Setenv("AGGREGATOR_TOTAL_NODES", "101")
	t.Setenv("AGGREGATOR_MALICIOUS_NODES", "40")
	req := httptest.NewRequest(http.MethodPost, "/aggregate", strings.NewReader(`[{"id":"n1","value":1}]`))
	rr := httptest.NewRecorder()

	aggregateHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}
