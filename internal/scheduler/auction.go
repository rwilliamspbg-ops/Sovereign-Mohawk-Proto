package scheduler

import (
	"fmt"
	"math"
	"sort"
	"strings"
)

type Bid struct {
	NodeID         string
	PricePerUnit   float64
	AvailableUnits float64
	Profile        ResourceProfile
}

type Allocation struct {
	TaskID         string
	WinnerNodeID   string
	ClearingPrice  float64
	AllocatedUnits float64
	UtilityScore   float64
}

type AuctionAllocator struct {
	MinTrustScore float64
}

func NewAuctionAllocator(minTrust float64) *AuctionAllocator {
	if minTrust <= 0 {
		minTrust = 0.5
	}
	if minTrust > 1 {
		minTrust = 1
	}
	return &AuctionAllocator{MinTrustScore: minTrust}
}

func (a *AuctionAllocator) Allocate(task TaskSpec, bids []Bid) (Allocation, error) {
	if strings.TrimSpace(task.TaskID) == "" {
		return Allocation{}, fmt.Errorf("task_id is required")
	}
	if task.ComplexityUnits <= 0 {
		return Allocation{}, fmt.Errorf("complexity_units must be positive")
	}
	filtered := make([]Bid, 0, len(bids))
	for _, bid := range bids {
		if strings.TrimSpace(bid.NodeID) == "" || bid.PricePerUnit <= 0 || bid.AvailableUnits < task.ComplexityUnits {
			continue
		}
		if bid.Profile.TrustScore < a.MinTrustScore {
			continue
		}
		capacity := bid.Profile.CapacityScore(task)
		if capacity <= 0 {
			continue
		}
		filtered = append(filtered, bid)
	}
	if len(filtered) == 0 {
		return Allocation{}, fmt.Errorf("no eligible bids")
	}

	sort.Slice(filtered, func(i, j int) bool {
		scoreI := filtered[i].PricePerUnit / math.Max(filtered[i].Profile.CapacityScore(task), 1e-9)
		scoreJ := filtered[j].PricePerUnit / math.Max(filtered[j].Profile.CapacityScore(task), 1e-9)
		if scoreI == scoreJ {
			return filtered[i].NodeID < filtered[j].NodeID
		}
		return scoreI < scoreJ
	})

	winner := filtered[0]
	return Allocation{
		TaskID:         task.TaskID,
		WinnerNodeID:   winner.NodeID,
		ClearingPrice:  winner.PricePerUnit,
		AllocatedUnits: task.ComplexityUnits,
		UtilityScore:   winner.Profile.CapacityScore(task) / winner.PricePerUnit,
	}, nil
}
