package privacy

import "testing"

func TestProperty_AllocateWithinBudget(t *testing.T) {
	o := NewOrchestrator(10, 0.1, 2.0)
	res, err := o.Allocate(AllocationRequest{ShardID: "s", ShardSize: 100, Class: SensitivityPublic})
	if err != nil {
		t.Fatal(err)
	}
	if res.AllocatedEps <= 0 {
		t.Fatalf("non-positive allocation")
	}
	if o.RemainingBudget() < 0 {
		t.Fatal("negative remaining")
	}
}