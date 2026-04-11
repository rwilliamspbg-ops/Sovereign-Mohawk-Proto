package router

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
	"time"
)

// AttestationVerifier validates that a node quote is authentic and current.
type AttestationVerifier func(nodeID string, quote []byte) error

// ProofVerifier validates integrity proofs attached to insight offers.
type ProofVerifier func(expectedRoot string, proofData []byte, salt [32]byte) (bool, error)

// InsightOffer advertises a high-level model capability without exposing raw data.
type InsightOffer struct {
	OfferID           string    `json:"offer_id"`
	SourceVertical    string    `json:"source_vertical"`
	ModelID           string    `json:"model_id"`
	Summary           string    `json:"summary"`
	ExpectedProofRoot string    `json:"expected_proof_root"`
	ProofPayload      []byte    `json:"proof_payload,omitempty"`
	ProofSalt         [32]byte  `json:"proof_salt,omitempty"`
	PublisherNodeID   string    `json:"publisher_node_id"`
	PublisherQuote    []byte    `json:"publisher_quote"`
	PublishedAt       time.Time `json:"published_at"`
}

// SubscriptionRequest registers a consuming domain for selected source insights.
type SubscriptionRequest struct {
	SubscriberVertical string   `json:"subscriber_vertical"`
	SourceVerticals    []string `json:"source_verticals"`
	SubscriberNodeID   string   `json:"subscriber_node_id"`
	SubscriberQuote    []byte   `json:"subscriber_quote"`
}

// Router coordinates cross-vertical capability routing.
type Router struct {
	policy      *PolicyEngine
	ledger      *ProvenanceLedger
	verifyQuote AttestationVerifier
	verifyProof ProofVerifier

	mu            sync.RWMutex
	offers        map[string]InsightOffer
	subscriptions map[string]map[string]struct{}
}

// New creates a cross-vertical federated router.
func New(policy *PolicyEngine, quoteVerifier AttestationVerifier, proofVerifier ProofVerifier) *Router {
	return NewWithLedger(policy, quoteVerifier, proofVerifier, NewProvenanceLedger())
}

// NewWithLedger creates a router with a caller-provided provenance ledger.
func NewWithLedger(policy *PolicyEngine, quoteVerifier AttestationVerifier, proofVerifier ProofVerifier, ledger *ProvenanceLedger) *Router {
	if policy == nil {
		policy = NewPolicyEngine()
	}
	if quoteVerifier == nil {
		quoteVerifier = func(_ string, _ []byte) error { return nil }
	}
	if proofVerifier == nil {
		proofVerifier = func(_ string, _ []byte, _ [32]byte) (bool, error) { return true, nil }
	}
	if ledger == nil {
		ledger = NewProvenanceLedger()
	}
	return &Router{
		policy:        policy,
		ledger:        ledger,
		verifyQuote:   quoteVerifier,
		verifyProof:   proofVerifier,
		offers:        map[string]InsightOffer{},
		subscriptions: map[string]map[string]struct{}{},
	}
}

// PublishInsight verifies trust controls before an offer is discoverable.
func (r *Router) PublishInsight(offer InsightOffer) (InsightOffer, error) {
	offer.OfferID = strings.TrimSpace(offer.OfferID)
	offer.SourceVertical = normalizeVertical(offer.SourceVertical)
	offer.ModelID = strings.TrimSpace(offer.ModelID)
	offer.PublisherNodeID = strings.TrimSpace(offer.PublisherNodeID)
	if offer.PublishedAt.IsZero() {
		offer.PublishedAt = time.Now().UTC()
	}
	if offer.OfferID == "" {
		offer.OfferID = deriveOfferID(offer.SourceVertical, offer.ModelID, offer.PublishedAt)
	}
	if offer.SourceVertical == "" || offer.ModelID == "" || offer.PublisherNodeID == "" {
		return InsightOffer{}, fmt.Errorf("source_vertical, model_id, and publisher_node_id are required")
	}
	if err := r.verifyQuote(offer.PublisherNodeID, offer.PublisherQuote); err != nil {
		return InsightOffer{}, fmt.Errorf("publisher attestation failed: %w", err)
	}
	if strings.TrimSpace(offer.ExpectedProofRoot) != "" {
		ok, err := r.verifyProof(strings.TrimSpace(offer.ExpectedProofRoot), offer.ProofPayload, offer.ProofSalt)
		if err != nil {
			return InsightOffer{}, fmt.Errorf("proof verification failed: %w", err)
		}
		if !ok {
			return InsightOffer{}, fmt.Errorf("proof verification failed")
		}
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.offers[offer.OfferID] = offer
	return offer, nil
}

// RegisterSubscription records a consumer and allowed source verticals.
func (r *Router) RegisterSubscription(req SubscriptionRequest) error {
	req.SubscriberVertical = normalizeVertical(req.SubscriberVertical)
	req.SubscriberNodeID = strings.TrimSpace(req.SubscriberNodeID)
	if req.SubscriberVertical == "" || req.SubscriberNodeID == "" {
		return fmt.Errorf("subscriber_vertical and subscriber_node_id are required")
	}
	if err := r.verifyQuote(req.SubscriberNodeID, req.SubscriberQuote); err != nil {
		return fmt.Errorf("subscriber attestation failed: %w", err)
	}

	allowedSources := map[string]struct{}{}
	for _, source := range req.SourceVerticals {
		s := normalizeVertical(source)
		if s != "" {
			if err := r.policy.AllowRoute(s, req.SubscriberVertical); err != nil {
				return err
			}
			allowedSources[s] = struct{}{}
		}
	}
	if len(allowedSources) == 0 {
		return fmt.Errorf("at least one source vertical is required")
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.subscriptions[req.SubscriberVertical] = allowedSources
	return nil
}

// Discover returns offers visible to a subscriber vertical under active policies.
func (r *Router) Discover(subscriberVertical string) ([]InsightOffer, error) {
	subscriberVertical = normalizeVertical(subscriberVertical)
	if subscriberVertical == "" {
		return nil, fmt.Errorf("subscriber_vertical is required")
	}

	r.mu.RLock()
	subscribedSources := r.subscriptions[subscriberVertical]
	if len(subscribedSources) == 0 {
		r.mu.RUnlock()
		return nil, nil
	}
	out := make([]InsightOffer, 0, len(r.offers))
	for _, offer := range r.offers {
		if _, ok := subscribedSources[offer.SourceVertical]; !ok {
			continue
		}
		if err := r.policy.AllowRoute(offer.SourceVertical, subscriberVertical); err != nil {
			continue
		}
		out = append(out, offer)
	}
	r.mu.RUnlock()
	return out, nil
}

// RecordTransfer appends a provenance record for an observed cross-domain impact.
func (r *Router) RecordTransfer(event ProvenanceEvent) (ProvenanceRecord, error) {
	return r.ledger.Append(event)
}

// Provenance returns immutable chain records in append order.
func (r *Router) Provenance() []ProvenanceRecord {
	return r.ledger.Records()
}

func normalizeVertical(v string) string {
	return strings.ToLower(strings.TrimSpace(v))
}

func deriveOfferID(sourceVertical string, modelID string, ts time.Time) string {
	h := sha256.Sum256([]byte(sourceVertical + ":" + modelID + ":" + ts.UTC().Format(time.RFC3339Nano)))
	return hex.EncodeToString(h[:16])
}
