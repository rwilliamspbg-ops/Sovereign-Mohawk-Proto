# Strict Host Go-Live Evidence

Generated (UTC): 2026-03-28T13:02:00Z

## Command

```bash
python3 scripts/validate_go_live_gates.py --host-preflight-mode strict
```

## Result

- `ok: false`
- `host_preflight_mode: strict`
- failure: `host UDP/sysctl tuning preflight failed`

## Interpretation

The strict gate is functioning correctly and is enforcing production kernel UDP/socket minima.
This development container host does not meet production sysctl thresholds.

## Required host tuning

```bash
sudo sysctl -w net.core.rmem_max=8388608
sudo sysctl -w net.core.rmem_default=262144
sudo sysctl -w net.core.wmem_max=8388608
sudo sysctl -w net.core.wmem_default=262144
sudo sysctl --system
```

## Production sign-off note

Re-run strict gate on a tuned production host and archive the updated `results/go-live/go-live-gate-report.json` with this evidence.
