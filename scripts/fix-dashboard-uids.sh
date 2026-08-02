#!/bin/bash
# Fix datasource UIDs in v2 dashboards that don't all use prometheus-main

set -e

cd /workspaces/Sovereign-Mohawk-Proto

echo "Fixing datasource UIDs in v2 dashboards..."

# List of files with issues
files=(
  "monitoring/grafana/dashboards/v2/v2-10-ops-overview.json"
  "monitoring/grafana/dashboards/v2/v2-11-ops-incidents.json"
  "monitoring/grafana/dashboards/v2/v2-12-security-pqc-compliance.json"
  "monitoring/grafana/dashboards/v2/v2-13-ops-router-command-center.json"
  "monitoring/grafana/dashboards/v2/v2-14-ops-mrc-transport.json"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo -n "Fixing $(basename $file)... "
    # Fix all datasource references
    jq '(.. | objects | select(has("datasource")) | .datasource) |= 
        if type == "object" then 
          .uid = "prometheus-main" 
        else . 
        end' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "✓"
  fi
done

echo "Verifying fixes..."

for file in monitoring/grafana/dashboards/v2/v2-*.json; do
  if [ -f "$file" ]; then
    uid_count=$(jq '[.. | objects | select(has("datasource")) | select(.datasource.uid == "prometheus-main" or .datasource.uid == null)] | length' "$file" 2>/dev/null || echo "0")
    wrong_count=$(jq '[.. | objects | select(has("datasource")) | select(.datasource.uid != "prometheus-main" and .datasource.uid != null)] | length' "$file" 2>/dev/null || echo "0")
    
    if [ "$wrong_count" -eq "0" ]; then
      echo "  ✓ $(basename $file): All datasources fixed"
    else
      echo "  ⚠ $(basename $file): Still has $wrong_count with wrong UID"
    fi
  fi
done

echo "Done!"
