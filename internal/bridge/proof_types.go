package bridge

import (
	"encoding/json"
	"fmt"
	"strings"
)

// EVMLogProof models an EVM receipt/log inclusion proof payload.
type EVMLogProof struct {
	BlockHash   string `json:"block_hash"`
	TxHash      string `json:"tx_hash"`
	LogIndex    uint64 `json:"log_index"`
	EventSig    string `json:"event_sig"`
	ReceiptRoot string `json:"receipt_root"`
}

// CosmosIBCProof models an IBC packet commitment proof payload.
type CosmosIBCProof struct {
	ClientID     string `json:"client_id"`
	ConnectionID string `json:"connection_id"`
	ChannelID    string `json:"channel_id"`
	PortID       string `json:"port_id"`
	Sequence     uint64 `json:"sequence"`
	Commitment   string `json:"commitment"`
	Height       uint64 `json:"height"`
}

func parseEVMLogProof(raw string) (EVMLogProof, error) {
	var p EVMLogProof
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		return EVMLogProof{}, fmt.Errorf("invalid EVM JSON proof: %w", err)
	}
	if !strings.HasPrefix(strings.ToLower(strings.TrimSpace(p.BlockHash)), "0x") {
		return EVMLogProof{}, fmt.Errorf("evm block_hash must start with 0x")
	}
	if !strings.HasPrefix(strings.ToLower(strings.TrimSpace(p.TxHash)), "0x") {
		return EVMLogProof{}, fmt.Errorf("evm tx_hash must start with 0x")
	}
	if strings.TrimSpace(p.EventSig) == "" {
		return EVMLogProof{}, fmt.Errorf("evm event_sig is required")
	}
	if !strings.HasPrefix(strings.ToLower(strings.TrimSpace(p.ReceiptRoot)), "0x") {
		return EVMLogProof{}, fmt.Errorf("evm receipt_root must start with 0x")
	}
	return p, nil
}

func parseCosmosIBCProof(raw string) (CosmosIBCProof, error) {
	var p CosmosIBCProof
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		return CosmosIBCProof{}, fmt.Errorf("invalid Cosmos IBC JSON proof: %w", err)
	}
	if strings.TrimSpace(p.ClientID) == "" {
		return CosmosIBCProof{}, fmt.Errorf("cosmos client_id is required")
	}
	if strings.TrimSpace(p.ChannelID) == "" {
		return CosmosIBCProof{}, fmt.Errorf("cosmos channel_id is required")
	}
	if strings.TrimSpace(p.PortID) == "" {
		return CosmosIBCProof{}, fmt.Errorf("cosmos port_id is required")
	}
	if p.Sequence == 0 {
		return CosmosIBCProof{}, fmt.Errorf("cosmos sequence must be > 0")
	}
	if strings.TrimSpace(p.Commitment) == "" {
		return CosmosIBCProof{}, fmt.Errorf("cosmos commitment is required")
	}
	if p.Height == 0 {
		return CosmosIBCProof{}, fmt.Errorf("cosmos height must be > 0")
	}
	return p, nil
}

func looksLikeEVMLogProofJSON(raw string) bool {
	var payload map[string]any
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		return false
	}
	_, hasBlockHash := payload["block_hash"]
	_, hasTxHash := payload["tx_hash"]
	_, hasReceiptRoot := payload["receipt_root"]
	return hasBlockHash || hasTxHash || hasReceiptRoot
}

func looksLikeCosmosIBCProofJSON(raw string) bool {
	var payload map[string]any
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		return false
	}
	_, hasClientID := payload["client_id"]
	_, hasChannelID := payload["channel_id"]
	_, hasSequence := payload["sequence"]
	return hasClientID || hasChannelID || hasSequence
}
