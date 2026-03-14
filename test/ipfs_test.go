package test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
)

func TestIPFSBackendPutAndGet(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v0/add":
			_ = json.NewEncoder(w).Encode(map[string]string{"Name": "checkpoint.json", "Hash": "bafy123", "Size": "4"})
		case "/api/v0/cat":
			_, _ = w.Write([]byte("data"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	backend := ipfs.NewBackend(server.URL)
	cid, err := backend.PutCheckpoint(context.Background(), "checkpoint.json", []byte("data"))
	if err != nil {
		t.Fatalf("expected checkpoint put to succeed, got %v", err)
	}
	if cid != "bafy123" {
		t.Fatalf("expected CID bafy123, got %s", cid)
	}
	payload, err := backend.GetCheckpoint(context.Background(), cid)
	if err != nil {
		t.Fatalf("expected checkpoint get to succeed, got %v", err)
	}
	if string(payload) != "data" {
		t.Fatalf("expected payload data, got %q", string(payload))
	}
}
