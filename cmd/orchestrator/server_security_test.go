package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
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
