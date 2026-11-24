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

package wasmhost

import (
	"context"
	"os"
	"testing"
)

// TestNewRunnerInstantiatesBundledVerifier pins the regression fixed by
// instantiateEnvModule: verifier.wasm imports env.log and env.submit_gradients,
// so NewRunner used to fail with "module[env] not instantiated" and the
// node-agent crash-looped on startup.
func TestNewRunnerInstantiatesBundledVerifier(t *testing.T) {
	wasm, err := os.ReadFile("../../cmd/node-agent/verifier.wasm")
	if err != nil {
		t.Skipf("bundled verifier.wasm not available: %v", err)
	}

	h, err := NewRunner(context.Background(), wasm)
	if err != nil {
		t.Fatalf("NewRunner(bundled verifier.wasm) failed: %v", err)
	}
	defer h.Close(context.Background())
}

// TestBundledVerifierExportsRequiredFunctions checks that the module exposes
// the alloc and verify_proof exports the runner depends on, so the fix is not
// merely a permissive instantiation of a useless module.
func TestBundledVerifierExportsRequiredFunctions(t *testing.T) {
	wasm, err := os.ReadFile("../../cmd/node-agent/verifier.wasm")
	if err != nil {
		t.Skipf("bundled verifier.wasm not available: %v", err)
	}

	ctx := context.Background()
	h, err := NewRunner(ctx, wasm)
	if err != nil {
		t.Fatalf("NewRunner(bundled verifier.wasm) failed: %v", err)
	}
	defer h.Close(ctx)

	if h.mod.ExportedFunction("alloc") == nil {
		t.Fatal("verifier.wasm does not export alloc")
	}
	if h.mod.ExportedFunction("verify_proof") == nil {
		t.Fatal("verifier.wasm does not export verify_proof")
	}
}
