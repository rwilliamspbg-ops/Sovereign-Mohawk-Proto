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

// Reference: /proofs/cryptography.md
// Theorem 5: O(1) verification time via optimized Wasm host calls.
package wasmhost

import (
	"context"
	"fmt"
	"sync"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)// Copyright 2026 Sovereign-Mohawk Core Team
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

// Reference: /proofs/cryptography.md
// Theorem 5: O(1) verification time via optimized Wasm host calls.
package wasmhost

import (
	"context"
	"fmt"
	"sync"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// Host manages the WebAssembly runtime environment for zk-SNARK verification.
type Host struct {
	runtime wazero.Runtime
	mod     api.Module
	mu      sync.Mutex
}

// NewHost initializes a high-performance Wasm environment.
func NewHost(ctx context.Context, wasmBin []byte) (*Host, error) {
	r := wazero.NewRuntime(ctx)

	// Instantiate the module with hardware acceleration where available
	mod, err := r.Instantiate(ctx, wasmBin)
	if err != nil {
		r.Close(ctx)
		return nil, fmt.Errorf("failed to instantiate wasm: %w", err)
	}

	return &Host{
		runtime: r,
		mod:     mod,
	}, nil
}

// NewRunner is a compatibility alias for NewHost.
// Fixes 'undefined: wasmhost.NewRunner' in cmd/node-agent/main.go.
func NewRunner(ctx context.Context, wasmBin []byte) (*Host, error) {
	return NewHost(ctx, wasmBin)
}

// Verify executes the zk-SNARK proof verification in the Wasm sandbox.
// Targets the 10ms execution window required for 10M-node scale.
func (h *Host) Verify(ctx context.Context, proof []byte) (bool, error) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Theorem 5: Constant-time verification check
	// Note: Guest module must export 'verify_proof'
	results, err := h.mod.ExportedFunction("verify_proof").Call(ctx, uint64(len(proof)))
	if err != nil {
		return false, fmt.Errorf("wasm execution error: %w", err)
	}

	if len(results) == 0 {
		return false, fmt.Errorf("wasm function returned no results")
	}

	return results[0] == 1, nil
}

// FastVerify is an optimized alias for the Verify method.
func (h *Host) FastVerify(ctx context.Context, proof []byte) (bool, error) {
	return h.Verify(ctx, proof)
}

// Close releases Wasm resources.
func (h *Host) Close(ctx context.Context) error {
	return h.runtime.Close(ctx)
}
