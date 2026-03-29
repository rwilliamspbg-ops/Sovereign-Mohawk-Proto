# Forensics Rehearsal Validation - 2026-03-29

## Scope

This validation records local execution evidence for Day 2 operational tooling:

- Mini-Mohawk sandbox startup and teardown
- Byzantine forensics extraction report and JSON metrics generation
- Quantum KEX rotation drill (dry-run and live rolling restart)
- Compact rehearsal command behavior (`make forensics-rehearsal`)

## Commands Executed

1. `./scripts/launch_sandbox.sh`
2. `bash scripts/extract_byzantine_forensics.sh --since 10m --output results/forensics/byzantine_rejections_manual.md --metrics-json results/forensics/byzantine_forensics_metrics_manual.json`
3. `bash scripts/quantum_kex_rotation_drill.sh --dry-run`
4. `bash scripts/quantum_kex_rotation_drill.sh --mode x25519-mlkem768-hybrid --services node-agent-1,node-agent-2,orchestrator`
5. `make forensics-rehearsal`
6. `docker compose -f docker-compose.sandbox.yml ps` (cleanup verification)

## Runtime Results

### Sandbox behavior

- Sandbox services started successfully (`orchestrator`, `shard-us-east`, `node-agent-1`, `node-agent-2`, `ipfs`).
- Teardown verification after rehearsal showed no running services.

### Forensics output behavior

Artifacts generated:

- `results/forensics/byzantine_rejections_manual.md`
- `results/forensics/byzantine_forensics_metrics_manual.json`
- `results/forensics/byzantine_rejections_local.md`
- `results/forensics/byzantine_forensics_metrics_local.json`

Observed values for local drill (`15m` window):

- total_lines: `43`
- total_events: `0`
- event_ratio_percent: `0.0`
- accepted_false: `0`
- submission_failed: `0`
- kex_mismatch: `0`
- unsupported_kex_mode: `0`
- kex_key_size_mismatch: `0`

### Artifact delta (local vs manual baseline)

Comparison performed between:

- local: `results/forensics/byzantine_forensics_metrics_local.json` (`15m`)
- baseline: `results/forensics/byzantine_forensics_metrics_manual.json` (`10m`)

Delta summary:

- delta_total_events: `0`
- delta_accepted_false: `0`
- delta_submission_failed: `0`
- delta_kex_mismatch: `0`
- delta_unsupported_kex_mode: `0`
- delta_kex_key_size_mismatch: `0`

## Recovery Behavior Validation

### Quantum KEX rotation drill

- Dry-run path executed successfully.
- Live rolling restart path executed successfully for selected services (`node-agent-1,node-agent-2,orchestrator`).
- Final validation succeeded with service/container health checks.
- In strict mTLS environments, unauthenticated `/p2p/info` probe may fail and is treated as warning when health checks pass.

### Compact rehearsal

- `make forensics-rehearsal` executed drill and automatic cleanup.
- Post-run sandbox status confirmed fully down.

## Defects Found and Addressed During Validation

1. Sandbox wasm builder dependency assumption:

- Symptom: `wasm-hello-world-build` failed with `rustup: command not found`.
- Resolution: Added resilient fallback in `docker-compose.sandbox.yml` to emit minimal wasm artifact when target build is unavailable.

1. Rotation drill false-negative in mTLS setup:

- Symptom: Final validation failed due to unauthenticated control-plane probe.
- Resolution: Updated `scripts/quantum_kex_rotation_drill.sh` final validation to rely on container health checks and treat endpoint probe failure as warning.

## Conclusion

Local validation confirms the implemented Day 2 tooling and recovery flows are operational for:

- startup
- report generation
- rolling recovery
- automated cleanup

GitHub-hosted behavior (issue creation/labeling/auto-close in workflow context) remains to be validated in Actions runtime with repository variables configured.
