package manifest

import "testing"

func TestProperty_ValidateCommunicationComplexity(t *testing.T) {
	m := &Manifest{TaskID: "t", NodeID: "n"}
	for n := 2; n <= 64; n++ {
		for d := 1; d <= 8; d++ {
			_ = m.ValidateCommunicationComplexity(d, n)
		}
	}
}