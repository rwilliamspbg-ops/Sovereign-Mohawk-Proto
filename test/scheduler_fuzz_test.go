package test

import (
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
