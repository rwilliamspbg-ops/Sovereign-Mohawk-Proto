package main

import "testing"

func poisonedBatch() [][]float64 {
	batch := make([][]float64, 0, 6)
	for n := 0; n < 5; n++ {
		v := make([]float64, 128)
		for i := range v {
			v[i] = float64((i+n)%7-3) / 10.0
		}
		batch = append(batch, v)
	}
	poison := make([]float64, 128)
	poison[0] = 1000000.0
	batch = append(batch, poison)
	return batch
}

func TestProcessLiveMultiKrumFiltersPoison(t *testing.T) {
	selected, filtered, err := processLiveMultiKrum(poisonedBatch(), 1, 0)
	if err != nil {
		t.Fatalf("Multi-Krum failed: %v", err)
	}
	if filtered < 1 {
		t.Fatalf("filtered = %d, want at least 1", filtered)
	}
	if selected != 6-filtered {
		t.Fatalf("selected=%d filtered=%d, inconsistent", selected, filtered)
	}
}

func TestProcessLiveMultiKrumRequiresEnoughUpdates(t *testing.T) {
	if _, _, err := processLiveMultiKrum(poisonedBatch()[:2], 1, 0); err == nil {
		t.Fatal("expected precondition error for n=2 f=1")
	}
}

func TestProcessLiveMultiKrumIndicesIdentifiesPoison(t *testing.T) {
	batch := poisonedBatch()
	indices, err := processLiveMultiKrumIndices(batch, 1, 0)
	if err != nil {
		t.Fatalf("Multi-Krum failed: %v", err)
	}
	for _, idx := range indices {
		if idx == len(batch)-1 {
			t.Fatal("poisoned gradient was selected by Multi-Krum")
		}
	}
}

func TestProcessLiveMultiKrumM5FiltersOnlyPoison(t *testing.T) {
	batch := poisonedBatch()
	indices, err := processLiveMultiKrumIndices(batch, 1, 5)
	if err != nil {
		t.Fatalf("Multi-Krum failed: %v", err)
	}
	if len(indices) != 5 {
		t.Fatalf("selected = %d, want 5", len(indices))
	}
	for _, idx := range indices {
		if idx == len(batch)-1 {
			t.Fatal("poisoned gradient was selected with m=5")
		}
	}
}
