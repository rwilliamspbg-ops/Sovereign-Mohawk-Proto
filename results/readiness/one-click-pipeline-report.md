# One-Click Pipeline Report

- Status: **PASS**
- Started: 2026-03-26T10:20:35Z
- Finished: 2026-03-26T10:21:01Z
- Failed step: None

## Go Toolchain

- Go version: `go1.25.7`
- Compile version: `go1.25.7`
- GOROOT: `/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.7.linux-amd64`
- Aligned: `True`

## Steps

- [PASS] 1. Go 1.25 toolchain alignment (0.03s)
- [PASS] 2. Host kernel network preflight (0.02s)
- [PASS] 3. Static gates (capabilities + PQC contract) (0.09s)
- [PASS] 4. Build + tests + strict auth smoke (4.39s)
- [PASS] 5. Python SDK regression (1.07s)
- [PASS] 6. Boot observability + control plane stack (0.35s)
- [PASS] 7. Mainnet readiness gate (0.15s)
- [PASS] 8. Chaos readiness drill (19.56s)
- [PASS] 9. Readiness digest generation (0.05s)

## Artifacts

- results/readiness/readiness-report.json
- chaos-reports/tpm-metrics-summary.json
- results/readiness/readiness-digest.md
