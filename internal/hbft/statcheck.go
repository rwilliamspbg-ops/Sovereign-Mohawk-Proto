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

import "math/rand/v2"

// StatCheckConfig configures a Technique-B empirical sanity-check trial
// batch. This is deliberately independent of Simulator/MultiKrumSelect: it
// exists only to sanity-check the Chernoff tail bound
// (proofs/LeanFormalization/Theorem1BFT.lean's chernoff_hierarchical_bound)
// against a fresh, minimal trial generator that matches that theorem's
// literal statement exactly -- the probability that any of Committees
// committees' realized Byzantine count (each of NodesPerCommittee nodes,
// each independently Byzantine with probability ByzantineRate) reaches
// FailureThreshold. Multi-Krum selection, gradients, and the weighted-
// credit HTree.safe rule Technique A checks are all out of scope here on
// purpose -- see proofs/TraceValidator/HierarchicalBFTBoundEval.lean's doc
// comment for why conflating the two would be a real, if subtle, category
// error (that theorem is about raw per-committee Byzantine counts, not
// about the weighted-credit mechanism hierarchical_composition_
// counterexample already found unsound in the deterministic case).
type StatCheckConfig struct {
	Trials            int
	Committees        int     // T in chernoff_hierarchical_bound
	NodesPerCommittee int     // c
	FailureThreshold  int     // k
	ByzantineRate     float64 // p
	Seed              uint64
}

// StatCheckResult is the empirical outcome of running cfg.Trials
// independent trials.
type StatCheckResult struct {
	Trials        int
	Failures      int
	EmpiricalRate float64
}

// RunStatCheck runs cfg.Trials independent trials, each sampling
// cfg.Committees committees of cfg.NodesPerCommittee nodes, each
// independently Byzantine with probability cfg.ByzantineRate (i.i.d.
// Bernoulli per node, matching chernoff_hierarchical_bound's binomial
// model exactly), and counts a trial as a "failure" iff any committee's
// realized Byzantine count reaches cfg.FailureThreshold.
func RunStatCheck(cfg StatCheckConfig) StatCheckResult {
	rng := rand.New(rand.NewPCG(cfg.Seed, 0))
	failures := 0
	for t := 0; t < cfg.Trials; t++ {
		trialFailed := false
		for c := 0; c < cfg.Committees; c++ {
			byz := 0
			for n := 0; n < cfg.NodesPerCommittee; n++ {
				if rng.Float64() < cfg.ByzantineRate {
					byz++
				}
			}
			if byz >= cfg.FailureThreshold {
				trialFailed = true
			}
		}
		if trialFailed {
			failures++
		}
	}
	return StatCheckResult{
		Trials:        cfg.Trials,
		Failures:      failures,
		EmpiricalRate: float64(failures) / float64(cfg.Trials),
	}
}
