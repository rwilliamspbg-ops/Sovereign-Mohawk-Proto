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

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// instantiateEnvModule provides the host functions imported by the bundled
// verifier.wasm module, which is built from wasm-modules/fl_task with
// #[link(wasm_import_module = "env")].
//
// Its two imports are ancillary task/logging hooks (env.log and
// env.submit_gradients), not part of the Groth16/ed25519 verification path,
// which is self-contained in the module. Before this host module existed,
// wazero rejected every instantiation of verifier.wasm with
// "module[env] not instantiated", so the node-agent could not start at all.
func instantiateEnvModule(ctx context.Context, r wazero.Runtime) (api.Module, error) {
	return r.NewHostModuleBuilder("env").
		NewFunctionBuilder().
		WithFunc(func(_ context.Context, offset, length, level uint32) {
			// Task log output is intentionally discarded: the host process owns
			// logging and the wasm task does not expose a structured stream here.
			_ = offset
			_ = length
			_ = level
		}).
		Export("log").
		NewFunctionBuilder().
		WithFunc(func(_ context.Context, offset, length uint32) uint32 {
			// Gradient submission from the wasm task is handled by the Go
			// node-agent; report success so the task completes its flow.
			_ = offset
			_ = length
			return 0
		}).
		Export("submit_gradients").
		Instantiate(ctx)
}
