package internal

import "testing"

func TestMultiKrumSelect(t *testing.T) {
	updates := [][]float64{
		{0.10, 0.20, 0.30},
		{0.11, 0.19, 0.29},
		{0.09, 0.21, 0.31},
		{5.00, 5.00, 5.00}, // outlier
		{0.10, 0.20, 0.28},
	}

	selected, scores, err := MultiKrumSelect(updates, 1, 2)
	if err != nil {
		t.Fatalf("MultiKrumSelect failed: %v", err)
	}
	if len(scores) != len(updates) {
		t.Fatalf("scores length=%d, want %d", len(scores), len(updates))
	}
	if len(selected) != 2 {
		t.Fatalf("selected length=%d, want 2", len(selected))
	}
	for _, idx := range selected {
		if idx < 0 || idx >= len(updates) {
			t.Fatalf("selected index out of range: %d", idx)
		}
		if idx == 3 {
			t.Fatalf("outlier index selected by multi-krum")
		}
	}
}

func TestMultiKrumAggregate(t *testing.T) {
	updates := [][]float64{
		{1.0, 1.0},
		{1.1, 0.9},
		{0.9, 1.1},
		{10.0, 10.0}, // outlier
		{1.0, 1.05},
	}
	mean, selected, _, err := MultiKrumAggregate(updates, 1, 3)
	if err != nil {
		t.Fatalf("MultiKrumAggregate failed: %v", err)
	}
	if len(mean) != 2 {
		t.Fatalf("mean length=%d, want 2", len(mean))
	}
	if len(selected) != 3 {
		t.Fatalf("selected length=%d, want 3", len(selected))
	}
	if mean[0] > 2.0 || mean[1] > 2.0 {
		t.Fatalf("mean looks contaminated by outlier: %v", mean)
	}
}
