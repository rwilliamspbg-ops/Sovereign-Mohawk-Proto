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
		_, _ = alloc.Allocate(task, bids)
	})
}
