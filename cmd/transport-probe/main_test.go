package main

import (
	"context"
	"testing"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
)

func TestPickDialableAddrPrefersNonLoopback(t *testing.T) {
	got, err := pickDialableAddr([]string{"/ip4/127.0.0.1/tcp/1234", "/ip4/172.18.0.2/tcp/4321"})
	if err != nil {
		t.Fatalf("pickDialableAddr returned error: %v", err)
	}
	if got != "/ip4/172.18.0.2/tcp/4321" {
		t.Fatalf("expected non-loopback address, got %q", got)
	}
}

func TestPickDialableAddrRejectsEmptyList(t *testing.T) {
	if _, err := pickDialableAddr(nil); err == nil {
		t.Fatal("expected error for empty address list")
	}
}

func BenchmarkProbeLocalEcho(b *testing.B) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	for i := 0; i < b.N; i++ {
		receiver, err := network.NewHost(ctx, network.DefaultConfig(0))
		if err != nil {
			b.Fatalf("receiver host: %v", err)
		}
		received := make(chan *network.GradientMessage, 1)
		network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeX25519, func(msg *network.GradientMessage) *network.GradientAck {
			received <- msg
			return &network.GradientAck{Accepted: true}
		})

		sender, err := network.NewHost(ctx, network.DefaultConfig(0))
		if err != nil {
			_ = receiver.Close()
			b.Fatalf("sender host: %v", err)
		}

		msg := &network.GradientMessage{NodeID: "probe-bench", TaskID: "task-bench", Round: 1, Gradients: []float64{1.0}}
		ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
		if err != nil {
			_ = receiver.Close()
			_ = sender.Close()
			b.Fatalf("send gradient: %v", err)
		}
		if !ack.Accepted {
			_ = receiver.Close()
			_ = sender.Close()
			b.Fatalf("expected accepted=true, got false reason=%q", ack.Reason)
		}

		select {
		case <-received:
		case <-ctx.Done():
			_ = receiver.Close()
			_ = sender.Close()
			b.Fatal("timed out waiting for receiver to observe the message")
		}

		_ = receiver.Close()
		_ = sender.Close()
	}
}

func TestProbeLocalEchoAcceptsGradient(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
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

	msg := &network.GradientMessage{NodeID: "probe-test", TaskID: "task-test", Round: 1, Gradients: []float64{1.0}}
	ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
	if err != nil {
		t.Fatalf("send gradient: %v", err)
	}
	if !ack.Accepted {
		t.Fatalf("expected accepted=true, got false reason=%q", ack.Reason)
	}

	select {
	case got := <-received:
		if got.NodeID != msg.NodeID || got.Round != msg.Round || len(got.Gradients) != 1 {
			t.Fatalf("unexpected received message: %+v", got)
		}
	case <-ctx.Done():
		t.Fatal("timed out waiting for receiver to observe the message")
	}
}
