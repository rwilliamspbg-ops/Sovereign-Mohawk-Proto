package main

import "testing"

func TestGenerateGradientVectorModes(t *testing.T) {
	zero := generateGradientVector("node-zero", 1, "zero")
	if len(zero) != 128 {
		t.Fatalf("zero vector length = %d, want 128", len(zero))
	}
	for i, v := range zero {
		if v != 0 {
			t.Fatalf("zero vector[%d] = %v, want 0", i, v)
		}
	}

	a := generateGradientVector("node-seed", 7, "seeded")
	b := generateGradientVector("node-seed", 7, "seeded")
	nonzero := 0
	for i := range a {
		if a[i] != 0 {
			nonzero++
		}
		if a[i] != b[i] {
			t.Fatalf("seeded vector not deterministic at %d: %v != %v", i, a[i], b[i])
		}
	}
	if nonzero < 100 {
		t.Fatalf("seeded vector has only %d nonzero entries", nonzero)
	}

	byz := generateGradientVector("node-seed", 7, "byzantine")
	if byz[0] < 1000 {
		t.Fatalf("byzantine poison magnitude = %v, want >= 1000", byz[0])
	}
}
