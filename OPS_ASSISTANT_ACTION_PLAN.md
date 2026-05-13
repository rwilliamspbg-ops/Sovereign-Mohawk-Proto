# Ops-Assistant Rendering Issues - ACTION PLAN

**Date**: May 13, 2026  
**Status**: Critical Issues Identified & Partially Fixed  
**Priority**: HIGH - Metrics & dashboards won't render without these fixes

---

## EXECUTIVE SUMMARY

Your ops-assistant isn't rendering metrics/dashboards due to **5 critical configuration issues**:

1. ✅ **FIXED**: Dashboard datasource UID mismatches (prometheus vs prometheus-main)
2. ✅ **FIXED**: Root dashboards not copied to provisioning directory
3. ⚠️ **REQUIRES ACTION**: Grafana API token not properly configured
4. ⚠️ **REQUIRES ACTION**: Prometheus metrics may not exist (if services not running)
5. ⚠️ **REQUIRES ACTION**: CORS/frontend connectivity needs validation

---

## WHAT WAS FIXED ✅

### 1. Dashboard Datasource UID Mismatch
**Issue**: Root dashboards referenced `uid: prometheus` but provisioning defines `uid: prometheus-main`

**Status**: FIXED
- ✅ Root dashboards copied from `/grafana/` → `/monitoring/grafana/dashboards/v2/legacy-*`
- ✅ All datasource references updated to `prometheus-main`
- ✅ V2 dashboards verified and corrected (all 10 files now use correct UID)

**Files affected**:
```
monitoring/grafana/dashboards/v2/
  ✓ legacy-byzantine-detection.json
  ✓ legacy-node-health-overview.json
  ✓ legacy-tokenomics-flow.json
  ✓ v2-00-start-here.json (verified)
  ✓ v2-10-ops-overview.json (corrected)
  ✓ v2-11-ops-incidents.json (corrected)
  ✓ v2-12-security-pqc-compliance.json (corrected)
  ✓ v2-13-ops-router-command-center.json (corrected)
  ✓ v2-14-ops-mrc-transport.json (corrected)
  ✓ v2-20-eng-latency-drilldown.json (verified)
  ✓ v2-21-eng-node-agents.json (verified)
  ✓ v2-22-eng-migration-control-plane.json (verified)
  ✓ v2-30-exec-summary.json (verified)
```

### 2. Dashboard Provisioning
**Status**: READY
- ✅ All dashboards now in correct location: `/monitoring/grafana/dashboards/v2/`
- ✅ Provisioning file configured correctly: [monitoring/grafana/provisioning/dashboards/dashboards.yml](monitoring/grafana/provisioning/dashboards/dashboards.yml)
- ✅ Datasource UID matches provisioning: `uid: prometheus-main`

---

## WHAT STILL NEEDS ACTION ⚠️

### ACTION 1: Set Grafana API Token 🔑 **BLOCKING**

**Current Problem**:
- docker-compose.yml defaults to hardcoded `'admin'` token
- Grafana 11.5.2 may use different credentials or require token generation

**Steps**:

```bash
# Step 1: Generate Grafana API token
docker-compose pull grafana
docker-compose up grafana -d
sleep 5

# Step 2: Create API token for ops-assistant
GRAFANA_TOKEN=$(docker exec grafana grafana-cli admin create-api-token \
  --name "ops-assistant" --role Admin 2>&1 | grep -oE '[a-f0-9]{32}' || echo "admin")

echo "GRAFANA_API_TOKEN=$GRAFANA_TOKEN"

# Step 3: Export token before bringing up ops-assistant
export GRAFANA_API_TOKEN="$GRAFANA_TOKEN"

# Step 4: Update docker-compose.yml (optional, for persistence)
# Change: GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN:-admin}
# To: GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}
```

**File to update**: [docker-compose.yml](docker-compose.yml) (line 369)

```yaml
# BEFORE:
- GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN:-admin}

# AFTER:
- GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}
```

**Or use the prepared fix template**:
```bash
cat .ops-assistant-compose-fix.yml > docker-compose.yml.recommended
# Review and apply changes manually
```

---

### ACTION 2: Verify Prometheus Metrics Exist 📊 **BLOCKING IF EMPTY**

**Current Problem**:
Backend queries specific metric names. If services aren't running or not exporting metrics, all queries will return empty results.

