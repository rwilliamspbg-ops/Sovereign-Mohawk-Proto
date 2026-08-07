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

// AdversaryStrategy crafts submitted gradients for a round's Byzantine
// committee members. honestGradients gives the strategy visibility into
// what honest members are submitting this round: a worst-case assumption
// (a real attacker might not have this), but assuming it does is what
// makes a passing trace validator's cross-check meaningful against a
// genuinely adaptive attacker rather than a strawman that Multi-Krum's
// distance-based scoring would filter trivially.
type AdversaryStrategy interface {
	Craft(rng *rand.Rand, dimension int, honestGradients [][]float64, byzantineCount int) [][]float64
}

// OutlierAdversary submits gradients far from the honest cluster in every
// dimension -- trivially filtered by Multi-Krum's distance-based scoring.
// Mirrors the existing internal/multikrum_test.go fixture style. Useful
// as a sanity baseline, not the interesting case.
type OutlierAdversary struct {
	Magnitude float64
}

func (a OutlierAdversary) Craft(_ *rand.Rand, dimension int, _ [][]float64, byzantineCount int) [][]float64 {
	out := make([][]float64, byzantineCount)
	for i := range out {
		g := make([]float64, dimension)
		for d := range g {
			g[d] = a.Magnitude
		}
		out[i] = g
	}
	return out
}

// CollusionAdversary biases Byzantine members' gradients toward a shared
// target offset from the honest cluster's centroid, with small per-node
// jitter so colluding submissions aren't bit-identical. This is the
// interesting case: colluding nodes that agree with each other look like
// a legitimate cluster to Krum's neighbor-distance scoring unless the
// bias is large enough to separate them from the honest cluster --
// exactly the attack Multi-Krum's guarantee is actually about, not a
// strawman far-outlier.
type CollusionAdversary struct {
	Bias float64
}

func (a CollusionAdversary) Craft(rng *rand.Rand, dimension int, honestGradients [][]float64, byzantineCount int) [][]float64 {
	target := centroidOf(honestGradients, dimension)
	for d := range target {
		target[d] += a.Bias
	}
	out := make([][]float64, byzantineCount)
	for i := range out {
		g := make([]float64, dimension)
		copy(g, target)
		for d := range g {
			g[d] += (rng.Float64() - 0.5) * 0.01
		}
		out[i] = g
	}
	return out
}

func centroidOf(gradients [][]float64, dimension int) []float64 {
	c := make([]float64, dimension)
	for _, g := range gradients {
		for d := 0; d < dimension; d++ {
			c[d] += g[d]
		}
	}
	if len(gradients) > 0 {
		for d := range c {
			c[d] /= float64(len(gradients))
		}
	}
	return c
}
