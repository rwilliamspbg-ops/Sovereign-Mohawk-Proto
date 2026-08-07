// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package hbft

import "testing"

func TestRunStatCheck_ZeroByzantineRateNeverFails(t *testing.T) {
	result := RunStatCheck(StatCheckConfig{
		Trials:            500,
		Committees:        12,
		NodesPerCommittee: 27,
		FailureThreshold:  14,
		ByzantineRate:     0,
		Seed:              1,
	})
	if result.Failures != 0 {
		t.Fatalf("expected 0 failures at ByzantineRate=0, got %d/%d", result.Failures, result.Trials)
	}
}

func TestRunStatCheck_CertainFailureAboveThreshold(t *testing.T) {
	// FailureThreshold=1 with ByzantineRate=1: every node in every
	// committee is Byzantine, so every committee trivially reaches the
	// threshold on every trial.
	result := RunStatCheck(StatCheckConfig{
		Trials:            50,
		Committees:        12,
		NodesPerCommittee: 27,
		FailureThreshold:  1,
		ByzantineRate:     1.0,
		Seed:              2,
	})
	if result.Failures != result.Trials {
		t.Fatalf("expected all %d trials to fail at ByzantineRate=1, got %d failures", result.Trials, result.Failures)
	}
}

func TestRunStatCheck_DeterministicGivenSeed(t *testing.T) {
	cfg := StatCheckConfig{
		Trials:            2000,
		Committees:        12,
		NodesPerCommittee: 27,
		FailureThreshold:  14,
		ByzantineRate:     0.3,
		Seed:              99,
	}
	a := RunStatCheck(cfg)
	b := RunStatCheck(cfg)
	if a.Failures != b.Failures {
		t.Fatalf("expected identical failure counts for identically-seeded runs, got %d vs %d", a.Failures, b.Failures)
	}
}

func TestRunStatCheck_EmpiricalRateRoughlyMatchesTheory(t *testing.T) {
	// At T=12, c=27, k=14, p=0.3, the true union failure probability is
	// ~0.158 (computed independently in Python during design of this
	// test -- see the implementation plan). 20000 trials should land
	// comfortably within a generous +/-0.05 absolute margin; a much
	// larger deviation would indicate a real bug in the trial generator,
	// not sampling noise.
	result := RunStatCheck(StatCheckConfig{
		Trials:            20000,
		Committees:        12,
		NodesPerCommittee: 27,
		FailureThreshold:  14,
		ByzantineRate:     0.3,
		Seed:              7,
	})
	const wantApprox = 0.158
	const margin = 0.05
	if result.EmpiricalRate < wantApprox-margin || result.EmpiricalRate > wantApprox+margin {
		t.Fatalf("empirical rate %f outside expected range [%f, %f] (theoretical ~%f)",
			result.EmpiricalRate, wantApprox-margin, wantApprox+margin, wantApprox)
	}
}
