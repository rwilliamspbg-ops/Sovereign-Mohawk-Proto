# Development Guide — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Prerequisites

- Go 1.25+ (`go.mod`).
- Python 3.8+ (SDK).
- Lean 4 via elan (proofs).
- Docker (optional, for Compose).
- GCC (for CGo / Python bridge).

## 2. Build

```bash
# Go
go build ./...

# Python shared library
make build-python-lib

# Lean proofs
cd proofs && lake build
```

## 3. Test

```bash
go test ./...
go test -race ./...
python3 scripts/ci/check_markdown_links.py
make audit-ready-check
```

## 4. Project layout

- `internal/` — Go runtime packages.
- `proofs/` — Lean 4 formalization.
- `sdk/python/` — Python SDK.
- `docs/` — documentation.
- `scripts/` — build/deploy/CI scripts.
- `monitoring/` — Prometheus/Grafana configs.

## 5. Contribution workflow

1. Create a feature branch.
2. Make changes; run tests.
3. Open a PR; CI runs the full gate.
4. For doc changes, run the link checker.

See `CONTRIBUTING.md` (root) and `docs/CONTRIBUTING_LEAN_PROOFS.md`.
