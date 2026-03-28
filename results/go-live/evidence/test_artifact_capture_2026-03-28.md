# Test and Artifact Capture Summary (2026-03-28)

## Scope

This capture records the end-to-end validation and artifact generation run executed on 2026-03-28.

## Test Execution Results

| Test Area | Command | Result |
| --- | --- | --- |
| Go test suite | `make test` | PASS |
| Python SDK tests | `make test-python-sdk` | PASS (29 passed) |
| Golden-path E2E | `make golden-path-e2e` | PASS |
| Go-live gate (advisory) | `make go-live-gate-advisory` | PASS (host tuning warning expected in advisory mode) |
| Go-live gate (strict) | `make go-live-gate-strict` | FAIL (expected on non-production host without required sysctl tuning) |
| Failure-injection latency validation | `make failure-injection-latency-check` | PASS |
| TPM closure validator | `make tpm-attestation-closure-check` | FAIL (expected: Windows/macOS evidence pending) |

## Generated / Refreshed Artifacts

### Go-Live and E2E

- `results/go-live/golden-path-report.json`
- `results/go-live/golden-path-report.md`
- `results/go-live/go-live-gate-report.json`
- `results/go-live/evidence/go_live_gate_advisory_2026-03-28.json`
- `results/go-live/evidence/go_live_gate_strict_2026-03-28.json`

### Latency and Performance

- `results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json`
- `results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md`
- `results/metrics/release_performance_evidence.md`

### TPM Closure State

- `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json`
- `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md`

## Remaining Blocking Conditions

- TPM cross-platform closure still pending for Windows and macOS evidence.
- Strict host gate requires production sysctl tuning to pass on this host class.

## Conclusion

All currently runnable test suites and artifact capture workflows were executed and recorded. Remaining failures are expected and correspond to known GA blockers, not unexpected regressions.
