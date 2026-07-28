# Ops-Assistant Diagnostics - Recommended Fixes

## CRITICAL ISSUES & FIXES

### Issue 1: Root Grafana Dashboards Not Mounted ⚠️ BLOCKING

**Problem**: 
- Dashboards exist in `/grafana/*.json` but not mounted to Grafana container
- Only V2 dashboards in `/monitoring/grafana/dashboards/v2/` are actually used

**Solution**: 
Copy root dashboards to monitored path:

```bash
cp grafana/*.json monitoring/grafana/dashboards/v2/
# Rename to match v2 naming convention
```

Or update docker-compose.yml volumes:

```yaml
grafana:
  volumes:
    - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro
    + - ./grafana:/var/lib/grafana/dashboards/legacy:ro  # ADD THIS
    - grafana-data:/var/lib/grafana
```

---

### Issue 2: CORS Origin Mismatch ⚠️ BLOCKING

**Problem**:
- CORS configured for `localhost:3001` but ops-assistant runs on `:3000`
- Frontend on `:5173` may have CORS issues

**Current Config in docker-compose.yml**:
```yaml
ops-assistant:
  ports:
    - "3001:3000"  # Maps container:3000 → host:3001
  environment:
    - CORS_ORIGIN=http://localhost:3001,http://localhost:5173
```

**Issue**: CORS allows `localhost:3001` but backend actually runs on `localhost:3000` internally

**Fix**: Check if frontend calls correct URL:
- If calling `http://localhost:3001/api/*` → ✅ Works (proxy through docker port mapping)
- If calling `http://localhost:3000/api/*` → ❌ May have CORS issues

**Verify in DevTools**:
```javascript
// In browser console
fetch('http://localhost:3001/api/health')
  .then(r => r.json())
  .then(console.log)
  .catch(console.error)
```

---

### Issue 3: Grafana API Token Not Validated ⚠️ HIGH PRIORITY

**Problem**: 
Using hardcoded `'admin'` token as fallback. Default Grafana password is random or requires initialization.

