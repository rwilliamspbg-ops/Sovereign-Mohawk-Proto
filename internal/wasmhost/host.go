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
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// compilationCacheDir is the directory used to persist wazero AOT-compiled
// WASM modules between process restarts, eliminating repeated JIT warm-up
// on restarts of long-running node-agents.
const compilationCacheDir = "/tmp/mohawk-wasm-cache"

const (
	MaxModuleBytes       = 10 * 1024 * 1024
	MaxFunctionCount     = 1000
	MaxImportCount       = 1000
	MaxFunctionLocals    = 1024
	MaxTotalLocalEntries = 20000
	DefaultMaxMillis     = 30_000
)

// Host manages the WebAssembly runtime environment for zk-SNARK verification.
type Host struct {
	runtime wazero.Runtime
	mod     api.Module
	mu      sync.Mutex
}

// Registry manages hash-addressed WASM hosts and supports default hot reload.
type Registry struct {
	mu          sync.RWMutex
	modules     map[string]*Host
	defaultHash string
}

// NewRegistry creates an empty module registry.
func NewRegistry() *Registry {
	return &Registry{modules: make(map[string]*Host)}
}

// NewHost initializes a high-performance Wasm environment.
// It enables the wazero compilation cache so that modules are compiled once
// and reused on subsequent startups, and enables WASM SIMD intrinsics where
// the host CPU supports them (detected automatically by wazero).
func NewHost(ctx context.Context, wasmBin []byte) (*Host, error) {
	if err := ValidateModuleLimits(wasmBin); err != nil {
		return nil, err
	}

	cfg := wazero.NewRuntimeConfig().
		WithCompilationCache(newCompilationCache(ctx))

	r := wazero.NewRuntimeWithConfig(ctx, cfg)

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

// ValidateModuleLimits enforces static module-level safety guardrails before
// any JIT/AOT compilation work is performed.
func ValidateModuleLimits(wasmBin []byte) error {
	if len(wasmBin) == 0 {
		return fmt.Errorf("empty wasm module")
	}
	if len(wasmBin) > MaxModuleBytes {
		return fmt.Errorf("wasm module size %d exceeds max %d bytes", len(wasmBin), MaxModuleBytes)
	}

	limits, err := inspectModuleLimits(wasmBin)
	if err != nil {
		return fmt.Errorf("invalid wasm module: %w", err)
	}
	if limits.FunctionCount > MaxFunctionCount {
		return fmt.Errorf("wasm module function count %d exceeds max %d", limits.FunctionCount, MaxFunctionCount)
	}
	if limits.ImportCount > MaxImportCount {
		return fmt.Errorf("wasm module import count %d exceeds max %d", limits.ImportCount, MaxImportCount)
	}
	if limits.MaxLocalsPerFunction > MaxFunctionLocals {
		return fmt.Errorf("wasm module max locals per function %d exceeds max %d", limits.MaxLocalsPerFunction, MaxFunctionLocals)
	}
	if limits.TotalLocalEntries > MaxTotalLocalEntries {
		return fmt.Errorf("wasm module total local entries %d exceeds max %d", limits.TotalLocalEntries, MaxTotalLocalEntries)
	}
	return nil
}

type moduleLimits struct {
	FunctionCount        int
	ImportCount          uint32
	MaxLocalsPerFunction uint32
	TotalLocalEntries    uint32
}

func inspectModuleLimits(wasmBin []byte) (moduleLimits, error) {
	limits := moduleLimits{}
	if len(wasmBin) < 8 {
		return limits, fmt.Errorf("module too short")
	}
	if wasmBin[0] != 0x00 || wasmBin[1] != 0x61 || wasmBin[2] != 0x73 || wasmBin[3] != 0x6d {
		return limits, fmt.Errorf("bad wasm magic")
	}
	if wasmBin[4] != 0x01 || wasmBin[5] != 0x00 || wasmBin[6] != 0x00 || wasmBin[7] != 0x00 {
		return limits, fmt.Errorf("unsupported wasm version")
	}

	offset := uint64(8)
	var importedFuncs uint32
	var definedFuncs uint32
	bufLen := uint64(len(wasmBin))

	for offset < bufLen {
		sectionID := wasmBin[offset]
		offset++

		sectionSize, n, err := readVarUint32(wasmBin[offset:])
		if err != nil {
			return limits, fmt.Errorf("read section size: %w", err)
		}
		offset += uint64(n)
		if uint64(sectionSize) > bufLen-offset {
			return limits, fmt.Errorf("section exceeds module bounds")
		}

		section := wasmBin[offset:][:sectionSize]
		offset += uint64(sectionSize)

		switch sectionID {
		case 2:
			importCount, funcCount, err := countImports(section)
			if err != nil {
				return limits, fmt.Errorf("parse import section: %w", err)
			}
			limits.ImportCount = importCount
			importedFuncs = funcCount
		case 3:
			count, _, err := readVarUint32(section)
			if err != nil {
				return limits, fmt.Errorf("parse function section: %w", err)
			}
			definedFuncs = count
		case 10:
			maxLocals, totalLocals, err := parseCodeSectionLocals(section, definedFuncs)
			if err != nil {
				return limits, fmt.Errorf("parse code section: %w", err)
			}
			limits.MaxLocalsPerFunction = maxLocals
			limits.TotalLocalEntries = totalLocals
		}
	}

	limits.FunctionCount = int(importedFuncs + definedFuncs)
	return limits, nil
}

func countImports(section []byte) (uint32, uint32, error) {
	entryCount, i, err := readVarUint32(section)
	if err != nil {
		return 0, 0, err
	}

	var importCount uint32
	var importedFuncs uint32
	for entry := uint32(0); entry < entryCount; entry++ {
		importCount++
		if err := skipName(section, &i); err != nil {
			return 0, 0, err
		}
		if err := skipName(section, &i); err != nil {
			return 0, 0, err
		}
		if i >= len(section) {
			return 0, 0, fmt.Errorf("truncated import descriptor")
		}
		kind := section[i]
		i++

		switch kind {
		case 0x00: // func
			_, n, err := readVarUint32(section[i:])
			if err != nil {
				return 0, 0, err
			}
			i += n
			importedFuncs++
		case 0x01: // table
			if i >= len(section) {
				return 0, 0, fmt.Errorf("truncated table import")
			}
			i++ // elemtype
			if err := skipLimits(section, &i); err != nil {
				return 0, 0, err
			}
		case 0x02: // memory
			if err := skipLimits(section, &i); err != nil {
				return 0, 0, err
			}
		case 0x03: // global
			if i+2 > len(section) {
				return 0, 0, fmt.Errorf("truncated global import")
			}
			i += 2 // valtype + mutability
		default:
			return 0, 0, fmt.Errorf("unsupported import kind %d", kind)
		}
	}

	return importCount, importedFuncs, nil
}

func parseCodeSectionLocals(section []byte, expectedBodies uint32) (uint32, uint32, error) {
	bodyCount, i, err := readVarUint32(section)
	if err != nil {
		return 0, 0, err
	}
	if expectedBodies > 0 && bodyCount != expectedBodies {
		return 0, 0, fmt.Errorf("function/code section count mismatch: %d != %d", expectedBodies, bodyCount)
	}

	var maxLocals uint32
	var totalLocals uint32
	for body := uint32(0); body < bodyCount; body++ {
		bodySize, n, err := readVarUint32(section[i:])
		if err != nil {
			return 0, 0, err
		}
		i += n
		bodySizeInt, err := safeIntFromUint32(bodySize)
		if err != nil {
			return 0, 0, fmt.Errorf("invalid body size: %w", err)
		}
		if i+bodySizeInt > len(section) {
			return 0, 0, fmt.Errorf("function body exceeds bounds")
		}

		bodyBytes := section[i : i+bodySizeInt]
		i += bodySizeInt

		locals, err := parseFunctionLocals(bodyBytes)
		if err != nil {
			return 0, 0, err
		}
		totalLocals += locals
		if locals > maxLocals {
			maxLocals = locals
		}
	}
	return maxLocals, totalLocals, nil
}

func parseFunctionLocals(body []byte) (uint32, error) {
	declCount, i, err := readVarUint32(body)
	if err != nil {
		return 0, err
	}

	var totalLocals uint32
	for d := uint32(0); d < declCount; d++ {
		count, n, err := readVarUint32(body[i:])
		if err != nil {
			return 0, err
		}
		i += n
		if i >= len(body) {
			return 0, fmt.Errorf("truncated locals type")
		}
		i++ // valtype
		totalLocals += count
	}
	return totalLocals, nil
}

func skipName(data []byte, i *int) error {
	if *i >= len(data) {
		return fmt.Errorf("truncated name")
	}
	nameLen, n, err := readVarUint32(data[*i:])
	if err != nil {
		return err
	}
	*i += n
	nameLenInt, err := safeIntFromUint32(nameLen)
	if err != nil {
		return fmt.Errorf("invalid name length: %w", err)
	}
	if *i+nameLenInt > len(data) {
		return fmt.Errorf("name exceeds bounds")
	}
	*i += nameLenInt
	return nil
}

func skipLimits(data []byte, i *int) error {
	if *i >= len(data) {
		return fmt.Errorf("truncated limits")
	}
	flags, n, err := readVarUint32(data[*i:])
	if err != nil {
		return err
	}
	*i += n

	if _, n, err = readVarUint32(data[*i:]); err != nil {
		return err
	}
	*i += n

	if flags&0x01 != 0 {
		if _, n, err = readVarUint32(data[*i:]); err != nil {
			return err
		}
		*i += n
	}
	return nil
}

func readVarUint32(data []byte) (uint32, int, error) {
	var value uint32
	var shift uint
	for i, b := range data {
		value |= uint32(b&0x7f) << shift
		if b&0x80 == 0 {
			return value, i + 1, nil
		}
		shift += 7
		if shift >= 35 {
			return 0, 0, fmt.Errorf("varuint32 too large")
		}
	}
	return 0, 0, fmt.Errorf("truncated varuint32")
}

// newCompilationCache creates a filesystem-backed compilation cache at
// compilationCacheDir. Falls back to an in-memory cache if the path is
// not writable (e.g. read-only container filesystem).
func newCompilationCache(ctx context.Context) wazero.CompilationCache {
	cache, err := wazero.NewCompilationCacheWithDir(compilationCacheDir)
	if err != nil {
		// Fallback: in-memory cache — no error propagation, just warm up every run.
		return wazero.NewCompilationCache()
	}
	_ = ctx
	return cache
}

// NewRunner is a compatibility alias for NewHost.
func NewRunner(ctx context.Context, wasmBin []byte) (*Host, error) {
	return NewHost(ctx, wasmBin)
}

// Upsert compiles/loads a WASM module and stores it by SHA256 content hash.
// Returns the module hash. Existing hashes are deduplicated.
func (r *Registry) Upsert(ctx context.Context, wasmBin []byte) (string, error) {
	if len(wasmBin) == 0 {
		return "", fmt.Errorf("empty wasm module")
	}
	hashBytes := sha256.Sum256(wasmBin)
	hash := hex.EncodeToString(hashBytes[:])

	r.mu.RLock()
	_, exists := r.modules[hash]
	r.mu.RUnlock()
	if exists {
		return hash, nil
	}

	host, err := NewHost(ctx, wasmBin)
	if err != nil {
		return "", err
	}

	r.mu.Lock()
	if _, exists = r.modules[hash]; exists {
		r.mu.Unlock()
		_ = host.Close(ctx)
		return hash, nil
	}
	r.modules[hash] = host
	if r.defaultHash == "" {
		r.defaultHash = hash
	}
	r.mu.Unlock()

	return hash, nil
}

// Get returns a host by content hash.
func (r *Registry) Get(hash string) (*Host, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	host, ok := r.modules[hash]
	return host, ok
}

// Default returns the current default host.
func (r *Registry) Default() *Host {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.defaultHash == "" {
		return nil
	}
	return r.modules[r.defaultHash]
}

// HotReload inserts module bytes and sets that module as default.
func (r *Registry) HotReload(ctx context.Context, wasmBin []byte) (string, error) {
	hash, err := r.Upsert(ctx, wasmBin)
	if err != nil {
		return "", err
	}
	r.mu.Lock()
	r.defaultHash = hash
	r.mu.Unlock()
	return hash, nil
}

// Close releases all module runtimes in the registry.
func (r *Registry) Close(ctx context.Context) error {
	r.mu.Lock()
	modules := r.modules
	r.modules = make(map[string]*Host)
	r.defaultHash = ""
	r.mu.Unlock()

	for _, host := range modules {
		if host != nil {
			_ = host.Close(ctx)
		}
	}
	return nil
}

// Verify executes the "verify_proof" Wasm export and enforces the per-manifest
// execution deadline. maxMillis == 0 falls back to DefaultMaxMillis.
func (h *Host) Verify(ctx context.Context, proof []byte, maxMillis uint64) (bool, error) {
	if maxMillis == 0 {
		maxMillis = DefaultMaxMillis
	}
	maxAllowedMillis := uint64(math.MaxInt64 / int64(time.Millisecond))
	if maxMillis > maxAllowedMillis {
		return false, fmt.Errorf("maxMillis %d exceeds supported maximum %d", maxMillis, maxAllowedMillis)
	}
	deadline := time.Duration(maxMillis) * time.Millisecond
	execCtx, cancel := context.WithTimeout(ctx, deadline)
	defer cancel()

	h.mu.Lock()
	defer h.mu.Unlock()

	fn := h.mod.ExportedFunction("verify_proof")
	if fn == nil {
		return false, fmt.Errorf("wasm module missing required export: verify_proof")
	}

	// Theorem 5: Constant-time verification check
	proofLen, err := safeUint64FromInt(len(proof))
	if err != nil {
		return false, err
	}
	results, err := fn.Call(execCtx, proofLen)
	if err != nil {
		if execCtx.Err() != nil {
			return false, fmt.Errorf("wasm execution timed out after %dms: %w", maxMillis, execCtx.Err())
		}
		return false, fmt.Errorf("wasm execution error: %w", err)
	}

	if len(results) == 0 {
		return false, fmt.Errorf("wasm function returned no results")
	}

	return results[0] == 1, nil
}

// FastVerify is an optimized alias for Verify with the default timeout.
func (h *Host) FastVerify(ctx context.Context, proof []byte) (bool, error) {
	return h.Verify(ctx, proof, DefaultMaxMillis)
}

func safeUint64FromInt(v int) (uint64, error) {
	if v < 0 {
		return 0, fmt.Errorf("negative value %d cannot be converted to uint64", v)
	}
	return uint64(v), nil
}

// safeIntFromUint32 safely converts uint32 to int with bounds checking.
// Returns an error if the conversion would overflow on the host architecture.
func safeIntFromUint32(v uint32) (int, error) {
	maxInt := int(^uint(0) >> 1)
	if int64(v) > int64(maxInt) {
		return 0, fmt.Errorf("uint32 value %d exceeds maximum int value %d", v, maxInt)
	}
	return int(v), nil
}

// Close releases Wasm resources.
func (h *Host) Close(ctx context.Context) error {
	return h.runtime.Close(ctx)
}
