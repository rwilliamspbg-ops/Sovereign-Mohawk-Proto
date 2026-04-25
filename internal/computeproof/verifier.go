package computeproof

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
)

// Verifier enforces challenge binding and replay resistance for proofs.
type Verifier struct {
	mu   sync.Mutex
	seen map[string]struct{}
}

func NewVerifier() *Verifier {
	return &Verifier{seen: map[string]struct{}{}}
}

func (v *Verifier) Verify(trace Trace, proof Proof) (bool, error) {
	if v == nil {
		return false, fmt.Errorf("verifier is nil")
	}
	traceHash, err := trace.Hash()
	if err != nil {
		return false, err
	}
	if traceHash != strings.TrimSpace(proof.TraceHash) {
		return false, nil
	}
	challenge := strings.TrimSpace(proof.Challenge)
	if challenge == "" {
		return false, fmt.Errorf("challenge is required")
	}
	recomputed := sha256.Sum256([]byte(traceHash + ":" + challenge))
	if hex.EncodeToString(recomputed[:]) != strings.TrimSpace(proof.Seal) {
		return false, nil
	}

	replayKey := traceHash + ":" + challenge
	v.mu.Lock()
	defer v.mu.Unlock()
	if _, exists := v.seen[replayKey]; exists {
		return false, nil
	}
	v.seen[replayKey] = struct{}{}
	return true, nil
}
