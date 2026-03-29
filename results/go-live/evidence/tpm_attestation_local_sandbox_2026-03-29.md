# TPM Attestation Local Sandbox Validation - 2026-03-29

## Target

- Platform: `swtpm`-style containerized development path (local dev container)
- Scope: Mini-Mohawk sandbox (`orchestrator`, `node-agent-1`, `node-agent-2`)
- Attestation mode: `MOHAWK_TPM_IDENTITY_SIG_MODE=xmss`
- Transport mode: `MOHAWK_TRANSPORT_KEX_MODE=x25519-mlkem768-hybrid`

## Execution Summary

Commands executed:

1. `./scripts/launch_sandbox.sh`
2. `make forensics-drill`
3. `bash scripts/quantum_kex_rotation_drill.sh --mode x25519-mlkem768-hybrid --services node-agent-1,node-agent-2,orchestrator`
4. `make forensics-drill-down`

Observed outcomes:

- Sandbox startup: success
- Node agent gradient submission loop: active
- Forensics extraction output generated:
  - `results/forensics/byzantine_rejections_local.md`
  - `results/forensics/byzantine_forensics_metrics_local.json`
- Rejection/failure events in local drill: `0`

## Integrity and Stability Signals

- `accepted=false`: `0`
- `submission_failed`: `0`
- `kex_mismatch`: `0`
- `unsupported_kex_mode`: `0`
- `kex_key_size_mismatch`: `0`

Source: `results/forensics/byzantine_forensics_metrics_local.json`

## Limitations of This Capture

- Mini-Mohawk sandbox profile does not include Prometheus by default, so p95 query capture for proof and gradient latency was not collected in this run.
- This validation is an operational sanity pass for local TPM-attested flow behavior, not a production-grade hardware benchmark.

## Status

- Local validation status: verified for sandbox operational behavior
- Production hardware benchmark status: tracked separately in `HARDWARE_COMPATIBILITY.md` and go-live evidence matrix
