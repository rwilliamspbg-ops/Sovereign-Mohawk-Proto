package hbft

import (
	"fmt"
	"math"
)

// ChernoffFailureBound computes the hierarchical Chernoff tail bound used
// by proofs/LeanFormalization/Theorem1BFT.lean's chernoff_hierarchical_bound:
//
//   per-committee:  chernoffBoundZ(c, k, p, z) = (1 - p + p*z)^c / z^k
//   hierarchical:   T * per-committee   (union bound over T committees)
//
// where:
//   T = committees (tiers collapsed to a flat committee count for the bound)
//   c = nodes per committee
//   k = majority-breaking threshold (Byzantine count that breaks a committee)
//   p = Byzantine rate
//   z = Chernoff base (>= 1, typically 2)
//
// This mirrors the deployment-scale proof
// chernoff_hierarchical_bound_deployment_scale (T=200, c=50000, k=25000,
// p=0.1, z=2) which proves the bound <= 200/10^1000. It is provided so
// the runtime can fail-closed when a topology's parameters do not satisfy
// the proven bound, rather than relying on the Lean proof alone.
func ChernoffFailureBound(T, c, k int, p, z float64) (float64, error) {
	if T <= 0 || c <= 0 || k <= 0 {
		return 0, fmt.Errorf("chernoff: T, c, k must be positive")
	}
	if p < 0 || p >= 1 {
		return 0, fmt.Errorf("chernoff: p must be in [0,1)")
	}
	if z < 1 {
		return 0, fmt.Errorf("chernoff: z must be >= 1")
	}
	perCommitteeLog := float64(c)*math.Log(1-p+p*z) - float64(k)*math.Log(z)
	boundLog := math.Log(float64(T)) + perCommitteeLog
	bound := math.Exp(boundLog)
	if math.IsNaN(bound) || math.IsInf(bound, 0) {
		return math.Inf(1), nil
	}
	if bound > 1 {
		bound = 1
	}
	return bound, nil
}

// ValidateChernoffBound fails closed when the hierarchical Chernoff bound
// for the simulator's topology exceeds threshold. A threshold of 1.0 means
// "any non-vacuous bound passes"; stricter thresholds (e.g. 0.01) enforce
// the proven deployment-scale guarantee.
func (s *Simulator) ValidateChernoffBound(threshold float64) error {
	T := s.cfg.Topology.Tiers * s.cfg.Topology.CommitteesPerTier
	c := s.cfg.Topology.NodesPerCommittee
	// Majority-breaking threshold: a committee breaks when Byzantine count
	// reaches ceil(c/2). Use c/2 (conservative) to match the Lean model's
	// k = majority threshold.
	k := c / 2
	if k < 1 {
		k = 1
	}
	bound, err := ChernoffFailureBound(T, c, k, s.cfg.ByzantineRate, 2.0)
	if err != nil {
		return err
	}
	if bound > threshold {
		return fmt.Errorf("hbft: Chernoff hierarchical bound %g exceeds threshold %g (T=%d c=%d k=%d p=%g)",
			bound, threshold, T, c, k, s.cfg.ByzantineRate)
	}
	return nil
}
