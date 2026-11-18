//go:build race

package test

// zkWeightRaceBuild is true when the test binary is built with the race
// detector.
//
// The WeightUpdateCircuit tests are skipped in that build, because they pay a
// one-time trusted setup -- a simulated multi-party Groth16 ceremony over ~9.6k
// constraints -- that costs tens of seconds natively and is disproportionately
// slower under the race detector. The stress job that builds with -race also
// runs `-count=50`, which pushed ./test/... past `go test`'s 10m per-package
// timeout. Proving is deterministic, single-goroutine cryptography, so it adds
// no race-detection value.
//
// Cover it without the detector: go test ./test/ -run 'TestWeightProof|TestBatchAggregator_ZKWeight'.
const zkWeightRaceBuild = true
