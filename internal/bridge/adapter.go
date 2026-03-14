package bridge

import (
	"fmt"
	"strings"
)

// Adapter verifies source/target-chain specific proof semantics.
type Adapter interface {
	Name() string
	Verify(req TransferRequest) error
}

type evmAdapter struct{}

type cosmosAdapter struct{}

type substrateAdapter struct{}

type genericAdapter struct{}

func (a evmAdapter) Name() string { return "evm" }

func (a cosmosAdapter) Name() string { return "cosmos" }

func (a substrateAdapter) Name() string { return "substrate" }

func (a genericAdapter) Name() string { return "generic" }

func (a evmAdapter) Verify(req TransferRequest) error {
	senderEVM := strings.HasPrefix(strings.ToLower(req.Sender), "0x")
	receiverEVM := strings.HasPrefix(strings.ToLower(req.Receiver), "0x")
	if !senderEVM && !receiverEVM {
		return fmt.Errorf("evm adapter requires at least one hex address with 0x prefix")
	}
	if len(req.Proof) < 8 {
		return fmt.Errorf("evm proof too short")
	}
	trimmed := strings.TrimSpace(req.Proof)
	if strings.HasPrefix(trimmed, "{") && looksLikeEVMLogProofJSON(trimmed) {
		if _, err := parseEVMLogProof(trimmed); err != nil {
			return err
		}
	}
	return nil
}

func (a cosmosAdapter) Verify(req TransferRequest) error {
	senderCosmos := strings.Contains(strings.ToLower(req.Sender), "1")
	receiverCosmos := strings.Contains(strings.ToLower(req.Receiver), "1")
	if !senderCosmos && !receiverCosmos {
		return fmt.Errorf("cosmos adapter expects at least one bech32-style address")
	}
	if len(req.Proof) < 8 {
		return fmt.Errorf("cosmos proof too short")
	}
	trimmed := strings.TrimSpace(req.Proof)
	if strings.HasPrefix(trimmed, "{") && looksLikeCosmosIBCProofJSON(trimmed) {
		if _, err := parseCosmosIBCProof(trimmed); err != nil {
			return err
		}
	}
	return nil
}

func (a substrateAdapter) Verify(req TransferRequest) error {
	if len(req.Sender) < 6 && len(req.Receiver) < 6 {
		return fmt.Errorf("substrate adapter expects at least one non-trivial SS58 address")
	}
	if len(req.Proof) < 8 {
		return fmt.Errorf("substrate proof too short")
	}
	return nil
}

func (a genericAdapter) Verify(req TransferRequest) error {
	if len(req.Proof) < 8 {
		return fmt.Errorf("proof too short")
	}
	return nil
}

func normalizeChain(chain string) string {
	chain = strings.ToLower(strings.TrimSpace(chain))
	if idx := strings.Index(chain, ":"); idx > 0 {
		chain = chain[:idx]
	}
	return chain
}
