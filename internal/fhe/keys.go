package fhe

import (
	"fmt"
	"sort"
	"strings"
)

type KeyShare struct {
	NodeID string
	Weight int
}

func ValidateShares(shares []KeyShare, threshold int) error {
	if threshold <= 0 {
		return fmt.Errorf("threshold must be positive")
	}
	if len(shares) == 0 {
		return fmt.Errorf("at least one share is required")
	}
	seen := map[string]struct{}{}
	for _, s := range shares {
		node := strings.TrimSpace(s.NodeID)
		if node == "" {
			return fmt.Errorf("share node_id is required")
		}
		if s.Weight <= 0 {
			return fmt.Errorf("share weight must be positive")
		}
		if _, ok := seen[node]; ok {
			return fmt.Errorf("duplicate share for node %q", node)
		}
		seen[node] = struct{}{}
	}
	return nil
}

func HasQuorum(participants []string, shareSet map[string]KeyShare, threshold int) bool {
	if threshold <= 0 {
		return false
	}
	total := 0
	for _, p := range participants {
		node := strings.TrimSpace(p)
		if node == "" {
			continue
		}
		share, ok := shareSet[node]
		if !ok || share.Weight <= 0 {
			continue
		}
		total += share.Weight
		if total >= threshold {
			return true
		}
	}
	return false
}

func ShareMap(shares []KeyShare) map[string]KeyShare {
	out := make(map[string]KeyShare, len(shares))
	for _, s := range shares {
		out[strings.TrimSpace(s.NodeID)] = s
	}
	return out
}

func SortedParticipants(participants []string) []string {
	out := make([]string, 0, len(participants))
	for _, p := range participants {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	sort.Strings(out)
	return out
}
