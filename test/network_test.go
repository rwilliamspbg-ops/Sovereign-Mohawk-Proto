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
	network.RegisterGradientHandler(receiver, func(msg *network.GradientMessage) *network.GradientAck {
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

	ack, err := network.SendGradient(ctx, sender, receiver.ID(), receiver.Addrs(), msg)
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
