# Troubleshooting — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## Symptom -> diagnosis -> fix

| Symptom | Likely cause | Fix |
|---|---|---|
| Node-agent fails to start: "verifier module missing" | Fail-closed verifier boot; `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK` not set and no valid verifier | Provide a valid verifier module, or set `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true` for CI/dev only |
| QUIC UDP-buffer instability | Host UDP socket tuning unavailable | Set `MOHAWK_DISABLE_QUIC=true` (falls back to TCP) |
| Multi-Krum panics: "n <= 2f+2" | Committee too small for Byzantine bound | Increase `NodesPerCommittee` or lower `f` |
| `verify-lean-formalization` CI fails | Runtime formula drifted from Lean claim | Run `make audit-ready-check`; update `proofs/theorem_claims.json` if a theorem changed |
| TPM attestation fails on non-Linux | Hardware TPM only on Linux | Use default backend (lower assurance) or run on Linux |
| Formal proof drift | `check_theorem_runtime_consistency.py` pattern missing | Run `make audit-ready-check`; never weaken claims without review |
| `lake build` fails | Lean toolchain mismatch | Use elan; check `lean-toolchain` |

## 1. Common issues

- **Build failures**: ensure Go 1.25+, Python 3.8+, Lean via elan.
- **Port conflicts**: check `docker-compose.yml` port mappings.
- **Permission errors on TPM**: run with appropriate privileges on Linux.

## 2. Cross-references

- Operations: `docs/guides/OPERATIONS.md`
- Deployment: `docs/guides/DEPLOYMENT.md`
- Incident response: `docs/security/INCIDENT_RESPONSE.md`
- Getting started: `docs/guides/GETTING_STARTED.md`
