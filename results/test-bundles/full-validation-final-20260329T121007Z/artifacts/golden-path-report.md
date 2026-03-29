# Golden Path E2E Report

The end-to-end golden path executed stack startup, readiness checks, integration tests, and metric assertions.

| Check | Result |
| --- | --- |
| readiness_gate_ok | PASS |
| internal_runtime_tests_ok | PASS |
| pyapi_integration_tests_ok | PASS |
| prometheus_up_query_ok | PASS |
| consensus_ratio_query_ok | PASS |

## Artifacts

- results/readiness/readiness-report.json
- results/go-live/golden-path-report.json
- /tmp/mohawk_golden_internal_tests.log
- /tmp/mohawk_golden_pyapi_tests.log
