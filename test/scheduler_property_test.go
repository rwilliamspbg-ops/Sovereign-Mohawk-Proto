package test

import (
	"testing"

	"github.com/leanovate/gopter"
	"github.com/leanovate/gopter/gen"
	"github.com/leanovate/gopter/prop"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/scheduler"
)

func TestSchedulerAllocateProperty(t *testing.T) {
	parameters := gopter.DefaultTestParameters()
	parameters.MinSuccessfulTests = 200
	properties := gopter.NewProperties(parameters)

	properties.Property("allocated units <= available units", prop.ForAll(
		func(units float64) bool {
			alloc := scheduler.NewAuctionAllocator(0.5)
			task := scheduler.TaskSpec{TaskID: "t", ComplexityUnits: 1, RequiredMemoryGB: 1, RequiresNPU: false}
			bids := []scheduler.Bid{{NodeID: "n", PricePerUnit: 1, AvailableUnits: units}}
			res, err := alloc.Allocate(task, bids)
			if err != nil {
				return true
			}
			return res.AllocatedUnits <= units+1e-9
		},
		gen.Float64Range(0, 100),
	))

	properties.TestingRun(t)
}
