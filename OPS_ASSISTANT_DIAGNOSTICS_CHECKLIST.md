# Ops-Assistant Metrics & Dashboard Rendering - Diagnostics Checklist

**Date**: May 13, 2026  
**Status**: Investigation Report  
**Issue**: Ops-assistant not rendering metrics/dashboards or replying with correct info

---

## QUICK DIAGNOSTICS

### ✅ Configuration Found

| Component | Config | Location | Status |
|-----------|--------|----------|--------|
| **Prometheus URL** | `http://prometheus:9090` | docker-compose.yml (ops-assistant service) | ✅ Correct |
| **Grafana URL** | `http://grafana:3000` | docker-compose.yml (ops-assistant service) | ✅ Correct |
| **Grafana API Token** | Defaults to `admin` | docker-compose.yml | ⚠️ Using default |
| **CORS Origins** | `http://localhost:3001,http://localhost:5173` | docker-compose.yml | ✅ Set |
| **Network** | `mohawk-net` | docker-compose.yml | ✅ All services on same net |
| **Service Dependencies** | `depends_on: [prometheus, grafana]` with health checks | docker-compose.yml | ✅ Correct |

---

## 1. PROMETHEUS CONNECTIVITY / NO METRICS

### Potential Issues Found

#### 1.1 Metric Names Mismatch ⚠️ **CRITICAL**
**File**: [web/ops-assistant/server/prometheus-client.ts](web/ops-assistant/server/prometheus-client.ts#L111)

```javascript
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

**Issue**: These metric names are hardcoded but may not exist in Prometheus if:
- Orchestrator isn't running or isn't exposing metrics
- Node agents aren't configured with proper metric names
- Recording rules haven't been applied

**Fix**: Verify metrics exist in Prometheus:
```bash
# Check Prometheus status
curl http://localhost:9090/-/ready

# List all metrics
curl 'http://localhost:9090/api/v1/label/__name__/values' | grep -i mohawk
```

---

#### 1.2 Prometheus Service Configuration
**File**: [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml)

**Scrape Configs Found**:
- ✅ orchestrator:9091
- ✅ tpm-metrics:9102
- ✅ node-agents (node-agent:9100, node-agent-{1..3}:9100)
- ✅ pyapi-exporter:9104
- ✅ federated-router:8088
- ✅ ops-assistant:3000

**Status Check**:
```bash
# Check all scrape targets
curl http://localhost:9090/api/v1/targets

# Check if metrics are scraping
docker logs prometheus | grep -E 'error|fail|dropped|invalid'
```

---

#### 1.3 Query Error Handling 
**File**: [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts#L164-L195)

Endpoints that query Prometheus:
- `POST /api/query` - Range queries
- `GET /api/query/instant` - Instant queries
- `GET /api/prometheus/key-metrics` - Returns metric names

**Potential Issues**:
- ⚠️ `parseTimeRange()` function called but not shown - need to verify it handles all formats
- ⚠️ Step parameter default `'1m'` may be too granular for long time ranges
- ⚠️ Timeout set to 10s - may be too short for large result sets

**Recommendation**: 
```javascript
// In /api/query endpoint - verify parseTimeRange exists and handles:
// - "1h", "24h", "7d", "30d"
// - Relative times like "30m ago"
// - Unix timestamps
```

---

### Health Check Status

**Endpoint Available**:
- `GET /api/prometheus/health`
- Returns: `{ healthy: boolean, message: string }`

**To Test**:
```bash
curl http://localhost:3001/api/prometheus/health
```

---

## 2. GRAFANA / DASHBOARD RENDERING ISSUES

### ✅ Dashboard Configuration

**Files Located**:
- Root dashboards: [grafana/*.json](grafana/) (3 files: byzantine-detection, tokenomics-flow, node-health-overview)
- V2 Provisioned dashboards: [monitoring/grafana/dashboards/v2/](monitoring/grafana/dashboards/v2/) (10 files)

**Provisioning Config**:
- **File**: [monitoring/grafana/provisioning/dashboards/dashboards.yml](monitoring/grafana/provisioning/dashboards/dashboards.yml)
- **Folder**: `v2` (folderUid: afj06payx6g3kb)
- **Path in Container**: `/var/lib/grafana/dashboards/v2`

---

### ⚠️ POTENTIAL ISSUES DETECTED

#### 2.1 Dashboard File Mismatch
- **Root dashboards** (`/grafana/*.json`) are NOT mounted in docker-compose
- **V2 dashboards** (`/monitoring/grafana/dashboards/v2/`) ARE mounted correctly

**Current docker-compose Volumes**:
```yaml
volumes:
  - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
  - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro
  - grafana-data:/var/lib/grafana
```

**Issue**: Root `/grafana/*.json` files are never loaded into Grafana container!

**Fix**: Either:
1. Copy root dashboards to `monitoring/grafana/dashboards/v2/`
2. OR Update docker-compose to mount: `- ./grafana:/var/lib/grafana/dashboards/root:ro`

---

#### 2.2 Grafana Client Configuration
**File**: [web/ops-assistant/server/grafana-client.ts](web/ops-assistant/server/grafana-client.ts#L60)

```typescript
constructor(
  baseUrl: string = 'http://grafana:3000',
  apiToken: string = process.env.GRAFANA_API_TOKEN || 'admin'
)
```

**Issues**:
- ⚠️ Using hardcoded `'admin'` token as fallback
- ⚠️ `GRAFANA_API_TOKEN` env var set in docker-compose but defaults to `'admin'`
- ❓ No token validation before requests

**In Grafana 11.5.2**:
- Default admin password is usually random or needs initialization
- Using `'admin'` token may fail after Grafana setup changes

**Fix**:
```bash
# Check current Grafana API token situation
docker logs grafana | grep -i "token\|auth"

# Or generate new admin token in running Grafana
docker exec grafana grafana-cli admin create-api-token --name ops-assistant --role Admin
```

---

#### 2.3 Datasource UID Mismatch ⚠️ **CRITICAL**
**File**: [monitoring/grafana/provisioning/datasources/prometheus.yml](monitoring/grafana/provisioning/datasources/prometheus.yml#L3)

```yaml
datasources:
  - name: Prometheus
    uid: prometheus-main
    url: http://prometheus:9090
```

**Dashboards in v2/ folder**:
- May reference Prometheus datasource as `prometheus` or other UIDs
- Must match the UID `prometheus-main` for queries to work

**Check**:
1. Open any dashboard JSON file: [v2-00-start-here.json](monitoring/grafana/dashboards/v2/v2-00-start-here.json)
2. Search for `"datasource"` field in panels
3. Verify it matches `"uid": "prometheus-main"`

**Example Issue**:
```json
// If dashboard has:
{ "datasource": { "uid": "prometheus" } }
// But provisioning defines: uid: prometheus-main
// → Query will fail silently
```

---

#### 2.4 Dashboard Endpoint Issues
**File**: [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts#L222-L255)

Endpoints:
- `GET /api/grafana/dashboards` - Lists all dashboards
- `GET /api/grafana/dashboards/:uid` - Gets dashboard by UID
- `GET /api/grafana/search` - Searches dashboards

**Potential Issues**:
- Error responses return errors but frontend may not handle them
- ⚠️ Empty result sets returned silently (e.g., `return []`)
- No distinction between auth failure vs. no results

**Recommendation**: Add error context:
```typescript
async getDashboards(): Promise<Dashboard[]> {
  try {
    // ... existing code
  } catch (error) {
    console.error('[GrafanaClient] Auth/connectivity issue:', error);
    // Log actual error for diagnostics
    throw error; // Don't silently return []
  }
}
```

---

## 3. DOCKER COMPOSE / ENVIRONMENT ISSUES

### ✅ Verified Configuration

**Service Startup Order**:
- ✅ prometheus starts first (no depends_on)
- ✅ grafana depends_on prometheus → service_healthy
- ✅ ops-assistant depends_on [prometheus, grafana] → service_healthy

**Health Checks**:
- ✅ prometheus: `curl -fsS http://localhost:9090/-/healthy`
- ✅ grafana: `curl -fsS http://localhost:3000/api/health`
- ✅ ops-assistant: `curl -f http://localhost:3000/api/health`

**Network**:
- ✅ All services on `mohawk-net`
- ✅ Service discovery via DNS (e.g., `http://prometheus:9090`)

**Resource Limits**:
```yaml
ops-assistant:
  limits: 512m memory, 0.5 CPU
  reservations: 256m memory, 0.25 CPU
```

---

### ⚠️ Environment Variable Issues

**In docker-compose.yml ops-assistant service**:
```yaml
environment:
  - PROMETHEUS_URL=http://prometheus:9090
  - GRAFANA_URL=http://grafana:3000
  - GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN:-admin}  # ← Falls back to 'admin'
```

**Problem 1**: If `GRAFANA_API_TOKEN` env var not set in host, defaults to `'admin'`
- This may not match actual token in Grafana

**Problem 2**: No validation that these URLs are reachable at startup

**Solution**:
```bash
# Before docker-compose up, set:
export GRAFANA_API_TOKEN=$(docker exec grafana grafana-cli admin create-api-token --name ops-assistant --role Admin 2>/dev/null || echo "admin")

# Or validate in server startup:
# Check connectivity to Prometheus/Grafana before starting
```

---

## 4. FRONTEND / COPILOTKIT INTEGRATION

### API Configuration
**File**: [web/ops-assistant/client/config.ts](web/ops-assistant/client/config.ts)

**API URL Resolution**:
```typescript
// Uses VITE_API_BASE_URL env var, defaults to window.location.origin
// In dev: http://localhost:5173 (frontend) → calls http://localhost:5173/api/*
// In Docker: http://ops-assistant:3000 → calls http://ops-assistant:3000/api/*
```

**CORS Configuration**:
```yaml
# ops-assistant backend:
CORS_ORIGIN=http://localhost:3001,http://localhost:5173
```

**Potential Issues**:
- ⚠️ CORS origin is `localhost:3001` but ops-assistant runs on `:3000`
- ⚠️ Frontend dev port `5173` (Vite default) is in CORS but frontend might be on different port
- ⚠️ In production, `window.location.origin` might differ

**Recommendation**:
```bash
# Check actual frontend/backend origins
curl -I http://localhost:3001/api/health  # Frontend proxy
curl -I http://localhost:3000/api/health  # Backend direct
```

---

### WebSocket Connection
**File**: [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts#L87-L113)

- ✅ WebSocket manager active
- ✅ Clients registered with session IDs
- ✅ Welcome message sent

**Frontend Hook**: [web/ops-assistant/client/hooks/useWebSocket.ts](web/ops-assistant/client/hooks/useWebSocket.ts)

**Potential Issues**:
- ⚠️ WebSocket URL derived from API base URL
- ⚠️ If API URL is wrong, WebSocket fails silently

---

## 5. QUICK DIAGNOSTICS COMMANDS

### Run These Immediately

```bash
# 1. Check Prometheus health and targets
curl http://localhost:9090/-/ready
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# 2. Verify metrics exist
curl 'http://localhost:9090/api/v1/label/__name__/values?match={job=~"orchestrator|tpm-metrics"}' | jq '.data[] | select(. | contains("mohawk"))'

# 3. Check Grafana API access
curl -H "Authorization: Bearer admin" http://localhost:3000/api/datasources | jq '.[] | {name: .name, uid: .uid, url: .url, type: .type}'

# 4. Test ops-assistant backend
curl http://localhost:3001/api/health
curl http://localhost:3001/api/prometheus/health
curl http://localhost:3001/api/grafana/dashboards

# 5. Check logs for errors
docker logs ops-assistant | tail -50
docker logs prometheus | tail -50
docker logs grafana | tail -50

# 6. Verify network
docker network inspect mohawk-net | jq '.Containers[] | {name: .Name, ipv4: .IPv4Address}'
```

---

## 6. ROOT CAUSE ANALYSIS

### Most Likely Causes (in order of probability)

| # | Issue | Evidence | Fix |
|---|-------|----------|-----|
| 1 | **Prometheus metrics missing** | hardcoded KEY_METRICS names may not exist | Verify `curl 'http://localhost:9090/api/v1/metrics/find'` includes mohawk_* metrics |
| 2 | **Grafana auth token failure** | Using hardcoded `'admin'` token | Set proper `GRAFANA_API_TOKEN` env var before docker-compose up |
| 3 | **Datasource UID mismatch** | Dashboard UIDs != provisioning UID | Check dashboard JSONs for correct datasource UID: `prometheus-main` |
| 4 | **CORS origin mismatch** | Frontend can't call backend API | Verify frontend actually calls `localhost:3001` not `localhost:3000` |
| 5 | **Dashboard not provisioned** | Root `/grafana/*.json` not mounted | Copy to `/monitoring/grafana/dashboards/v2/` or update docker-compose volumes |

---

## 7. STEP-BY-STEP RESOLUTION

### Step 1: Verify Prometheus Metrics
```bash
docker exec prometheus curl http://localhost:9090/api/v1/query?query=up
# Should return all scrape targets with value 1
```

### Step 2: Verify Grafana Datasource
```bash
docker exec ops-assistant curl -H "Authorization: Bearer admin" \
  http://grafana:3000/api/datasources/uid/prometheus-main
# Should return datasource details, not 404
```

### Step 3: Test API Endpoints Directly
```bash
# Test instant query
curl -X GET 'http://localhost:3001/api/query/instant?query=up'

# Test dashboard list
curl http://localhost:3001/api/grafana/dashboards
```

### Step 4: Check Frontend Console
- Open browser: http://localhost:5173 or http://localhost:3001
- Open DevTools → Console and Network tabs
- Look for failed API calls (red X in Network tab)
- Check console errors

### Step 5: Enable Debug Logging
- Add to [web/ops-assistant/server/index.ts](web/ops-assistant/server/index.ts):
  ```typescript
  console.debug('[API] Query endpoint:', req.body);
  console.debug('[API] Prometheus response:', response.data);
  ```

---

## 8. IMPLEMENTATION FIXES

### Critical Fixes Needed

**Fix 1**: Verify Prometheus Metrics Availability
- [ ] Check if orchestrator is running and exposing metrics
- [ ] Verify metric names: `mohawk:gradient_submit:total`, etc.
- [ ] If missing, update KEY_METRICS to match actual metric names

**Fix 2**: Set GRAFANA_API_TOKEN Properly
- [ ] Before `docker-compose up`, generate token
- [ ] Export `GRAFANA_API_TOKEN` in environment
- [ ] Update docker-compose to require it

**Fix 3**: Validate Datasource UIDs
- [ ] Check all dashboard JSONs
- [ ] Ensure datasource.uid = `prometheus-main`
- [ ] Or update provisioning to match dashboard UUIDs

**Fix 4**: Update Dashboard Mount Path
- [ ] Copy `/grafana/*.json` to `/monitoring/grafana/dashboards/v2/`
- [ ] Or update docker-compose volumes

**Fix 5**: CORS Configuration
- [ ] Verify frontend calls correct backend port (3001 or 3000)
- [ ] Update CORS_ORIGIN if needed
- [ ] Test with browser DevTools Network tab

---

## 9. TESTING CHECKLIST

- [ ] Prometheus targets all UP
- [ ] Metrics exist and have data
- [ ] Grafana can connect to Prometheus
- [ ] Grafana dashboards load without errors
- [ ] Backend `/api/prometheus/health` returns true
- [ ] Backend `/api/grafana/dashboards` returns list
- [ ] Frontend loads without CORS errors
- [ ] WebSocket connects successfully
- [ ] Chat integration receives metrics

---

## References

- [Prometheus Configuration](monitoring/prometheus/prometheus.yml)
- [Grafana Provisioning](monitoring/grafana/provisioning/datasources/prometheus.yml)
- [Ops-Assistant Backend](web/ops-assistant/server/index.ts)
- [Ops-Assistant Client Config](web/ops-assistant/client/config.ts)
- [Docker Compose Services](docker-compose.yml)
