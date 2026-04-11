package router

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

func TestPublishDiscoverAndProvenance(t *testing.T) {
	policy := NewPolicyEngine()
	policy.Allow("climate", "supply-chain")

	r := New(
		policy,
		func(_ string, quote []byte) error {
			if len(quote) == 0 {
				t.Fatal("missing quote")
			}
			return nil
		},
		func(_ string, payload []byte, _ [32]byte) (bool, error) {
			return len(payload) > 0, nil
		},
	)

	offer, err := r.PublishInsight(InsightOffer{
		SourceVertical:    "climate",
		ModelID:           "climate-global-v7",
		Summary:           "storm index embeddings",
		ExpectedProofRoot: "expected",
		ProofPayload:      []byte("proof"),
		PublisherNodeID:   "node-a",
		PublisherQuote:    []byte("attested"),
	})
	if err != nil {
		t.Fatalf("publish failed: %v", err)
	}
	if offer.OfferID == "" {
		t.Fatal("expected generated offer id")
	}

	err = r.RegisterSubscription(SubscriptionRequest{
		SubscriberVertical: "supply-chain",
		SourceVerticals:    []string{"climate"},
		SubscriberNodeID:   "node-b",
		SubscriberQuote:    []byte("attested"),
	})
	if err != nil {
		t.Fatalf("subscribe failed: %v", err)
	}

	offers, err := r.Discover("supply-chain")
	if err != nil {
		t.Fatalf("discover failed: %v", err)
	}
	if len(offers) != 1 {
		t.Fatalf("expected 1 offer, got %d", len(offers))
	}

	record, err := r.RecordTransfer(ProvenanceEvent{
		OfferID:         offer.OfferID,
		SourceVertical:  "climate",
		TargetVertical:  "supply-chain",
		SubscriberModel: "scm-forecast-v2",
		ImpactMetric:    "mae",
		ImpactDelta:     -0.13,
	})
	if err != nil {
		t.Fatalf("record transfer failed: %v", err)
	}
	if record.RecordHash == "" {
		t.Fatal("expected record hash")
	}
	if got := r.Provenance(); len(got) != 1 {
		t.Fatalf("expected 1 provenance record, got %d", len(got))
	}
}

func TestBlockedRouteDenied(t *testing.T) {
	policy := NewPolicyEngine()
	policy.Allow("oncology", "supply-chain")
	policy.Block("oncology", "supply-chain")

	r := New(policy, nil, nil)
	err := r.RegisterSubscription(SubscriptionRequest{
		SubscriberVertical: "supply-chain",
		SourceVerticals:    []string{"oncology"},
		SubscriberNodeID:   "node-c",
		SubscriberQuote:    []byte("ok"),
	})
	if err == nil {
		t.Fatal("expected blocked route error")
	}
}

func TestSchemaTranslation(t *testing.T) {
	translator := SchemaTranslator{}
	out, err := translator.Translate(TranslationRequest{
		SourceVertical: "climate",
		TargetVertical: "agriculture",
		SourceSchema:   []string{"temp", "humidity", "wind"},
		TargetSchema:   []string{"humidity", "soil", "wind"},
		Gradient:       []float64{0.1, 0.2, 0.3},
	})
	if err != nil {
		t.Fatalf("translate failed: %v", err)
	}
	if len(out) != 3 {
		t.Fatalf("expected 3 dimensions, got %d", len(out))
	}
	if out[0] != 0.2 || out[1] != 0 || out[2] != 0.3 {
		t.Fatalf("unexpected translation output: %#v", out)
	}
}

func TestProvenancePersistsAcrossRestarts(t *testing.T) {
	persistPath := filepath.Join(t.TempDir(), "router-provenance.json")
	ledger, err := NewFileBackedProvenanceLedger(persistPath)
	if err != nil {
		t.Fatalf("new file-backed ledger: %v", err)
	}
	r := NewWithLedger(nil, nil, nil, ledger)

	_, err = r.RecordTransfer(ProvenanceEvent{
		OfferID:        "offer-1",
		SourceVertical: "climate",
		TargetVertical: "supply-chain",
		ImpactMetric:   "mae",
		ImpactDelta:    -0.04,
	})
	if err != nil {
		t.Fatalf("record transfer: %v", err)
	}

	reloaded, err := NewFileBackedProvenanceLedger(persistPath)
	if err != nil {
		t.Fatalf("reload file-backed ledger: %v", err)
	}
	if got := len(reloaded.Records()); got != 1 {
		t.Fatalf("expected 1 persisted record, got %d", got)
	}
}

func TestPublishWithSignedAttestationFixturePath(t *testing.T) {
	t.Setenv("MOHAWK_TPM_IDENTITY_SIG_MODE", "rsa-pss-sha256")
	fixturePath, nodeID := writeSignedAttestationFixture(t)
	quote, err := os.ReadFile(fixturePath)
	if err != nil {
		t.Fatalf("read fixture quote: %v", err)
	}

	r := New(
		nil,
		func(id string, q []byte) error { return tpm.Verify(id, q) },
		func(_ string, _ []byte, _ [32]byte) (bool, error) { return true, nil },
	)

	_, err = r.PublishInsight(InsightOffer{
		SourceVertical:  "oncology",
		ModelID:         "oncology-global-v1",
		PublisherNodeID: nodeID,
		PublisherQuote:  quote,
	})
	if err != nil {
		t.Fatalf("publish with signed fixture failed: %v", err)
	}
}

func writeSignedAttestationFixture(t *testing.T) (string, string) {
	t.Helper()
	nodeID := "router-fixture-node"
	quote, err := tpm.GetVerifiedQuote(nodeID)
	if err != nil {
		t.Fatalf("generate tpm quote for fixture: %v", err)
	}
	fixturePath := filepath.Join(t.TempDir(), "signed_attestation_quote.json")
	if err := os.WriteFile(fixturePath, quote, 0o600); err != nil {
		t.Fatalf("write fixture path: %v", err)
	}
	return fixturePath, nodeID
}
