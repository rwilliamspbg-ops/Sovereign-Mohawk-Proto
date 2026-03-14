package hva

import (
	"fmt"
	"math"
)

const (
	HonestNumerator   = 5
	HonestDenominator = 9
)

type Level struct {
	Depth     int    `json:"depth"`
	Name      string `json:"name"`
	NodeCount int    `json:"node_count"`
}

type Plan struct {
	Dimensions   int     `json:"dimensions"`
	TotalNodes   int     `json:"total_nodes"`
	BranchFactor int     `json:"branch_factor"`
	Levels       []Level `json:"levels"`
	EdgeCount    int     `json:"edge_count"`
	Bound        int     `json:"bound"`
}

func BuildPlan(totalNodes int, dimensions int) (Plan, error) {
	if totalNodes < 1 {
		return Plan{}, fmt.Errorf("total nodes must be positive")
	}
	if dimensions < 1 {
		return Plan{}, fmt.Errorf("dimensions must be positive")
	}

	branchFactor := recommendedBranchFactor(totalNodes)
	levels := make([]Level, 0, 4)
	current := totalNodes
	edgeCount := 0
	depth := 0

	for {
		levels = append(levels, Level{
			Depth:     depth,
			Name:      tierName(depth, current),
			NodeCount: current,
		})
		if current == 1 {
			break
		}

		next := int(math.Ceil(float64(current) / float64(branchFactor)))
		edgeCount += current
		current = maxInt(1, next)
		depth++
	}

	bound := dimensions * len(levels)
	plan := Plan{
		Dimensions:   dimensions,
		TotalNodes:   totalNodes,
		BranchFactor: branchFactor,
		Levels:       levels,
		EdgeCount:    edgeCount,
		Bound:        bound,
	}

	if err := plan.Validate(); err != nil {
		return Plan{}, err
	}
	return plan, nil
}

func (p Plan) Validate() error {
	if p.TotalNodes < 1 || p.Dimensions < 1 {
		return fmt.Errorf("invalid plan dimensions")
	}
	if len(p.Levels) == 0 {
		return fmt.Errorf("plan must contain at least one level")
	}
	if p.EdgeCount > p.TotalNodes*len(p.Levels) {
		return fmt.Errorf("hierarchical mesh exceeds O(d log n) edge budget")
	}
	if p.Bound > p.Dimensions*(int(math.Ceil(math.Log2(float64(p.TotalNodes))))+1) {
		return fmt.Errorf("hierarchical mesh exceeds O(d log n) complexity bound")
	}
	return nil
}

func MinimumHonestNodes(totalNodes int) int {
	if totalNodes <= 0 {
		return 0
	}
	return (HonestNumerator*totalNodes + HonestDenominator - 1) / HonestDenominator
}

func MaximumByzantineNodes(totalNodes int) int {
	if totalNodes <= 0 {
		return 0
	}
	return totalNodes - MinimumHonestNodes(totalNodes)
}

func recommendedBranchFactor(totalNodes int) int {
	if totalNodes <= 4 {
		return 2
	}
	return maxInt(2, int(math.Ceil(math.Log2(float64(totalNodes)))))
}

func tierName(depth int, nodes int) string {
	switch {
	case depth == 0:
		return "edge"
	case nodes == 1:
		return "global"
	case nodes <= 100:
		return "continental"
	default:
		return "regional"
	}
}

func maxInt(a int, b int) int {
	if a > b {
		return a
	}
	return b
}
