//go:build !race

package test

// zkWeightRaceBuild is false in a normal (non-race) test build; see
// zkweight_racebuild.go for why the race build skips the weight-proof tests.
const zkWeightRaceBuild = false
