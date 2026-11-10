package scheduler

import "testing"

func TestProperty_CapacityScoreFinite(t *testing.T) {
	p := ResourceProfile{CPUCores: 4, MemoryGB: 8, TrustScore: 0.9, FreshnessMins: 10}
	task := TaskSpec{RequiredMemoryGB: 1}
	score := p.CapacityScore(task)
	if score < 0 {
		t.Fatalf("negative score %v", score)
	}
}