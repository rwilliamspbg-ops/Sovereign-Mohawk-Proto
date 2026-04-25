package privacy

import (
	"fmt"
	"math"
	"strings"
	"sync"
)

type SensitivityClass string

const (
	SensitivityHealthcare SensitivityClass = "healthcare"
	SensitivityFinance    SensitivityClass = "finance"
	SensitivityCritical   SensitivityClass = "critical"
	SensitivityPublic     SensitivityClass = "public"
)

type AllocationRequest struct {
	ShardID           string
	Class             SensitivityClass
	ShardSize         int
	DriftScore        float64
	MinFloor          float64
	MaxCeiling        float64
	RoundContribution float64
}

type AllocationResult struct {
	ShardID         string
	AllocatedEps    float64
	RemainingBudget float64
}

// Orchestrator implements dynamic adaptive DP allocation with global budget guards.
type Orchestrator struct {
	mu          sync.Mutex
	totalBudget float64
	consumed    float64
	defaultMin  float64
	defaultMax  float64
}

func NewOrchestrator(totalBudget float64, minEps float64, maxEps float64) *Orchestrator {
	if totalBudget <= 0 {
		totalBudget = 2.0
	}
	if minEps <= 0 {
		minEps = 0.2
	}
	if maxEps <= 0 {
		maxEps = 2.0
	}
	if minEps > maxEps {
		minEps, maxEps = maxEps, minEps
	}
	return &Orchestrator{totalBudget: totalBudget, defaultMin: minEps, defaultMax: maxEps}
}

func (o *Orchestrator) RemainingBudget() float64 {
	o.mu.Lock()
	defer o.mu.Unlock()
	return math.Max(0, o.totalBudget-o.consumed)
}

func (o *Orchestrator) Allocate(req AllocationRequest) (AllocationResult, error) {
	req.ShardID = strings.TrimSpace(req.ShardID)
	if req.ShardID == "" {
		return AllocationResult{}, fmt.Errorf("shard_id is required")
	}
	if req.ShardSize <= 0 {
		return AllocationResult{}, fmt.Errorf("shard_size must be positive")
	}

	minEps := o.defaultMin
	maxEps := o.defaultMax
	if req.MinFloor > 0 {
		minEps = req.MinFloor
	}
	if req.MaxCeiling > 0 {
		maxEps = req.MaxCeiling
	}
	if minEps > maxEps {
		minEps, maxEps = maxEps, minEps
	}

	base := baseBySensitivity(req.Class)
	drift := clamp(req.DriftScore, 0, 1)
	sizeFactor := clamp(math.Log10(float64(req.ShardSize)+1)/6.0, 0.15, 1.0)
	requested := base*(0.7+0.6*drift)*sizeFactor + req.RoundContribution
	requested = clamp(requested, minEps, maxEps)

	o.mu.Lock()
	defer o.mu.Unlock()
	if o.consumed+requested > o.totalBudget {
		return AllocationResult{}, fmt.Errorf("global epsilon budget exhausted: consumed=%.6f requested=%.6f total=%.6f", o.consumed, requested, o.totalBudget)
	}
	o.consumed += requested
	return AllocationResult{ShardID: req.ShardID, AllocatedEps: requested, RemainingBudget: math.Max(0, o.totalBudget-o.consumed)}, nil
}

func baseBySensitivity(class SensitivityClass) float64 {
	switch strings.ToLower(strings.TrimSpace(string(class))) {
	case string(SensitivityHealthcare), string(SensitivityCritical):
		return 0.25
	case string(SensitivityFinance):
		return 0.4
	case string(SensitivityPublic):
		return 0.9
	default:
		return 0.5
	}
}

func clamp(v, minV, maxV float64) float64 {
	if v < minV {
		return minV
	}
	if v > maxV {
		return maxV
	}
	return v
}
