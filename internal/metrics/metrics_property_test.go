package metrics

import "testing"

func TestProperty_ObserveNoPanic(t *testing.T) {
	ObserveConsensus("scope", 3, 5)
	ObserveHVALevels("scope", 2)
	ObserveQuote(true)
	ObserveVerification(false)
}