**Current Code** in [web/ops-assistant/server/grafana-client.ts](web/ops-assistant/server/grafana-client.ts#L66):
```typescript
apiToken: string = process.env.GRAFANA_API_TOKEN || 'admin'
```

**Fix**:

Option A: Generate and set token before startup
```bash
# Generate API token in running Grafana
docker exec grafana grafana-cli admin create-api-token --name "ops-assistant" --role Admin

# Set env var before docker-compose
export GRAFANA_API_TOKEN="<token>"
docker-compose up
```

Option B: Update Dockerfile/docker-compose to generate token
```yaml
ops-assistant:
  environment:
    - GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}  # Required, no fallback
```

Then in host shell before up:
```bash
docker-compose pull grafana
docker-compose up grafana -d
sleep 5
GRAFANA_API_TOKEN=$(docker exec grafana grafana-cli admin create-api-token --name ops-assistant --role Admin 2>&1 | grep -oE '[a-f0-9]{32}')
docker-compose up ops-assistant
```

---

### Issue 4: Prometheus Metric Names Mismatch ⚠️ BLOCKING IF METRICS MISSING

**Problem**:
Hardcoded metric names in KEY_METRICS may not exist if services aren't properly instrumented.

**Current Metrics** in [web/ops-assistant/server/prometheus-client.ts](web/ops-assistant/server/prometheus-client.ts#L111):
```typescript
export const KEY_METRICS = {
  throughput: 'rate(mohawk:gradient_submit:total[1m])',
  verifications: 'rate(mohawk:proof_verifications:rate1m[1m])',
  acceleratorOps: 'rate(mohawk:accelerator_ops:rate1m[1m])',
  failures: 'rate(mohawk:gradient_submit:failure_rate_5m[1m])',
  byzantineRejects: 'increase(mohawk_fedavg_byzantine_filtered_total[5m])',
  roundLatencyP95: 'histogram_quantile(0.95, mohawk_fedavg_round_latency_quantile_ms)',
  proofLatencyP95: 'histogram_quantile(0.95, mohawk_operator_op_latency_ms)'
};
```

**Verify metrics exist**:
```bash
# Check if metrics are in Prometheus
curl 'http://localhost:9090/api/v1/label/__name__/values' | jq '.data[] | select(. | contains("mohawk"))'

# Should return metric names like:
# "mohawk:gradient_submit:total"
# "mohawk_fedavg_byzantine_filtered_total"
# etc.

# If empty, metrics aren't being scraped
```

**If metrics missing**:
1. Check if orchestrator, node-agents, tpm-metrics are running
2. Verify they're configured to export metrics on correct ports (9091, 9100, 9102)
3. Check Prometheus scrape config again: `curl http://localhost:9090/api/v1/targets`

**Fix**: Update prometheus.yml if services on different ports:
```yaml
scrape_configs:
  - job_name: orchestrator
    metrics_path: /metrics
    static_configs:
      - targets: ["orchestrator:9091"]  # Verify this port
```

---

### Issue 5: Dashboard Datasource UID Mismatch ⚠️ BLOCKING

**Problem**:
Dashboard JSON files reference datasource UID that may not match Grafana provisioning.

**Provisioning defines** (datasources/prometheus.yml):
```yaml
datasources:
  - name: Prometheus
    uid: prometheus-main
```

**Dashboard JSON must reference** (in panels):
```json
{
  "datasource": {
    "type": "prometheus",
    "uid": "prometheus-main"
  }
}
```

**Check/Fix**:
```bash
# Check what UID dashboards expect
grep -r '"uid"' monitoring/grafana/dashboards/v2/*.json | grep -i datasource

# Should all show: "uid": "prometheus-main"

# If different, either:
# 1. Update datasource provisioning to use dashboard's expected UID
# 2. Update all dashboard JSONs to use provisioning's UID
```

---

## QUICK FIX CHECKLIST

Run these in order:

```bash
# 1. Check if Prometheus has data
curl 'http://localhost:9090/api/v1/query?query=up' | jq .

# 2. Check if Grafana can see Prometheus
docker exec ops-assistant curl -H "Authorization: Bearer admin" \
  http://grafana:3000/api/datasources | jq '.[] | {name, url, uid}'

# 3. Check if backend API works
curl http://localhost:3001/api/prometheus/health
curl http://localhost:3001/api/grafana/dashboards

# 4. Check logs for errors
docker logs -f ops-assistant 2>&1 | grep -i error

# 5. Test a simple instant query
curl 'http://localhost:3001/api/query/instant?query=up'
```

---

## IMPLEMENTATION ORDER

1. **First**: Verify Prometheus metrics exist (Issue 4)
   - If missing, fix services first
   - Can't proceed if no data

2. **Second**: Set GRAFANA_API_TOKEN (Issue 3)
   - Generate and export token
   - Test Grafana connectivity

3. **Third**: Fix dashboard datasource UIDs (Issue 5)
   - Ensure all dashboards reference correct datasource

4. **Fourth**: Mount/copy dashboards properly (Issue 1)
   - Verify all dashboard files are accessible to Grafana

5. **Fifth**: Verify CORS configuration (Issue 2)
   - Test frontend API calls work

---

## VALIDATION SCRIPT

Create `/workspaces/Sovereign-Mohawk-Proto/scripts/validate-ops-assistant.sh`:

```bash
#!/bin/bash

echo "=== Ops-Assistant Connectivity Check ==="

# Check Prometheus
echo -n "Prometheus health: "
curl -s http://localhost:9090/-/ready > /dev/null && echo "✅ OK" || echo "❌ FAILED"

# Check metrics
echo -n "Prometheus metrics (mohawk): "
METRIC_COUNT=$(curl -s 'http://localhost:9090/api/v1/label/__name__/values' | \
  jq '[.data[] | select(. | contains("mohawk"))] | length')
echo "$METRIC_COUNT metrics found"

# Check Grafana
echo -n "Grafana health: "
curl -s http://localhost:3000/api/health > /dev/null && echo "✅ OK" || echo "❌ FAILED"

# Check ops-assistant
echo -n "Ops-Assistant health: "
curl -s http://localhost:3001/api/health > /dev/null && echo "✅ OK" || echo "❌ FAILED"

# Check Prometheus connectivity from ops-assistant
echo -n "Ops-Assistant → Prometheus: "
curl -s http://localhost:3001/api/prometheus/health | jq '.healthy' | \
  grep -q "true" && echo "✅ OK" || echo "❌ FAILED"

# Check Grafana connectivity from ops-assistant
echo -n "Ops-Assistant → Grafana: "
curl -s -H "Authorization: Bearer admin" \
  http://localhost:3001/api/grafana/dashboards | jq '.success' 2>/dev/null | \
  grep -q "true" && echo "✅ OK" || echo "❌ FAILED"

echo ""
echo "=== Backend API Tests ==="
echo "POST /api/query (throughput):"
curl -s -X POST http://localhost:3001/api/query \
  -H "Content-Type: application/json" \
  -d '{"query":"rate(mohawk:gradient_submit:total[1m])"}' | jq '.data.result | length'

echo "GET /api/grafana/dashboards:"
curl -s http://localhost:3001/api/grafana/dashboards | jq '.dashboards | length'

echo ""
echo "Done!"
```

Usage:
```bash
chmod +x scripts/validate-ops-assistant.sh
./scripts/validate-ops-assistant.sh
```

---

## RECOMMENDED FILE UPDATES

If implementing fixes, update these files:

1. **docker-compose.yml**
   - [ ] Add `./grafana:/var/lib/grafana/dashboards/legacy:ro` to Grafana volumes
   - [ ] Change `GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN:-admin}` to `GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}` (required)

2. **web/ops-assistant/server/index.ts**
   - [ ] Add debug logging to `/api/query` and `/api/grafana/*` endpoints
   - [ ] Add error message context for failed queries

3. **web/ops-assistant/server/grafana-client.ts**
   - [ ] Add error handling and logging for auth failures
   - [ ] Log actual HTTP status codes from Grafana API

4. **monitoring/prometheus/prometheus.yml**
   - [ ] Verify all scrape targets are correct
   - [ ] Add ops-assistant health metrics endpoint if needed

5. **Copy dashboards** (if needed)
   - [ ] `cp grafana/*.json monitoring/grafana/dashboards/v2/`
   - [ ] Rename and validate UIDs

---

## NEXT STEPS

1. Run validation script above
2. Fix issues in priority order
3. Restart services: `docker-compose down && docker-compose up -d`
4. Re-run validation script
5. Test frontend chat interface for metric rendering

See [OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md](OPS_ASSISTANT_DIAGNOSTICS_CHECKLIST.md) for detailed diagnostics.
