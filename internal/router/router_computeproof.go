package router

import "fmt"

// PublishInsightWithComputeProof validates a proof-of-compute before publishing.
func (r *Router) PublishInsightWithComputeProof(
	offer InsightOffer,
	tracePayload []byte,
	computeProof []byte,
	verifyCompute func(tracePayload []byte, proofPayload []byte) (bool, error),
) (InsightOffer, error) {
	if verifyCompute == nil {
		return InsightOffer{}, fmt.Errorf("compute proof verifier is required")
	}
	ok, err := verifyCompute(tracePayload, computeProof)
	if err != nil {
		return InsightOffer{}, fmt.Errorf("compute proof validation failed: %w", err)
	}
	if !ok {
		return InsightOffer{}, fmt.Errorf("compute proof validation failed")
	}
	return r.PublishInsight(offer)
}
