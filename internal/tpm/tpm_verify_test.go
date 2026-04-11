package tpm

import (
	"strings"
	"testing"
)

func TestGenerateAndVerifyQuoteRSA(t *testing.T) {
	t.Setenv("MOHAWK_TPM_IDENTITY_SIG_MODE", "rsa-pss-sha256")
	quote, err := GetVerifiedQuote("tpm-rsa-node")
	if err != nil {
		t.Fatalf("generate rsa quote: %v", err)
	}
	if len(quote) == 0 {
		t.Fatalf("expected non-empty quote")
	}
	if err := Verify("tpm-rsa-node", quote); err != nil {
		t.Fatalf("verify rsa quote: %v", err)
	}
}

func TestGenerateAndVerifyQuoteXMSSReplayProtection(t *testing.T) {
	t.Setenv("MOHAWK_TPM_IDENTITY_SIG_MODE", "xmss")
	nodeID := "tpm-xmss-node"

	xmssSeenMutex.Lock()
	delete(xmssSeenIndex, nodeID)
	xmssSeenMutex.Unlock()

	quote, err := GetVerifiedQuote(nodeID)
	if err != nil {
		t.Fatalf("generate xmss quote: %v", err)
	}
	if err := Verify(nodeID, quote); err != nil {
		t.Fatalf("first verify xmss quote: %v", err)
	}
	if err := Verify(nodeID, quote); err == nil {
		t.Fatalf("expected replay detection on second verify")
	} else if !strings.Contains(strings.ToLower(err.Error()), "replay index") {
		t.Fatalf("expected replay-index error, got: %v", err)
	}
}
