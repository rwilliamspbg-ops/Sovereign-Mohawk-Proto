# Ops-Assistant Fix - Quick Reference Card

## ⚡ CRITICAL ACTIONS (Do These NOW)

### 1️⃣ Generate Grafana API Token
```bash
# Step 1: Start Grafana if not running
docker-compose up grafana -d

# Step 2: Wait for startup
sleep 5

# Step 3: Generate token
export GRAFANA_API_TOKEN=$(docker exec grafana grafana-cli admin create-api-token \
  --name "ops-assistant" --role Admin 2>&1 | grep -oE '[a-f0-9]{32}' || echo "admin")

  # Step 4: Verify token
  echo "Token: $GRAFANA_API_TOKEN"
  ```

  ### 2️⃣ Verify Prometheus Metrics Exist
  ```bash
  # Check if metrics are present
  curl -s 'http://localhost:9090/api/v1/label/__name__/values' | \
    jq '.data[] | select(. | contains("mohawk"))' | head

    # Should show metrics like:
    # "mohawk:gradient_submit:total"
    # "mohawk_fedavg_byzantine_filtered_total"
    # If empty → Services not running or not exporting metrics
    ```

    ### 3️⃣ Update docker-compose.yml
    **Make these 2 changes:**

    **Change 1** (Line ~369):
    ```diff
    - GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN:-admin}
    + GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}
    ```

    **Change 2** (Line ~370):
    ```diff
    - CORS_ORIGIN=http://localhost:3001,http://localhost:5173
    + CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173
    ```

    ### 4️⃣ Restart Services
    ```bash
    cd /workspaces/Sovereign-Mohawk-Proto

    # Set token
    export GRAFANA_API_TOKEN="<your-token-from-step-1>"

    # Restart
    docker-compose down
    docker-compose up -d

    # Wait for startup
    sleep 10
    ```

    ### 5️⃣ Validate Everything Works
    ```bash
    ./scripts/validate-ops-assistant.sh
    ```

    ---

    ## 📋 Validation Checklist

    ```bash
    # 1. Prometheus healthy?
    curl http://localhost:9090/-/ready && echo "✓ OK" || echo "✗ FAIL"

    # 2. Grafana healthy?
    curl http://localhost:3000/api/health && echo "✓ OK" || echo "✗ FAIL"

    # 3. Ops-assistant healthy?
    curl http://localhost:3001/api/health && echo "✓ OK" || echo "✗ FAIL"

    # 4. Backend can reach Prometheus?
    curl http://localhost:3001/api/prometheus/health && echo "✓ OK" || echo "✗ FAIL"

    # 5. Metrics exist?
    METRICS=$(curl -s 'http://localhost:9090/api/v1/label/__name__/values' | \
      jq '[.data[] | select(. | contains("mohawk"))] | length')
      echo "Mohawk metrics found: $METRICS"

      # 6. Dashboards accessible?
      DASHBOARDS=$(curl -s http://localhost:3001/api/grafana/dashboards | jq '.dashboards | length')
      echo "Dashboards found: $DASHBOARDS"

      # 7. Query works?
      curl -s http://localhost:3001/api/query/instant?query=up | jq '.data.result | length'
      ```

      ---

      ## 🔧 Troubleshooting Quick Fixes

      ### Issue: "Prometheus is unreachable"
      ```bash
      # Check if Prometheus is up
      curl http://localhost:9090/-/ready

      # Check if service is on network
      docker network inspect mohawk-net | grep prometheus

      # Restart Prometheus
      docker-compose up prometheus -d
      ```

      ### Issue: "Can't connect to Grafana API"
      ```bash
      # Test API with current token
      curl -H "Authorization: Bearer admin" http://localhost:3000/api/datasources

      # If fails, regenerate token (see Step 1 above)

      # Check Grafana logs
      docker logs grafana | tail -20
      ```

      ### Issue: "No data in dashboard panels"
      ```bash
      # Check if metrics exist
      curl 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length'

      # If 0, start services:
      docker-compose up orchestrator node-agent tpm-metrics -d

      # Check metric scrape targets
      curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'
      ```

      ### Issue: "CORS error in browser console"
      ```bash
      # Check CORS config in docker-compose.yml
      grep CORS_ORIGIN docker-compose.yml

      # Update if needed (see Step 3 above)

      # Restart ops-assistant
      docker-compose up ops-assistant -d
      ```

      ### Issue: Frontend shows "Cannot fetch dashboards"
      ```bash
      # Test backend dashboard endpoint
      curl http://localhost:3001/api/grafana/dashboards | jq .

      # If auth error, regenerate token (see Step 1)

      # Check logs
      docker logs ops-assistant | grep -i grafana | tail -10
      ```

      ---

      ## 📊 Quick Status Check (All-in-One)
      ```bash
      #!/bin/bash
      echo "=== Ops-Assistant Status ==="
      echo -n "Prometheus: "
      curl -s http://localhost:9090/-/ready > /dev/null && echo "✓" || echo "✗"
      echo -n "Grafana: "
      curl -s http://localhost:3000/api/health > /dev/null && echo "✓" || echo "✗"
      echo -n "Ops-Assistant: "
      curl -s http://localhost:3001/api/health > /dev/null && echo "✓" || echo "✗"
      echo -n "Backend→Prometheus: "
      curl -s http://localhost:3001/api/prometheus/health | jq '.healthy' | grep -q "true" && echo "✓" || echo "✗"
      echo -n "Metrics Available: "
      METRICS=$(curl -s 'http://localhost:9090/api/v1/label/__name__/values' | jq '[.data[] | select(. | contains("mohawk"))] | length')
      echo "$METRICS"
      echo -n "Dashboards: "
      DASHES=$(curl -s http://localhost:3001/api/grafana/dashboards | jq '.dashboards | length' 2>/dev/null || echo "error")
      echo "$DASHES"
      ```

      ---

      ## 📁 Key Files

      | File | Purpose | Status |
      |------|---------|--------|
      | [docker-compose.yml](docker-compose.yml) | Service configuration | ⚠️ **Needs manual update** |
      | [monitoring/grafana/provisioning/datasources/prometheus.yml](monitoring/grafana/provisioning/datasources/prometheus.yml) | Grafana datasource config | ✅ OK |
      | [monitoring/grafana/dashboards/v2/](monitoring/grafana/dashboards/v2/) | Dashboard files | ✅ **FIXED** |
      | [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts) | Backend API | ✅ OK |
      | [scripts/validate-ops-assistant.sh](scripts/validate-ops-assistant.sh) | Validation script | ✅ Created |

      ---

      ## 🎯 5-Minute Fix (If You Just Want It Working)

      ```bash
      # 1. Generate token
      export GRAFANA_API_TOKEN=$(docker exec grafana grafana-cli admin \
        create-api-token --name ops-assistant --role Admin 2>&1 | \
          grep -oE '[a-f0-9]{32}' || echo "admin")

          # 2. Edit docker-compose.yml (2 lines):
          sed -i "s/\${GRAFANA_API_TOKEN:-admin}/\${GRAFANA_API_TOKEN}/" docker-compose.yml
          sed -i "s|localhost:3001,localhost:5173|localhost:3000,localhost:3001,localhost:5173|" docker-compose.yml

          # 3. Restart
          docker-compose down && sleep 2 && docker-compose up -d && sleep 10

          # 4. Validate
          ./scripts/validate-ops-assistant.sh
          ```

          ---

          ## 📞 Need Help?

          1. **Full diagnostics**: See [OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md](OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md)
          2. **Implementation guide**: See [OPS_ASSISTANT_RECOMMENDED_FIXES.md](OPS_ASSISTANT_RECOMMENDED_FIXES.md)
          3. **Action plan**: See [OPS_ASSISTANT_ACTION_PLAN.md](OPS_ASSISTANT_ACTION_PLAN.md)
          4. **Validation**: Run `./scripts/validate-ops-assistant.sh`

          ---

          ## ✅ SUCCESS INDICATORS

          After fixes, you should see:
          - [ ] All validation checks pass (✓ marks)
          - [ ] Metrics appear in dashboard panels
          - [ ] Chat integration shows real-time data
          - [ ] No CORS errors in browser console
          - [ ] No connection errors in service logs

          ---

          **Last Updated**: May 13, 2026  
          **Status**: ✅ READY TO FIX (4 of 5 issues addressed, 1 awaiting Grafana startup)
          