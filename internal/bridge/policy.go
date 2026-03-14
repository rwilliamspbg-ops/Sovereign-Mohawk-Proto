package bridge

import (
	"fmt"
	"strings"
)

// RoutePolicy constrains transfer acceptance for a specific source→target route.
type RoutePolicy struct {
	ID                string   `json:"id"`
	AllowedAssets     []string `json:"allowed_assets,omitempty"`
	MinAmount         float64  `json:"min_amount,omitempty"`
	MaxAmount         float64  `json:"max_amount,omitempty"`
	MinFinalityBlocks uint64   `json:"min_finality_blocks,omitempty"`
}

func routeKey(sourceChain, targetChain string) string {
	return normalizeChain(sourceChain) + "->" + normalizeChain(targetChain)
}

func (e *Engine) RegisterRoutePolicy(sourceChain, targetChain string, policy RoutePolicy) {
	if e.policies == nil {
		e.policies = map[string]RoutePolicy{}
	}
	e.policies[routeKey(sourceChain, targetChain)] = policy
}

func (e *Engine) resolveRoutePolicy(sourceChain, targetChain string) (RoutePolicy, bool) {
	if e.policies == nil {
		return RoutePolicy{}, false
	}
	policy, ok := e.policies[routeKey(sourceChain, targetChain)]
	return policy, ok
}

func applyRoutePolicy(req TransferRequest, policy RoutePolicy) error {
	if len(policy.AllowedAssets) > 0 {
		allowed := false
		for _, asset := range policy.AllowedAssets {
			if strings.EqualFold(strings.TrimSpace(asset), strings.TrimSpace(req.Asset)) {
				allowed = true
				break
			}
		}
		if !allowed {
			return fmt.Errorf("asset %q not allowed by route policy %q", req.Asset, policy.ID)
		}
	}
	if policy.MinAmount > 0 && req.Amount < policy.MinAmount {
		return fmt.Errorf("amount %.8f below minimum %.8f for policy %q", req.Amount, policy.MinAmount, policy.ID)
	}
	if policy.MaxAmount > 0 && req.Amount > policy.MaxAmount {
		return fmt.Errorf("amount %.8f above maximum %.8f for policy %q", req.Amount, policy.MaxAmount, policy.ID)
	}
	if policy.MinFinalityBlocks > 0 && req.FinalityDepth < policy.MinFinalityBlocks {
		return fmt.Errorf("finality_depth %d below required %d for policy %q", req.FinalityDepth, policy.MinFinalityBlocks, policy.ID)
	}
	return nil
}
