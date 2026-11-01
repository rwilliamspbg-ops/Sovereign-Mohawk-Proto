# Testing Enhancement Scope — Sovereign-Mohawk-Proto

Derived from RustForge advanced-tier concepts, adapted to Go/Python/Lean stack.

## Goal
Improve test strength validation and protocol-parsing fuzz coverage without blocking PRs (informational initially).

## Work items

### 1. Mutation testing (informational)
- Tool: `gremlins` or `go-mutesting` (Go-native, no Rust).
- Target packages: `node/...` protocol parsing, `server/...` aggregation, RDP accountant.
- CI: new job `mutation-testing` in `.github/workflows/` with `continue-on-error: true`, uploads mutant report artifact.
- Gate: informational only; never blocks merge until score baseline established.

### 2. Broader fuzz targets (`go test -fuzz`)
- Add fuzz functions for:
  - protocol message deserialization (orchestrator/node-agent boundary)
  - manifest JSON parsing
  - ZK proof verification inputs
  - RDP accountant shard aggregation
- Location: alongside existing `*_fuzz_test.go` files in `node/`.
- CI: extend existing fuzz smoke job with `go test -fuzz=FuzzX -fuzztime=30s`.

### 3. Property test expansion
- Use `github.com/leanovate/gopter` or `pgregory.net/rapid` for additional invariants on scheduler auction, threshold aggregation.

### 4. Concurrency (Go race detector already in `go-test-race`; add stress loops)
- Add `-race -count=100` variant for concurrency-sensitive packages.

## Out of scope
- Rust-specific tooling (loom, cargo-mutants, trybuild) — not applicable.
- Hard coverage gates — deferred until baseline.

## Success criteria
- Mutation job runs green (informational) on main.
- ≥4 new fuzz targets committed.
- No regression in existing test suite.
