package mpc

import (
	"testing"
)

func TestSplitAndReconstruct(t *testing.T) {
	val := []float64{1.0, 2.0, 3.0}
	shares, err := SplitVector(val, 3, func() float64 { return 0.5 })
	if err != nil {
		t.Fatal(err)
	}
	if len(shares) != 3 {
		t.Fatalf("expected 3 shares, got %d", len(shares))
	}
	// reconstruct
	sum := make([]float64, len(val))
	for _, sh := range shares {
		for i := range sh {
			sum[i] += sh[i]
		}
	}
	for i := range val {
		if sum[i] != val[i] {
			t.Fatalf("reconstruct mismatch: %v vs %v", sum[i], val[i])
		}
	}
}

func TestAggregateBasic(t *testing.T) {
	out, err := Aggregate([][]float64{{1, 2}, {3, 4}, {5, 6}})
	if err != nil {
		t.Fatal(err)
	}
	if out[0] != 9 || out[1] != 12 {
		t.Fatalf("unexpected: %v", out)
	}
}

func TestAggregateDimensionMismatch(t *testing.T) {
	_, err := Aggregate([][]float64{{1, 2}, {3}})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestCoordinatorRound(t *testing.T) {
	parties := []PartyID{"p1", "p2", "p3"}
	c := NewCoordinator(parties)
	inputs := map[PartyID][]float64{
		"p1": {1.0, 2.0},
		"p2": {3.0, 4.0},
		"p3": {5.0, 6.0},
	}
	out, err := c.Round(inputs)
	if err != nil {
		t.Fatal(err)
	}
	// expected: 9, 12
	if out[0] < 8.999 || out[0] > 9.001 || out[1] < 11.999 || out[1] > 12.001 {
		t.Fatalf("unexpected aggregate: %v", out)
	}
}

func TestCoordinatorMissingInput(t *testing.T) {
	c := NewCoordinator([]PartyID{"p1", "p2"})
	_, err := c.Round(map[PartyID][]float64{"p1": {1.0}})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestSplitValidation(t *testing.T) {
	if _, err := SplitVector([]float64{1}, 1, DefaultRNG); err == nil {
		t.Fatal("expected error for n<2")
	}
	if _, err := SplitVector(nil, 3, DefaultRNG); err == nil {
		t.Fatal("expected error for empty vector")
	}
}

func TestDefaultRNG(t *testing.T) {
	r := DefaultRNG()
	if r < -1 || r > 1 {
		t.Fatalf("out of range: %v", r)
	}
}
