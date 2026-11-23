package ipfs

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestNewBackendTrimsTrailingSlashes(t *testing.T) {
	b := NewBackend("http://127.0.0.1:5001///")
	if b.endpoint != "http://127.0.0.1:5001" {
		t.Fatalf("endpoint = %q, want trailing slashes trimmed", b.endpoint)
	}
	if b.client == nil {
		t.Fatal("expected an HTTP client")
	}
}

func TestBackendEnabled(t *testing.T) {
	var nilBackend *Backend
	cases := []struct {
		name string
		b    *Backend
		want bool
	}{
		{"nil receiver", nilBackend, false},
		{"empty endpoint", NewBackend(""), false},
		{"configured endpoint", NewBackend("http://127.0.0.1:5001"), true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.b.Enabled(); got != tc.want {
				t.Errorf("Enabled() = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestPutCheckpointDisabled(t *testing.T) {
	var nilBackend *Backend
	if _, err := nilBackend.PutCheckpoint(context.Background(), "n", []byte("x")); err == nil {
		t.Error("nil backend: expected an error")
	}
	disabled := NewBackend("")
	if _, err := disabled.PutCheckpoint(context.Background(), "n", []byte("x")); err == nil {
		t.Error("empty endpoint: expected an error")
	}
}

func TestPutCheckpointRoundTrip(t *testing.T) {
	var gotMethod, gotPath, gotQuery, gotFilename, gotContentType string
	var gotPayload []byte

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotPath = r.URL.Path
		gotQuery = r.URL.RawQuery
		gotContentType = r.Header.Get("Content-Type")
		file, hdr, err := r.FormFile("file")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		defer file.Close()
		gotFilename = hdr.Filename
		gotPayload, _ = io.ReadAll(file)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(AddResponse{Name: hdr.Filename, Hash: "QmRoundTripHash", Size: "3"})
	}))
	defer srv.Close()

	b := NewBackend(srv.URL)
	hash, err := b.PutCheckpoint(context.Background(), "checkpoints/round.bin", []byte("abc"))
	if err != nil {
		t.Fatalf("PutCheckpoint: %v", err)
	}
	if hash != "QmRoundTripHash" {
		t.Errorf("hash = %q, want %q", hash, "QmRoundTripHash")
	}
	if gotMethod != http.MethodPost {
		t.Errorf("method = %q, want POST", gotMethod)
	}
	if gotPath != "/api/v0/add" {
		t.Errorf("path = %q, want /api/v0/add", gotPath)
	}
	if gotQuery != "pin=true" {
		t.Errorf("query = %q, want pin=true", gotQuery)
	}
	if !strings.HasPrefix(gotContentType, "multipart/form-data;") {
		t.Errorf("content-type = %q, want multipart/form-data", gotContentType)
	}
	if gotFilename != "round.bin" {
		t.Errorf("filename = %q, want path.Base(name) = round.bin", gotFilename)
	}
	if string(gotPayload) != "abc" {
		t.Errorf("payload = %q, want abc", gotPayload)
	}
}

func TestPutCheckpointErrorStatus(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
	}{
		{"internal server error", http.StatusInternalServerError, "boom"},
		{"not found", http.StatusNotFound, "no such endpoint"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tc.status)
				_, _ = io.WriteString(w, tc.body)
			}))
			defer srv.Close()

			b := NewBackend(srv.URL)
			hash, err := b.PutCheckpoint(context.Background(), "n", []byte("x"))
			if err == nil {
				t.Fatalf("expected an error for HTTP %d", tc.status)
			}
			if !strings.Contains(err.Error(), tc.body) {
				t.Errorf("error = %q, want it to contain the response body %q", err, tc.body)
			}
			if hash != "" {
				t.Errorf("hash = %q, want empty on error", hash)
			}
		})
	}
}

func TestPutCheckpointMalformedResponse(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "this is not json")
	}))
	defer srv.Close()

	b := NewBackend(srv.URL)
	if _, err := b.PutCheckpoint(context.Background(), "n", []byte("x")); err == nil {
		t.Fatal("expected a decode error for a malformed add response")
	}
}

func TestPutCheckpointClientError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"Hash":"Qm"}`)
	}))
	defer srv.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	b := NewBackend(srv.URL)
	if _, err := b.PutCheckpoint(ctx, "n", []byte("x")); err == nil {
		t.Fatal("expected an error when the request context is already cancelled")
	}
}

func TestGetCheckpointRoundTrip(t *testing.T) {
	const cid = "Qm/abc?x=1&y=2"
	var gotMethod, gotPath, gotArg string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotPath = r.URL.Path
		gotArg = r.URL.Query().Get("arg")
		_, _ = io.WriteString(w, "checkpoint-payload")
	}))
	defer srv.Close()

	b := NewBackend(srv.URL)
	payload, err := b.GetCheckpoint(context.Background(), cid)
	if err != nil {
		t.Fatalf("GetCheckpoint: %v", err)
	}
	if string(payload) != "checkpoint-payload" {
		t.Errorf("payload = %q, want checkpoint-payload", payload)
	}
	if gotMethod != http.MethodPost {
		t.Errorf("method = %q, want POST", gotMethod)
	}
	if gotPath != "/api/v0/cat" {
		t.Errorf("path = %q, want /api/v0/cat", gotPath)
	}
	if gotArg != cid {
		t.Errorf("arg = %q, want the CID round-tripped as %q", gotArg, cid)
	}
}

func TestGetCheckpointErrorStatus(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = io.WriteString(w, "cat failed hard")
	}))
	defer srv.Close()

	b := NewBackend(srv.URL)
	payload, err := b.GetCheckpoint(context.Background(), "QmX")
	if err == nil {
		t.Fatal("expected an error for HTTP 500")
	}
	if !strings.Contains(err.Error(), "cat failed hard") {
		t.Errorf("error = %q, want it to contain the response body", err)
	}
	if payload != nil {
		t.Errorf("payload = %v, want nil on error", payload)
	}
}

func TestGetCheckpointDisabled(t *testing.T) {
	var nilBackend *Backend
	if _, err := nilBackend.GetCheckpoint(context.Background(), "QmX"); err == nil {
		t.Error("nil backend: expected an error")
	}
	disabled := NewBackend("")
	if _, err := disabled.GetCheckpoint(context.Background(), "QmX"); err == nil {
		t.Error("empty endpoint: expected an error")
	}
}
