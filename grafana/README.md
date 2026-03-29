# Pre-Packaged Grafana Dashboards

This folder provides quick-import dashboard JSON files for common operations views:

- node-health-overview.json
- byzantine-detection.json
- tokenomics-flow.json

## Import steps

1. Open Grafana at http://localhost:3000.
2. Go to Dashboards -> New -> Import.
3. Upload one of the JSON files from this folder.
4. Select the Prometheus datasource used by your stack.

These JSONs are intentionally compact for fast local/testnet setup and can be extended for team-specific drilldowns.
