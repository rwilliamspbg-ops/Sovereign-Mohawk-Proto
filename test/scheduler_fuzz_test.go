package test

import (
	"math"
	"strings"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/scheduler"
)

func FuzzSchedulerAllocate(f *testing.F) {
	f.Add("task-1", 10.0, 4.0, false, "node-a", 1.0, 5.0)
	f.Fuzz(func(t *testing.T, taskID string, complexity, mem float64, npu bool, nodeID string, price, units float64) {
		alloc := scheduler.NewAuctionAllocator(0.5)
		task := scheduler.TaskSpec{TaskID: taskID, ComplexityUnits: complexity, RequiredMemoryGB: mem, RequiresNPU: npu}
		bids := []scheduler.Bid{{NodeID: nodeID, PricePerUnit: price, AvailableUnits: units}}
		res, err := alloc.Allocate(task, bids)
		if err != nil {
			return
		}
		if res.AllocatedUnits > units+1e-9 {
			t.Fatalf("allocated %v > available %v", res.AllocatedUnits, units)
		}
		if res.WinnerNodeID != "" && res.WinnerNodeID != nodeID {
			t.Fatalf("unexpected winner: %s", res.WinnerNodeID)
		}
	})
}

// FuzzSchedulerAllocateSemantic asserts the auction contract: the winner is
// eligible, allocated units equal the task size, and no eligible bid has a
// better price/capacity score than the winner.
func FuzzSchedulerAllocateSemantic(f *testing.F) {
	f.Add("task-1", 10.0, 4.0, false, "node-a", 1.0, 5.0, "node-b", 2.0, 5.0)
	f.Add("task-1", 10.0, 4.0, false, "node-a", 1.0, 5.0, "node-b", 1.0, 5.0)
	f.Fuzz(func(t *testing.T, taskID string, complexity, mem float64, npu bool,
		nodeA string, priceA, unitsA float64,
		nodeB string, priceB, unitsB float64) {
		if nodeA == nodeB {
			nodeB = nodeB + "-b"
		}
		alloc := scheduler.NewAuctionAllocator(0.5)
		task := scheduler.TaskSpec{TaskID: taskID, ComplexityUnits: complexity, RequiredMemoryGB: mem, RequiresNPU: npu}
		profile := scheduler.ResourceProfile{CPUCores: 4, MemoryGB: 8, TrustScore: 0.9, FreshnessMins: 10}
		bids := []scheduler.Bid{
			{NodeID: nodeA, PricePerUnit: priceA, AvailableUnits: unitsA, Profile: profile},
			{NodeID: nodeB, PricePerUnit: priceB, AvailableUnits: unitsB, Profile: profile},
		}
		if strings.TrimSpace(taskID) == "" || complexity <= 0 {
			if _, err := alloc.Allocate(task, bids); err == nil {
				t.Fatal("expected error for empty task ID or non-positive complexity")
			}
			return
		}
		eligible := 0
		minScore := math.Inf(1)
		for _, b := range bids {
			if strings.TrimSpace(b.NodeID) == "" || b.PricePerUnit <= 0 || b.AvailableUnits < task.ComplexityUnits {
				continue
			}
			if b.Profile.TrustScore < 0.5 {
				continue
			}
			capacity := b.Profile.CapacityScore(task)
			if capacity <= 0 {
				continue
			}
			eligible++
			score := b.PricePerUnit / math.Max(capacity, 1e-9)
			if score < minScore {
				minScore = score
			}
		}
		res, err := alloc.Allocate(task, bids)
		if eligible == 0 {
			if err == nil {
				t.Fatal("expected error when no bids are eligible")
			}
			return
		}
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if res.AllocatedUnits != task.ComplexityUnits {
			t.Fatalf("allocated %v != complexity %v", res.AllocatedUnits, task.ComplexityUnits)
		}
		var winner *scheduler.Bid
		for i := range bids {
			if bids[i].NodeID == res.WinnerNodeID {
				winner = &bids[i]
			}
		}
		if winner == nil {
			t.Fatalf("winner %q not among bids", res.WinnerNodeID)
		}
		capacity := winner.Profile.CapacityScore(task)
		if winner.PricePerUnit <= 0 || winner.AvailableUnits < task.ComplexityUnits || winner.Profile.TrustScore < 0.5 || capacity <= 0 {
			t.Fatalf("winner is not eligible: %+v", *winner)
		}
		winnerScore := winner.PricePerUnit / math.Max(capacity, 1e-9)
		if winnerScore > minScore+1e-9 {
			t.Fatalf("winner score %v exceeds best eligible %v", winnerScore, minScore)
		}
	})
}