**Required Metric Names** ([prometheus-client.ts](web/ops-assistant/server/prometheus-client.ts#L111)):
```
- mohawk:gradient_submit:total (throughput)
- mohawk:proof_verifications:rate1m
- mohawk:accelerator_ops:rate1m
- mohawk:gradient_submit:failure_rate_5m
- mohawk_fedavg_byzantine_filtered_total
- mohawk_fedavg_round_latency_quantile_ms
- mohawk_operator_op_latency_ms
```

**Verification Steps**:

```bash
# Check if Prometheus is reachable
curl http://localhost:9090/-/ready

# List all mohawk metrics
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | \
  jq '.data[] | select(. | contains("mohawk"))'

# If empty, metrics aren't being exported
# Next steps:
# 1. Verify orchestrator is running on port 9091
# 2. Verify node-agents are running on port 9100
# 3. Verify tpm-metrics exporter on port 9102
# 4. Check prometheus.yml scrape configs (should be OK)
```

**Check Scrape Targets**:
```bash
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# All should show: "health": "up"
```

**If Metrics Missing**:
- Ensure orchestrator, node-agents, and exporter services are running
- Check their logs for export errors
- Verify metrics endpoints: `curl http://localhost:9091/metrics`, etc.

---

### ACTION 3: Update CORS Configuration ⚠️ **OPTIONAL BUT RECOMMENDED**

**Current Configuration**:
```yaml
CORS_ORIGIN=http://localhost:3001,http://localhost:5173
```

**Potential Issues**:
- Frontend may call `localhost:3000` directly (not through port mapping)
- Frontend may run on different Vite port
- Production deployments may have different origins

**Fix**:
```yaml
# Add more flexible CORS config
CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:3001,http://127.0.0.1:5173
```

Or in [docker-compose.yml](docker-compose.yml) (line 370):
```yaml
# BEFORE:
- CORS_ORIGIN=http://localhost:3001,http://localhost:5173

# AFTER:
- CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173
```

---

### ACTION 4: Validate Frontend-Backend Connection 🌐 **RECOMMENDED**

**Test Frontend API Connectivity**:

```bash
# 1. Run validation script (created by fix script)
./scripts/validate-ops-assistant.sh

# 2. Manual checks
curl http://localhost:3001/api/health
curl http://localhost:3001/api/prometheus/health
curl http://localhost:3001/api/grafana/dashboards

# 3. Test from browser console
curl('http://localhost:3001/api/health')
  .then(r => r.json())
  .then(console.log)
  .catch(e => console.error('CORS or connectivity error:', e))
```

---

### ACTION 5: Backend Error Logging 🐛 **OPTIONAL - FOR DEBUGGING**

If issues persist, add detailed logging to backend:

**File**: [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts)

Add around line 170 (in `/api/query` endpoint):
```typescript
app.post('/api/query', async (req: Request, res: Response) => {
  const { query, timeRange = '1h', step = '1m' } = req.body;
  
  console.debug('[/api/query] Received query:', { query, timeRange, step });
  console.debug('[/api/query] Prometheus URL:', prometheusUrl);
  
  // ... rest of endpoint
  
  console.debug('[/api/query] Response data points:', response.data?.data?.result?.length || 0);
});
```

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Configuration (DO NOW)
- [ ] Generate and export `GRAFANA_API_TOKEN`
- [ ] Verify Prometheus metrics exist
- [ ] Update `docker-compose.yml` with token
- [ ] Add `localhost:3000` to CORS_ORIGIN

### Phase 2: Deployment (DO NEXT)
```bash
# With all fixes applied:
docker-compose down
export GRAFANA_API_TOKEN="<your-token>"
docker-compose up -d
```

### Phase 3: Validation (VERIFY)
```bash
./scripts/validate-ops-assistant.sh
```

### Phase 4: Testing (CONFIRM)
- [ ] Open http://localhost:3001 (or 5173 for frontend)
- [ ] Check browser console for errors
- [ ] Verify metrics render in chat
- [ ] Test dashboard access
- [ ] Confirm data appears in UI

---

## QUICK REFERENCE: Critical URLs to Test

| Component | URL | Expected Result |
|-----------|-----|-----------------|
| **Prometheus** | http://localhost:9090 | Status page loads |
| **Prometheus Targets** | http://localhost:9090/api/v1/targets | All targets UP |
| **Prometheus Metrics** | http://localhost:9090/api/v1/label/__name__/values | mohawk* metrics exist |
| **Grafana** | http://localhost:3000 | Grafana login/dashboard loads |
| **Grafana API** | http://localhost:3000/api/datasources | Lists datasources |
| **Ops-Assistant Backend** | http://localhost:3001/api/health | {status: "healthy"} |
| **Backend → Prometheus** | http://localhost:3001/api/prometheus/health | {healthy: true} |
| **Backend Dashboards** | http://localhost:3001/api/grafana/dashboards | Lists dashboards |
| **Backend Query** | http://localhost:3001/api/query/instant?query=up | Returns metric data |

---

## TROUBLESHOOTING

### "No data" in dashboard panels
**Causes** (in order):
1. Prometheus metrics missing (most common)
   - Fix: Start orchestrator/node-agents services
2. Wrong datasource UID
   - Fix: Already done! All dashboards updated
3. Grafana can't connect to Prometheus
   - Fix: Check docker network `mohawk-net`
4. Query syntax error
   - Fix: Test query in Prometheus UI directly

### "Failed to fetch dashboards" error
**Causes**:
1. Grafana API token invalid
   - Fix: Set `GRAFANA_API_TOKEN` env var
2. Grafana service not healthy
   - Fix: `docker logs grafana`
3. CORS issue
   - Fix: Add origin to `CORS_ORIGIN`

### Frontend shows "Cannot connect to backend"
**Causes**:
1. Backend not running or not healthy
   - Fix: `docker-compose up ops-assistant -d`
2. CORS origin mismatch
   - Fix: Update `CORS_ORIGIN` in docker-compose.yml
3. WebSocket connection failed
   - Fix: Check browser DevTools Network tab

### "Prometheus is unreachable" from backend
**Causes**:
1. Prometheus service not running
   - Fix: `docker-compose up prometheus -d`
2. Network issue (services not on `mohawk-net`)
   - Fix: Verify in `docker network inspect mohawk-net`
3. Wrong PROMETHEUS_URL in env vars
   - Fix: Should be `http://prometheus:9090` (not localhost)

---

## FILES CREATED/MODIFIED

### Created Files:
- ✅ [OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md](OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md) - Detailed diagnostics
- ✅ [OPS_ASSISTANT_RECOMMENDED_FIXES.md](OPS_ASSISTANT_RECOMMENDED_FIXES.md) - Implementation guide
- ✅ [.ops-assistant-compose-fix.yml](.ops-assistant-compose-fix.yml) - Reference configuration
- ✅ [scripts/validate-ops-assistant.sh](scripts/validate-ops-assistant.sh) - Validation script
- ✅ [monitoring/grafana/dashboards/v2/legacy-*.json](monitoring/grafana/dashboards/v2/) - Migrated dashboards

### Modified Files:
- ✅ [monitoring/grafana/dashboards/v2/v2-10-ops-overview.json](monitoring/grafana/dashboards/v2/v2-10-ops-overview.json) - Fixed datasources
- ✅ [monitoring/grafana/dashboards/v2/v2-11-ops-incidents.json](monitoring/grafana/dashboards/v2/v2-11-ops-incidents.json) - Fixed datasources
- ✅ [monitoring/grafana/dashboards/v2/v2-12-security-pqc-compliance.json](monitoring/grafana/dashboards/v2/v2-12-security-pqc-compliance.json) - Fixed datasources
- ✅ [monitoring/grafana/dashboards/v2/v2-13-ops-router-command-center.json](monitoring/grafana/dashboards/v2/v2-13-ops-router-command-center.json) - Fixed datasources
- ✅ [monitoring/grafana/dashboards/v2/v2-14-ops-mrc-transport.json](monitoring/grafana/dashboards/v2/v2-14-ops-mrc-transport.json) - Fixed datasources

### Need Manual Update:
- ⚠️ [docker-compose.yml](docker-compose.yml) - Add GRAFANA_API_TOKEN, update CORS_ORIGIN
- ⚠️ [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts) - Optional: Add debug logging

---

## NEXT IMMEDIATE STEPS

1. **Set Grafana token**:
   ```bash
   docker-compose pull grafana
   docker-compose up grafana -d
   sleep 5
   GRAFANA_TOKEN=$(docker exec grafana grafana-cli admin create-api-token --name ops-assistant --role Admin 2>&1 | grep -oE '[a-f0-9]{32}' || echo "admin")
   export GRAFANA_API_TOKEN="$GRAFANA_TOKEN"
   echo "Token: $GRAFANA_API_TOKEN"
   ```

2. **Update docker-compose.yml** (optional but recommended):
   - Line 369: Remove `:-admin` fallback from GRAFANA_API_TOKEN
   - Line 370: Add `http://localhost:3000` to CORS_ORIGIN

3. **Restart services**:
   ```bash
   docker-compose down
   docker-compose up -d
   sleep 10
   ./scripts/validate-ops-assistant.sh
   ```

4. **Test in browser**:
   - Open http://localhost:3001 or http://localhost:5173
   - Check DevTools Console for errors
   - Verify metrics render in UI

---

## SUMMARY

✅ **FIXED** (Automatically):
- Datasource UID mismatches (all dashboards now use `prometheus-main`)
- Root dashboard provisioning (copied to v2 folder)
- Dashboard JSON validation

⚠️ **ACTION REQUIRED** (Before deployment):
- Generate and set `GRAFANA_API_TOKEN`
- Verify Prometheus metrics exist
- Update docker-compose.yml
- Validate connectivity

📊 **EXPECTED OUTCOME** (After fixes):
- All Grafana dashboards load without errors
- Metrics panels render data correctly
- Ops-assistant chat receives metric data
- Backend successfully queries Prometheus
- Frontend displays metrics in real-time

---

## For More Information

See:
- [OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md](OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md) - Detailed technical diagnostics
- [OPS_ASSISTANT_RECOMMENDED_FIXES.md](OPS_ASSISTANT_RECOMMENDED_FIXES.md) - Implementation details
- [.github/workflows/monitoring-smoke-gate.yml](.github/workflows/monitoring-smoke-gate.yml) - CI/CD configuration
