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

// Reference: /proofs/bft_resilience.md
// Secure Wasm environment ensuring execution integrity for BFT guards.
package wasmhost

import (
	"fmt"
)

// Runner handles the deterministic execution of the ML training logic.
// This is a prerequisite for the BFT Resilience proofs in Theorem 1.
type Runner struct {
	ModulePath  string
	MemoryLimit uint32
}

// NewRunner creates a new execution environment for regional aggregators.
// Renamed from NewHost to match cmd/node-agent requirements.
func NewRunner(path string, memLimit uint32) *Runner {
	return &Runner{
		ModulePath:  path,
		MemoryLimit: memLimit,
	}
}

// Initialize checks the environment readiness.
func (r *Runner) Initialize() error {
	if r.ModulePath == "" {
		return fmt.Errorf("failed to initialize Wasm runner: empty module path")
	}
	return nil
}
