package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/scheduler"
)

func TestAuctionAllocatorSelectsBestPricePerformance(t *testing.T) {
	allocator := scheduler.NewAuctionAllocator(0.5)
	task := scheduler.TaskSpec{TaskID: "task-1", ComplexityUnits: 5, RequiredMemoryGB: 2, RequiresNPU: true}
	bids := []scheduler.Bid{
		{
			NodeID:         "slow-cheap",
			PricePerUnit:   0.5,
			AvailableUnits: 6,
			Profile:        scheduler.ResourceProfile{NodeID: "slow-cheap", NPUTOPS: 1, CPUCores: 8, MemoryGB: 8, TrustScore: 0.8},
		},
		{
			NodeID:         "fast-fair",
			PricePerUnit:   0.9,
			AvailableUnits: 6,
			Profile:        scheduler.ResourceProfile{NodeID: "fast-fair", NPUTOPS: 20, CPUCores: 16, MemoryGB: 16, TrustScore: 0.9},
		},
	}
	alloc, err := allocator.Allocate(task, bids)
	if err != nil {
		t.Fatalf("allocate: %v", err)
	}
	if alloc.WinnerNodeID != "fast-fair" {
		t.Fatalf("expected fast-fair winner, got %q", alloc.WinnerNodeID)
	}
	if alloc.AllocatedUnits != 5 {
		t.Fatalf("unexpected allocated units: %.2f", alloc.AllocatedUnits)
	}
}

func TestAuctionAllocatorRejectsLowTrust(t *testing.T) {
	allocator := scheduler.NewAuctionAllocator(0.7)
	_, err := allocator.Allocate(
		scheduler.TaskSpec{TaskID: "task-2", ComplexityUnits: 1, RequiredMemoryGB: 1},
		[]scheduler.Bid{{
			NodeID:         "untrusted",
			PricePerUnit:   1,
			AvailableUnits: 5,
			Profile:        scheduler.ResourceProfile{NodeID: "untrusted", CPUCores: 8, MemoryGB: 4, TrustScore: 0.4},
		}},
	)
	if err == nil {
		t.Fatal("expected low-trust bid to be rejected")
	}
}
