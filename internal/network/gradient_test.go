package network

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

func newGradientPair(t *testing.T) (server, client corehost.Host) {
	t.Helper()
	return newNetworkTestHost(t), newNetworkTestHost(t)
}

func connectTestHosts(t *testing.T, ctx context.Context, from, to corehost.Host) {
	t.Helper()
	if err := from.Connect(ctx, peer.AddrInfo{ID: to.ID(), Addrs: to.Addrs()}); err != nil {
		t.Fatalf("connect %s -> %s: %v", from.ID(), to.ID(), err)
	}
}

func TestGradientSingleRoundTrip(t *testing.T) {
	server, client := newGradientPair(t)
	ctx := context.Background()

	recv := make(chan GradientMessage, 1)
	RegisterGradientHandler(server, func(m *GradientMessage) *GradientAck {
		recv <- *m
		return nil
	})

	msg := &GradientMessage{NodeID: "node-1", TaskID: "task-1", Round: 3, Gradients: []float64{1, 2, 3}}
	ack, err := SendGradient(ctx, client, server.ID(), server.Addrs(), msg)
	if err != nil {
		t.Fatalf("SendGradient: %v", err)
	}
	if !ack.Accepted {
		t.Fatalf("ack.Accepted = false, want true (reason=%q)", ack.Reason)
	}
	if ack.NegotiatedKEX != string(KEXModeX25519) {
		t.Errorf("NegotiatedKEX = %q, want x25519", ack.NegotiatedKEX)
	}
	if ack.KEXPublicKeyLen != 32 {
		t.Errorf("KEXPublicKeyLen = %d, want 32", ack.KEXPublicKeyLen)
	}
	if msg.TimestampMS == 0 {
		t.Error("SendGradient must stamp TimestampMS")
	}

	select {
	case got := <-recv:
		if got.NodeID != "node-1" || got.TaskID != "task-1" || got.Round != 3 {
			t.Errorf("handler saw %+v", got)
		}
		if len(got.Gradients) != 3 {
			t.Errorf("handler saw %d gradients, want 3", len(got.Gradients))
		}
	case <-time.After(10 * time.Second):
		t.Fatal("gradient handler was not invoked")
	}
}

func TestGradientBatchRoundTrip(t *testing.T) {
	server, client := newGradientPair(t)
	ctx := context.Background()

	recv := make(chan GradientMessage, 4)
	RegisterGradientHandler(server, func(m *GradientMessage) *GradientAck {
		recv <- *m
		if m.Round%2 == 0 {
			return &GradientAck{Accepted: true}
		}
		return &GradientAck{Accepted: false, Reason: "reject-odd-round"}
	})

	msgs := []GradientMessage{
		{NodeID: "a", Round: 1},
		{NodeID: "b", Round: 2},
		{NodeID: "c", Round: 3},
	}
	ack, err := SendGradientBatch(ctx, client, server.ID(), server.Addrs(), msgs)
	if err != nil {
		t.Fatalf("SendGradientBatch: %v", err)
	}
	if ack.BatchAccepted != 1 {
		t.Errorf("BatchAccepted = %d, want 1", ack.BatchAccepted)
	}
	if ack.BatchRejected != 2 {
		t.Errorf("BatchRejected = %d, want 2", ack.BatchRejected)
	}
	if ack.Accepted {
		t.Error("Accepted = true, want false when any batch item is rejected")
	}
	if ack.Reason != "reject-odd-round" {
		t.Errorf("Reason = %q, want the first rejection reason", ack.Reason)
	}
	if ack.NegotiatedKEX != string(KEXModeX25519) {
		t.Errorf("NegotiatedKEX = %q, want x25519", ack.NegotiatedKEX)
	}
	for i := range msgs {
		if msgs[i].TimestampMS == 0 {
			t.Errorf("msgs[%d].TimestampMS not stamped", i)
		}
	}
	if len(recv) != 3 {
		t.Errorf("handler invoked %d times, want 3", len(recv))
	}
}

func TestSendGradientBatchEmpty(t *testing.T) {
	// An empty batch must short-circuit before touching the host, so a nil
	// host and empty peer ID are safe here.
	ack, err := SendGradientBatch(context.Background(), nil, "", nil, nil)
	if err != nil {
		t.Fatalf("SendGradientBatch: %v", err)
	}
	if !ack.Accepted {
		t.Error("Accepted = false, want true for an empty batch")
	}
	if ack.BatchAccepted != 0 || ack.BatchRejected != 0 {
		t.Errorf("counts = %d/%d, want 0/0", ack.BatchAccepted, ack.BatchRejected)
	}
}

func TestSendGradientWithKEXRejectsUnknownMode(t *testing.T) {
	_, client := newGradientPair(t)
	_, err := SendGradientWithKEX(context.Background(), client, "", nil, &GradientMessage{NodeID: "x"}, KEXMode("bogus"))
	if err == nil {
		t.Fatal("expected an error for an unsupported KEX mode")
	}
	if !strings.Contains(err.Error(), "unsupported kex mode") {
		t.Errorf("error = %q, want it to name the unsupported mode", err)
	}
}

func TestSendGradientConnectFailure(t *testing.T) {
	server, client := newGradientPair(t)
	dead, err := ma.NewMultiaddr("/ip4/127.0.0.1/tcp/1")
	if err != nil {
		t.Fatalf("NewMultiaddr: %v", err)
	}
	_, err = SendGradient(context.Background(), client, server.ID(), []ma.Multiaddr{dead}, &GradientMessage{NodeID: "x"})
	if err == nil {
		t.Fatal("expected a connect error for an unreachable address")
	}
	if !strings.Contains(err.Error(), "connect to") {
		t.Errorf("error = %q, want it to mention the connect failure", err)
	}
}

