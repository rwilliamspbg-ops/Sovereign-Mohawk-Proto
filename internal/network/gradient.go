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
	"encoding/json"
	"fmt"
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
	Accepted bool   `json:"accepted"`
	Reason   string `json:"reason,omitempty"`
}

// RegisterGradientHandler installs the /mohawk/gradient/1.0.0 stream handler on h.
// onGradient is called for each inbound message; the returned *GradientAck is written back
// to the stream. If onGradient returns nil, a default accepted=true ack is sent.
func RegisterGradientHandler(h corehost.Host, onGradient func(*GradientMessage) *GradientAck) {
	h.SetStreamHandler(GradientProtocol, func(s corenetwork.Stream) {
		defer s.Close()
		var msg GradientMessage
		if err := json.NewDecoder(bufio.NewReader(s)).Decode(&msg); err != nil {
			s.Reset()
			return
		}
		ack := onGradient(&msg)
		if ack == nil {
			ack = &GradientAck{Accepted: true}
		}
		_ = json.NewEncoder(s).Encode(ack)
	})
}

// SendGradient connects to peerID (dialing peerAddrs if provided and not yet connected)
// and delivers msg over the gradient protocol, returning the peer's GradientAck.
func SendGradient(ctx context.Context, h corehost.Host, peerID peer.ID, peerAddrs []ma.Multiaddr, msg *GradientMessage) (*GradientAck, error) {
	if len(peerAddrs) > 0 {
		if err := h.Connect(ctx, peer.AddrInfo{ID: peerID, Addrs: peerAddrs}); err != nil {
			return nil, fmt.Errorf("gradient: connect to %s: %w", peerID, err)
		}
	}
	msg.TimestampMS = time.Now().UnixMilli()
	s, err := h.NewStream(ctx, peerID, GradientProtocol)
	if err != nil {
		return nil, fmt.Errorf("gradient: open stream to %s: %w", peerID, err)
	}
	defer s.Close()
	if err := json.NewEncoder(s).Encode(msg); err != nil {
		return nil, fmt.Errorf("gradient: send: %w", err)
	}
	_ = s.CloseWrite()
	var ack GradientAck
	if err := json.NewDecoder(bufio.NewReader(s)).Decode(&ack); err != nil {
		return nil, fmt.Errorf("gradient: read ack: %w", err)
	}
	return &ack, nil
}
