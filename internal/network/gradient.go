// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package network

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	corenetwork "github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	ma "github.com/multiformats/go-multiaddr"
)

// GradientProtocol is the libp2p stream protocol ID for direct gradient submission.
const GradientProtocol protocol.ID = "/mohawk/gradient/1.0.0"

// GradientMessage carries a gradient update from an edge node to the aggregator.
type GradientMessage struct {
	NodeID      string    `json:"node_id"`
	TaskID      string    `json:"task_id"`
	Round       int       `json:"round"`
	Gradients   []float64 `json:"gradients"`
	TimestampMS int64     `json:"timestamp_ms"`
}

// GradientAck is the aggregator's response to a gradient submission.
type GradientAck struct {
	Accepted        bool   `json:"accepted"`
	Reason          string `json:"reason,omitempty"`
	NegotiatedKEX   string `json:"negotiated_kex,omitempty"`
	KEXPublicKeyLen int    `json:"kex_public_key_len,omitempty"`
}

type gradientEnvelope struct {
	KEXMode      string          `json:"kex_mode,omitempty"`
	KEXPublicKey []byte          `json:"kex_public_key,omitempty"`
	Message      GradientMessage `json:"message"`
}

// RegisterGradientHandler installs the /mohawk/gradient/1.0.0 stream handler on h.
// onGradient is called for each inbound message; the returned *GradientAck is written back
// to the stream. If onGradient returns nil, a default accepted=true ack is sent.
func RegisterGradientHandler(h corehost.Host, onGradient func(*GradientMessage) *GradientAck) {
	RegisterGradientHandlerWithKEX(h, KEXModeX25519, onGradient)
}

// RegisterGradientHandlerWithKEX installs the gradient stream handler with explicit KEX mode checks.
func RegisterGradientHandlerWithKEX(h corehost.Host, expectedMode KEXMode, onGradient func(*GradientMessage) *GradientAck) {
	h.SetStreamHandler(GradientProtocol, func(s corenetwork.Stream) {
		defer s.Close()
		payload, err := io.ReadAll(bufio.NewReader(s))
		if err != nil {
			s.Reset()
			return
		}

		var msg GradientMessage
		ackMeta := &GradientAck{}

		var env gradientEnvelope
		if err := json.Unmarshal(payload, &env); err == nil && env.Message.NodeID != "" {
			mode := ParseKEXMode(env.KEXMode)
			if mode == "" {
				_ = json.NewEncoder(s).Encode(&GradientAck{Accepted: false, Reason: fmt.Sprintf("unsupported kex mode %q", env.KEXMode)})
				return
			}
			if expectedMode != "" && mode != expectedMode {
				_ = json.NewEncoder(s).Encode(&GradientAck{Accepted: false, Reason: fmt.Sprintf("kex mismatch expected=%s got=%s", expectedMode, mode)})
				return
			}
			expectedBytes := mode.ExpectedPublicKeyBytes()
			if expectedBytes > 0 && len(env.KEXPublicKey) != expectedBytes {
				_ = json.NewEncoder(s).Encode(&GradientAck{Accepted: false, Reason: fmt.Sprintf("kex public key bytes mismatch expected=%d got=%d", expectedBytes, len(env.KEXPublicKey))})
				return
			}
			ackMeta.NegotiatedKEX = string(mode)
			ackMeta.KEXPublicKeyLen = len(env.KEXPublicKey)
			msg = env.Message
		} else if err := json.Unmarshal(payload, &msg); err != nil {
			s.Reset()
			return
		}

		ack := onGradient(&msg)
		if ack == nil {
			ack = &GradientAck{Accepted: true}
		}
		if ack.NegotiatedKEX == "" {
			ack.NegotiatedKEX = ackMeta.NegotiatedKEX
		}
		if ack.KEXPublicKeyLen == 0 {
			ack.KEXPublicKeyLen = ackMeta.KEXPublicKeyLen
		}
		_ = json.NewEncoder(s).Encode(ack)
	})
}

// SendGradient connects to peerID (dialing peerAddrs if provided and not yet connected)
// and delivers msg over the gradient protocol, returning the peer's GradientAck.
func SendGradient(ctx context.Context, h corehost.Host, peerID peer.ID, peerAddrs []ma.Multiaddr, msg *GradientMessage) (*GradientAck, error) {
	return SendGradientWithKEX(ctx, h, peerID, peerAddrs, msg, KEXModeX25519)
}

// SendGradientWithKEX connects to peerID and delivers msg with explicit KEX negotiation metadata.
func SendGradientWithKEX(ctx context.Context, h corehost.Host, peerID peer.ID, peerAddrs []ma.Multiaddr, msg *GradientMessage, mode KEXMode) (*GradientAck, error) {
	if len(peerAddrs) > 0 {
		if err := h.Connect(ctx, peer.AddrInfo{ID: peerID, Addrs: peerAddrs}); err != nil {
			return nil, fmt.Errorf("gradient: connect to %s: %w", peerID, err)
		}
	}
	if mode == "" {
		mode = KEXModeX25519
	}
	if ParseKEXMode(string(mode)) == "" {
		return nil, fmt.Errorf("gradient: unsupported kex mode %q", mode)
	}
	kexPublicKey, err := generateKEXPublicKey(mode)
	if err != nil {
		return nil, err
	}
	msg.TimestampMS = time.Now().UnixMilli()
	s, err := h.NewStream(ctx, peerID, GradientProtocol)
	if err != nil {
		return nil, fmt.Errorf("gradient: open stream to %s: %w", peerID, err)
	}
	defer s.Close()
	env := gradientEnvelope{
		KEXMode:      string(mode),
		KEXPublicKey: kexPublicKey,
		Message:      *msg,
	}
	if err := json.NewEncoder(s).Encode(&env); err != nil {
		return nil, fmt.Errorf("gradient: send: %w", err)
	}
	_ = s.CloseWrite()
	var ack GradientAck
	if err := json.NewDecoder(bufio.NewReader(s)).Decode(&ack); err != nil {
		return nil, fmt.Errorf("gradient: read ack: %w", err)
	}
	return &ack, nil
}

func generateKEXPublicKey(mode KEXMode) ([]byte, error) {
	bytes := mode.ExpectedPublicKeyBytes()
	if bytes <= 0 {
		return nil, fmt.Errorf("gradient: invalid expected public key size for mode %q", mode)
	}
	key := make([]byte, bytes)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("gradient: generate kex public key: %w", err)
	}
	return key, nil
}
