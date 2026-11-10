package ipfs

import (
	"context"
	"testing"
)

func TestProperty_BackendDisabledByDefault(t *testing.T) {
	b := NewBackend("")
	if b.Enabled() {
		t.Fatal("expected disabled for empty endpoint")
	}
	_, err := b.PutCheckpoint(context.Background(), "name", []byte("x"))
	if err == nil {
		t.Fatal("expected error when disabled")
	}
}