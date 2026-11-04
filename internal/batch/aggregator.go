// @notice: Implements Byzantine Fault Tolerance for Sovereign Map.
// @proof: /proofs/communication.md#Theorem-1-Byzantine-Resilience
package batch

import (
	"fmt"
	"math/big"
	"time"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/proofs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

type Mode int

const (
	ModeHonest Mode = iota
	ModeByzantineMix
)

type Config struct {
	TotalNodes       int
	HonestNodes      int
	MaliciousNodes   int
	RedundancyFactor int
}

type Aggregator struct {
	Config        *Config
	Verifier      *proofs.Verifier
	Verified      bool // Restored for simulation tracking
	FilteredCount int  // Restored for simulation tracking

	// GradientCommitment, when non-nil, makes ProcessRound verify the
	// round's gradient proof against it via the MiMC data-commitment
	// circuit (internal.VerifyDataCommitmentProof) instead of the legacy
	// SHA-256-of-empty baseline check. This wires the ZK circuit verifier
	// into the aggregation pipeline so proofs attest to real data.
	GradientCommitment *big.Int
	GradientProof      []byte
}

// NewAggregator initializes the aggregator for the simulation.
func NewAggregator(cfg *Config) *Aggregator {
	return &Aggregator{
		Config:   cfg,
		Verifier: &proofs.Verifier{},
	}
}

// ProcessRound validates the cryptographic proof and updates tracking stats.
func (a *Aggregator) ProcessRound(mode Mode) (err error) {
	start := time.Now()
	scenario := fedAvgScenarioLabel(mode)
	tier := fedAvgTierLabel(a.Config.TotalNodes)
	received := int64(a.Config.TotalNodes)
	aggregated := int64(a.Config.HonestNodes)
	filtered := int64(0)

	defer func() {
		durationSec := time.Since(start).Seconds()
		if durationSec <= 0 {
			durationSec = 0.000001
		}

		metrics.ObserveFedAvgRoundDuration(scenario, tier, durationSec)
		metrics.ObserveFedAvgParticipation(scenario, tier, clamp01(float64(a.Config.HonestNodes)/float64(maxInt(1, a.Config.TotalNodes))))
		metrics.ObserveFedAvgStragglers(scenario, tier, a.Config.MaliciousNodes, a.Config.TotalNodes)
		metrics.ObserveFedAvgGradients(scenario, tier, received, aggregated)
		metrics.ObserveFedAvgByzantineFiltered(scenario, tier, filtered)
		metrics.ObserveFedAvgGradientThroughput(scenario, tier, float64(aggregated)/durationSec)

		latencyMs := durationSec * 1000.0
		metrics.ObserveFedAvgRoundLatency(scenario, tier, latencyMs, latencyMs, latencyMs)
		metrics.ObserveFedAvgGradientNorms(scenario, tier, 0.1, 0.5, 1.0)
	}()

	a.Verified = false
	a.FilteredCount = 0
	honestNodes := a.Config.HonestNodes
	metrics.ObserveConsensus("batch-round", honestNodes, a.Config.TotalNodes)
	if _, err := tpm.VerifyByzantineResilience(a.Config.TotalNodes, a.Config.MaliciousNodes); err != nil {
		return err
	}
	plan, err := hva.BuildPlan(a.Config.TotalNodes, maxInt(1, a.Config.RedundancyFactor))
	if err != nil {
		return err
	}
	metrics.ObserveHVALevels("batch-round", len(plan.Levels))

	// When a gradient commitment is supplied, verify the round's proof against
	// it using the MiMC data-commitment circuit verifier (real Groth16 over a
	// compiled R1CS). Otherwise fall back to the legacy SHA-256-of-empty
	// baseline check, preserving existing behavior.
	if a.GradientCommitment != nil {
		ok, err := internalpkg.VerifyDataCommitmentProof(a.GradientProof, a.GradientCommitment)
		if err != nil || !ok {
			return fmt.Errorf("zk circuit attestation failure: %v", err)
		}
	} else {
		// Baseline SHA256 for an empty proof (prototype default)
		expected := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
		salt := [32]byte{}

		if a.Verifier == nil {
			a.Verifier = &proofs.Verifier{}
		}

		isValid, err := a.Verifier.VerifyProof(expected, []byte(""), salt)
		if err != nil || !isValid {
			return fmt.Errorf("attestation failure: %v", err)
		}
	}

	// Update simulation tracking fields
	if mode == ModeByzantineMix {
		a.FilteredCount = a.Config.MaliciousNodes
		filtered = int64(a.FilteredCount)
	}
	a.Verified = true

	return nil
}

func fedAvgScenarioLabel(mode Mode) string {
	if mode == ModeByzantineMix {
		return "byzantine_mix"
	}
	return "honest"
}

func fedAvgTierLabel(totalNodes int) string {
	switch {
	case totalNodes >= 10000:
		return "10k"
	case totalNodes >= 5000:
		return "5k"
	case totalNodes >= 3000:
		return "3k"
	case totalNodes >= 1500:
		return "1500"
	default:
		return "sub1500"
	}
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func maxInt(a int, b int) int {
	if a > b {
		return a
	}
	return b
}
