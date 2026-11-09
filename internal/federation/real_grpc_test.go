package federation

import (
	"context"
	"testing"

	federationpb "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/gen"
)

func TestRealGRPCRoundTrip(t *testing.T) {
	srv, lis, err := NewRealGRPCServer()
	if err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()

	client, cleanup, err := DialRealFederation(context.Background(), lis)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()

	resp, err := client.ForwardGradient(context.Background(), &federationpb.GradientRequest{GradientId: "g1"})
	if err != nil {
		t.Fatal(err)
	}
	if !resp.Success {
		t.Fatalf("expected success")
	}
}
