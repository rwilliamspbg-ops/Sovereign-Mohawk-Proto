package hva

import "testing"

func TestProperty_MinimumHonestNodes(t *testing.T) {
	for n := 1; n <= 100; n++ {
		mh := MinimumHonestNodes(n)
		if mh < 0 || mh > n {
			t.Fatalf("n=%d mh=%d", n, mh)
		}
	}
}