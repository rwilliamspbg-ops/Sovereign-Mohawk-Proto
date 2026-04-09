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

package internal

import (
	"os"
	"strconv"
	"strings"
)

const (
	defaultDPSigma         = 0.5
	defaultDPTargetEpsilon = 2.0
	defaultDPDelta         = 1e-5
)

// DPConfig defines the single runtime source of truth for DP-SGD privacy knobs.
type DPConfig struct {
	Sigma         float64
	TargetEpsilon float64
	Delta         float64
}

// LoadDPConfig resolves DP configuration from environment variables with
// validated fallbacks.
func LoadDPConfig() DPConfig {
	return DPConfig{
		Sigma:         envFloat("MOHAWK_DP_SIGMA", defaultDPSigma),
		TargetEpsilon: defaultDPTargetEpsilon,
		Delta:         envFloat("MOHAWK_DP_DELTA", defaultDPDelta),
	}
}

func envFloat(name string, fallback float64) float64 {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil || v <= 0 {
		return fallback
	}
	return v
}
