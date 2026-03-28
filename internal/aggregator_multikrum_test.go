package internal

import "testing"

func TestProcessGradientBatchWithMultiKrum(t *testing.T) {
	agg := NewAggregator(Regional)
	updates := [][]float64{
		{0.10, 0.20, 0.30},
		{0.09, 0.21, 0.31},
		{0.11, 0.19, 0.29},
		{6.0, 6.0, 6.0}, // outlier
		{0.10, 0.20, 0.28},
	}

	result, err := agg.ProcessGradientBatch(updates, len(updates), BatchProcessingOptions{
		ByzantineF: 1,
		MultiKrumM: 3,
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if !result.UsedMultiKrum {
		t.Fatalf("expected multi-krum to be used")
	}
	if result.SelectedCount != 3 {
		t.Fatalf("selected count=%d, want 3", result.SelectedCount)
	}
	if result.MaxGradNorm > 2.0 {
		t.Fatalf("unexpectedly high norm after filtering: %f", result.MaxGradNorm)
	}
}

func TestProcessGradientBatchWithoutMultiKrum(t *testing.T) {
	agg := NewAggregator(Regional)
	updates := [][]float64{
		{0.1, 0.2},
		{0.2, 0.3},
		{0.3, 0.4},
	}

	result, err := agg.ProcessGradientBatch(updates, len(updates), BatchProcessingOptions{})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.UsedMultiKrum {
		t.Fatalf("did not expect multi-krum")
	}
	if result.InputCount != len(updates) {
		t.Fatalf("input count=%d, want %d", result.InputCount, len(updates))
	}
	if result.SelectedCount != len(updates) {
		t.Fatalf("selected count=%d, want %d", result.SelectedCount, len(updates))
	}
}
