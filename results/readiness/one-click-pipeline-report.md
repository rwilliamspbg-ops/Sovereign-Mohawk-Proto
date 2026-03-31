# One-Click Pipeline Report

- Status: **PASS**
- Started: 2026-03-28T13:51:34Z
- Finished: 2026-03-28T13:52:11Z
- Failed step: None

## Go Toolchain

- Go version: `go1.25.8`
- Compile version: `go1.25.8`
- GOROOT: `/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.8.linux-amd64`
- Aligned: `True`

## Steps

- [PASS] 1. Go 1.25 toolchain alignment (0.04s)
- [PASS] 2. Host kernel network preflight (0.03s)
- [PASS] 3. Static gates (capabilities + PQC contract) (0.09s)
- [PASS] 4. Build + tests + strict auth smoke (6.92s)
- [PASS] 5. Python SDK regression (1.16s)
- [PASS] 6. Boot observability + control plane stack (6.53s)
- [PASS] 7. Mainnet readiness gate (0.18s)
- [PASS] 8. Chaos readiness drill (21.78s)
- [PASS] 9. Readiness digest generation (0.05s)

## Artifacts

- results/readiness/readiness-report.json
- chaos-reports/tpm-metrics-summary.json
- results/readiness/readiness-digest.md
