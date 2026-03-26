package test

import (
	"context"
	"testing"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
)

func TestDefaultConfigIncludesTCPAndQUIC(t *testing.T) {
	cfg := network.DefaultConfig(0)
	if len(cfg.ListenAddrs) != 2 {
		t.Fatalf("expected two default listen addresses, got %d", len(cfg.ListenAddrs))
	}
	if cfg.KEXMode != network.KEXModeX25519 {
		t.Fatalf("expected default KEX mode %q, got %q", network.KEXModeX25519, cfg.KEXMode)
	}
}

func TestTransportConfigValidationRejectsUnknownKEXMode(t *testing.T) {
	cfg := network.DefaultConfig(0)
	cfg.KEXMode = network.KEXMode("unsupported")
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected unsupported KEX mode to fail validation")
	}
}

func TestParseKEXModeAliases(t *testing.T) {
	if got := network.ParseKEXMode("hybrid"); got != network.KEXModeHybridX25519MLKEM768 {
		t.Fatalf("expected hybrid alias to parse into %q, got %q", network.KEXModeHybridX25519MLKEM768, got)
	}
	if got := network.ParseKEXMode("ml-kem-768"); got != network.KEXModeHybridX25519MLKEM768 {
		t.Fatalf("expected ml-kem-768 alias to parse into %q, got %q", network.KEXModeHybridX25519MLKEM768, got)
	}
}

func TestParseKEXModeStrictRejectsUnknown(t *testing.T) {
	if _, err := network.ParseKEXModeStrict("unknown-kex"); err == nil {
		t.Fatal("expected strict parser to reject unknown mode")
	}
}

func TestTransportConfigNormalizedCanonicalizesAliases(t *testing.T) {
	cfg := network.DefaultConfig(0)
	cfg.KEXMode = network.KEXMode("hybrid")
	normalized, err := cfg.Normalized()
	if err != nil {
		t.Fatalf("expected normalization success, got %v", err)
	}
	if normalized.KEXMode != network.KEXModeHybridX25519MLKEM768 {
		t.Fatalf("expected normalized mode %q, got %q", network.KEXModeHybridX25519MLKEM768, normalized.KEXMode)
	}
}

func TestNewHost(t *testing.T) {
	host, err := network.NewHost(context.Background(), network.DefaultConfig(0))
	if err != nil {
		t.Fatalf("expected libp2p host to initialize, got %v", err)
	}
	defer host.Close()
	if host.ID().String() == "" {
		t.Fatal("expected host peer id")
	}
}

// TestGradientProtocol creates two in-process libp2p hosts, registers the gradient
// handler on one, and verifies that the other can dial and deliver a message.
func TestGradientProtocol(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	receiver, err := network.NewHost(ctx, network.DefaultConfig(0))
	if err != nil {
		t.Fatalf("receiver host: %v", err)
	}
	defer receiver.Close()

	received := make(chan *network.GradientMessage, 1)
	network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeX25519, func(msg *network.GradientMessage) *network.GradientAck {
		received <- msg
		return &network.GradientAck{Accepted: true}
	})

	sender, err := network.NewHost(ctx, network.DefaultConfig(0))
	if err != nil {
		t.Fatalf("sender host: %v", err)
	}
	defer sender.Close()

	msg := &network.GradientMessage{
		NodeID:    "test-node",
		TaskID:    "task-1",
		Round:     1,
		Gradients: []float64{0.1, 0.2, 0.3},
	}

	ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
	if err != nil {
		t.Fatalf("SendGradient: %v", err)
	}
	if !ack.Accepted {
		t.Fatalf("expected ack.Accepted=true, got false: %s", ack.Reason)
	}

	select {
	case got := <-received:
		if got.NodeID != "test-node" || got.Round != 1 || len(got.Gradients) != 3 {
			t.Fatalf("unexpected message: %+v", got)
		}
	case <-ctx.Done():
		t.Fatal("timed out waiting for gradient message")
	}
}

func TestGradientProtocolRejectsKEXMismatch(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	receiverCfg := network.DefaultConfig(0)
	receiverCfg.KEXMode = network.KEXModeHybridX25519MLKEM768
	receiver, err := network.NewHost(ctx, receiverCfg)
	if err != nil {
		t.Fatalf("receiver host: %v", err)
	}
	defer receiver.Close()

	network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeHybridX25519MLKEM768, func(msg *network.GradientMessage) *network.GradientAck {
		return &network.GradientAck{Accepted: true}
	})

	sender, err := network.NewHost(ctx, network.DefaultConfig(0))
	if err != nil {
		t.Fatalf("sender host: %v", err)
	}
	defer sender.Close()

	msg := &network.GradientMessage{NodeID: "node-a", TaskID: "task-a", Round: 1, Gradients: []float64{0.1}}
	ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
	if err != nil {
		t.Fatalf("SendGradientWithKEX: %v", err)
	}
	if ack.Accepted {
		t.Fatalf("expected kex mismatch rejection, got accepted=true")
	}
}
