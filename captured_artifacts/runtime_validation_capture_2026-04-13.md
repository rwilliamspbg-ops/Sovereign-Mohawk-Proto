# Runtime Validation Capture (2026-04-13)

## Scope

- Repository integrity verification before artifact publication.
- Router functional smoke validation.
- Performance artifact refresh for FedAvg and bridge serialization.

## Commands Executed

- `source scripts/ensure_go_toolchain.sh && make lint`
- `source scripts/ensure_go_toolchain.sh && go test -count=1 ./...`
- `ROUTER_URL=http://127.0.0.1:8087 bash scripts/router_smoke_discovery.sh`
- `bash scripts/benchmark_fedavg_compare.sh`
- `bash scripts/benchmark_bridge_compression_compare.sh`

## Verification Results

- Lint: passed (`go fmt`, `go vet`).
- Go tests: passed across repository packages.
- Router smoke: passed publish/subscribe/discover/provenance flow.

## Captured Public Artifacts

- `results/metrics/fedavg_benchmark_compare.md`
- `results/metrics/bridge_compression_benchmark_compare.md`
- `results/metrics/bridge_compression_benchmark_raw.txt`

## Key Performance Highlights

- FedAvg geomean: `290.0us` (`+0.09%` vs base).
- Bridge zero-copy speedup over JSON:
  - dim512: `54.63x`
  - dim2048: `71.31x`
  - dim8192: `71.48x`
  - dim16384: `69.97x`

## Notes

- Local smoke run used `MOHAWK_ROUTER_ALLOW_INSECURE_DEV_QUOTES=true` to allow CI/dev quote payloads during functional endpoint validation.
- This capture is validation-focused and does not include new core routing/scalability code changes.
- Micro-benchmark speedups improved over JSON but can vary by environment; compare against runs with matching host and toolchain context.
- Macro scale gap remains: this artifact set does not include a loaded 1500-node `.prom` snapshot or sustained high-volume throughput run.
- Prior stress observations around modest `bridge_total` throughput remain a target for dedicated optimization and long-duration load testing.
