package internal

import "testing"

func TestProcessGradientBatchWithMultiKrum(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
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
	t.Setenv("MOHAWK_DP_SIGMA", "5")
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

func TestProcessGradientBatchWithWeightedTrimAndHierarchy(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := [][]float64{
		{0.10, 0.20, 0.30},
		{0.12, 0.19, 0.29},
		{0.09, 0.22, 0.28},
		{4.9, 4.8, 5.1}, // outlier
		{0.11, 0.21, 0.31},
		{5.2, 5.1, 5.0}, // outlier
	}

	result, err := agg.ProcessGradientBatch(updates, 120, BatchProcessingOptions{
		WeightedTrimFraction:  0.34,
		HierarchicalGroupSize: 2,
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.SelectedCount >= len(updates) {
		t.Fatalf("expected reduced selected count, got %d from %d", result.SelectedCount, len(updates))
	}
	if result.MaxGradNorm > 2.0 {
		t.Fatalf("unexpectedly high norm after weighted trim/hierarchy: %f", result.MaxGradNorm)
	}
}

func TestProcessGradientBatchWithSemiAsyncQuorum(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := make([][]float64, 0, 200)
	for i := 0; i < 200; i++ {
		updates = append(updates, []float64{0.1, 0.2, 0.3})
	}

	result, err := agg.ProcessGradientBatch(updates, 1000, BatchProcessingOptions{
		SemiAsyncQuorum: 0.2,
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.SelectedCount != len(updates) {
		t.Fatalf("selected count=%d, want %d", result.SelectedCount, len(updates))
	}
}

func TestProcessGradientBatchWithStalenessWeighting(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := [][]float64{
		{1.0, 1.0, 1.0},
		{1.0, 1.0, 1.0},
	}

	result, err := agg.ProcessGradientBatch(updates, 120, BatchProcessingOptions{
		StalenessHalfLifeSec: 10,
		UpdateAgesSec:        []float64{0, 30},
		UpdateWeights:        []float64{1.0, 1.0},
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.MaxGradNorm <= 0 {
		t.Fatalf("expected positive grad norm")
	}
}

func TestProcessGradientBatchWithUtilitySelectionAndBufferedWindow(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := [][]float64{
		{0.1, 0.1},
		{0.2, 0.2},
		{0.3, 0.3},
		{0.4, 0.4},
		{0.5, 0.5},
	}

	result, err := agg.ProcessGradientBatch(updates, 200, BatchProcessingOptions{
		UtilityTopFraction:  0.8,
		BufferedWindowSize:  2,
		UpdateUtilityScores: []float64{1, 2, 3, 4, 5},
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.SelectedCount != 2 {
		t.Fatalf("selected count=%d, want 2", result.SelectedCount)
	}
}

func TestProcessGradientBatchWithAdaptiveQuorum(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := make([][]float64, 0, 300)
	for i := 0; i < 300; i++ {
		updates = append(updates, []float64{0.2, 0.2, 0.2})
	}

	result, err := agg.ProcessGradientBatch(updates, 1000, BatchProcessingOptions{
		SemiAsyncQuorum:     0.9,
		AdaptiveQuorumMin:   0.5,
		AdaptiveQuorumMax:   0.95,
		AdaptiveTargetP95Ms: 1,
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if result.EffectiveQuorum < 0.5 || result.EffectiveQuorum > 0.95 {
		t.Fatalf("effective quorum out of bounds: %f", result.EffectiveQuorum)
	}
}

func TestProcessGradientBatchAsyncFallbackOnMultiKrumError(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	agg := NewAggregator(Regional)
	updates := [][]float64{{1, 1, 1}, {2, 2, 2}}

	result, err := agg.ProcessGradientBatch(updates, 100, BatchProcessingOptions{
		ByzantineF:          1,
		MultiKrumM:          5,
		EnableAsyncFallback: true,
	})
	if err != nil {
		t.Fatalf("ProcessGradientBatch failed: %v", err)
	}
	if !result.UsedFallback {
		t.Fatalf("expected fallback path to be used")
	}
}