func roundTripEnvelope(t *testing.T, client, server corehost.Host, env gradientEnvelope) GradientAck {
	t.Helper()
	ctx := context.Background()
	connectTestHosts(t, ctx, client, server)
	s, err := client.NewStream(ctx, server.ID(), GradientProtocol)
	if err != nil {
		t.Fatalf("NewStream: %v", err)
	}
	defer s.Close()
	if err := json.NewEncoder(s).Encode(env); err != nil {
		t.Fatalf("encode envelope: %v", err)
	}
	if err := s.CloseWrite(); err != nil {
		t.Fatalf("CloseWrite: %v", err)
	}
	var ack GradientAck
	if err := json.NewDecoder(s).Decode(&ack); err != nil {
		t.Fatalf("decode ack: %v", err)
	}
	return ack
}

func TestGradientHandlerAcceptsSingleEnvelope(t *testing.T) {
	server, client := newGradientPair(t)
	recv := make(chan GradientMessage, 1)
	RegisterGradientHandlerWithKEX(server, KEXModeX25519, func(m *GradientMessage) *GradientAck {
		recv <- *m
		return nil
	})

	ack := roundTripEnvelope(t, client, server, gradientEnvelope{
		KEXMode:      string(KEXModeX25519),
		KEXPublicKey: make([]byte, 32),
		Message:      GradientMessage{NodeID: "node-9", Round: 7, Gradients: []float64{1.5}},
	})
	if !ack.Accepted {
		t.Fatalf("Accepted = false, want true (reason=%q)", ack.Reason)
	}
	if ack.NegotiatedKEX != string(KEXModeX25519) {
		t.Errorf("NegotiatedKEX = %q", ack.NegotiatedKEX)
	}
	if ack.KEXPublicKeyLen != 32 {
		t.Errorf("KEXPublicKeyLen = %d, want 32", ack.KEXPublicKeyLen)
	}
	select {
	case got := <-recv:
		if got.NodeID != "node-9" || got.Round != 7 {
			t.Errorf("handler saw %+v", got)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("handler not invoked for single-envelope message")
	}
}

func TestGradientHandlerRejectPaths(t *testing.T) {
	server, client := newGradientPair(t)
	RegisterGradientHandlerWithKEX(server, KEXModeX25519, func(m *GradientMessage) *GradientAck {
		return nil
	})

	cases := []struct {
		name       string
		env        gradientEnvelope
		wantReason string
	}{
		{
			"unsupported kex mode",
			gradientEnvelope{KEXMode: "bogus", KEXPublicKey: make([]byte, 32), Message: GradientMessage{NodeID: "n"}},
			"unsupported kex mode",
		},
		{
			"kex mismatch",
			gradientEnvelope{KEXMode: string(KEXModeHybridX25519MLKEM768), KEXPublicKey: make([]byte, 1216), Message: GradientMessage{NodeID: "n"}},
			"kex mismatch",
		},
		{
			"kex public key length mismatch",
			gradientEnvelope{KEXMode: string(KEXModeX25519), KEXPublicKey: make([]byte, 16), Message: GradientMessage{NodeID: "n"}},
			"kex public key bytes mismatch",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ack := roundTripEnvelope(t, client, server, tc.env)
			if ack.Accepted {
				t.Error("Accepted = true, want rejection")
			}
			if !strings.Contains(ack.Reason, tc.wantReason) {
				t.Errorf("Reason = %q, want it to contain %q", ack.Reason, tc.wantReason)
			}
		})
	}
}

func TestGradientHandlerMalformedPayloadResetsStream(t *testing.T) {
	server, client := newGradientPair(t)
	RegisterGradientHandler(server, func(m *GradientMessage) *GradientAck { return nil })

	ctx := context.Background()
	connectTestHosts(t, ctx, client, server)
	s, err := client.NewStream(ctx, server.ID(), GradientProtocol)
	if err != nil {
		t.Fatalf("NewStream: %v", err)
	}
	defer s.Close()
	if _, err := s.Write([]byte("{not valid json")); err != nil {
		t.Fatalf("write: %v", err)
	}
	if err := s.CloseWrite(); err != nil {
		t.Fatalf("CloseWrite: %v", err)
	}
	var ack GradientAck
	if err := json.NewDecoder(s).Decode(&ack); err == nil {
		t.Fatal("expected a decode error after the handler resets a malformed stream")
	}
}

func TestGenerateKEXPublicKey(t *testing.T) {
	for _, mode := range []KEXMode{KEXModeX25519, KEXModeHybridX25519MLKEM768} {
		key, err := generateKEXPublicKey(mode)
		if err != nil {
			t.Fatalf("generateKEXPublicKey(%s): %v", mode, err)
		}
		if len(key) != mode.ExpectedPublicKeyBytes() {
			t.Errorf("mode %s: key length = %d, want %d", mode, len(key), mode.ExpectedPublicKeyBytes())
		}
	}

	first, err := generateKEXPublicKey(KEXModeX25519)
	if err != nil {
		t.Fatalf("generateKEXPublicKey: %v", err)
	}
	second, err := generateKEXPublicKey(KEXModeX25519)
	if err != nil {
		t.Fatalf("generateKEXPublicKey: %v", err)
	}
	if bytes.Equal(first, second) {
		t.Error("two generated keys are identical; expected fresh randomness per call")
	}
}
