# Quick Test Guide - Ops Assistant Fixes

## 🚀 Verify the Fixes (5 minutes)

### Step 1: Start Services
```bash
cd /workspaces/Sovereign-Mohawk-Proto
docker-compose up -d prometheus grafana ops-assistant
sleep 10  # Wait for services to start
```

### Step 2: Verify Backend is Running
```bash
# Should return 200 OK
curl http://localhost:3000/health

# Should list 3+ actions
curl http://localhost:3000/api/actions | jq '.actions[].name'
```

### Step 3: Test Metrics Endpoint
```bash
# Should return mock metric data
curl http://localhost:3000/api/test-metrics | jq .
```

### Step 4: Test Dashboard Endpoint
```bash
# Should return dashboards array
curl http://localhost:3000/api/grafana/dashboards | jq '.dashboards | length'
```

### Step 5: Start Frontend (new terminal)
```bash
cd web/ops-assistant
npm install
npm run dev
```

### Step 6: Access Web UI
- Open browser: http://localhost:5173
- You should see the Ops Assistant UI with 3 tabs

---

## ✅ Manual Testing Checklist

### Chat Tab
- [ ] Loads without errors
- [ ] CopilotChat component is visible
- [ ] Initial greeting message appears
- [ ] Can type questions
- [ ] Send button is clickable

**Test Query:** "How many metrics are available?"
**Expected:** Chat responds (may show testing response)

### Metrics Tab
- [ ] Shows "System Metrics" header
- [ ] Displays 4 metric cards below
- [ ] Each card shows: Name, Value, Unit, Trend arrow
- [ ] Connection status shows (WebSocket or API Fallback)
- [ ] Can click cards to see detailed view

**Expected Values (from mock data):**
- Request Rate: 0-10000 req/s
- CPU Usage: 0-100 %
- Memory Available: varies MB
- Network Latency: 0-100 ms

### Dashboards Tab
- [ ] Shows "Grafana Dashboards" header
- [ ] Search box is functional
- [ ] Refresh button works (↻)
- [ ] If Grafana connected: shows dashboard list
- [ ] If Grafana not connected: shows helpful error message

**Test Search:** Type "ops" or "overview"
**Expected:** Filters dashboards by name

---

## 🔍 Debugging Output

### Check Browser Console (F12)
Look for messages like:
```
[MetricsView] Fetching metrics from API...
[MetricsView] Metrics loaded from API: 4
[GrafanaDashboard] Fetching dashboards from: http://localhost:3000/api/grafana/dashboards
[GrafanaDashboard] Response: {success: true, dashboards: [...]}
```

### Backend Logs
```bash
docker logs -f ops-assistant | grep -E "\[Server\]|\[Error\]"
```

Expected startup logs:
```
[Server] Operations Assistant running on port 3000
[Server] WebSocket: ws://localhost:3000
[Server] Available Actions: 3
```

---

## ⚡ Quick Fixes if Something's Wrong

### "Cannot find module @copilotkit/react-core"
```bash
cd web/ops-assistant
npm install @copilotkit/react-core
```

### Metrics show "Loading..." forever
1. Check browser console for errors (F12)
2. Verify backend: `curl http://localhost:3000/api/test-metrics`
3. Try page refresh (Ctrl+Shift+R)

### Dashboards show "Failed to fetch dashboards"
1. Verify Grafana is running: `docker ps | grep grafana`
2. Check Grafana status: `curl http://localhost:3000/api/health` (from backend)
3. Verify API endpoint: `curl http://localhost:3000/api/grafana/dashboards`

### CopilotChat not responding
1. Check browser console for JavaScript errors
2. Verify actions are registered: `curl http://localhost:3000/api/actions`
3. Check if CopilotKit provider error in console

---

## 📊 Expected Architecture Check

```
✓ CopilotProvider wrapping App
  └─ ✓ CopilotChat component
  └─ ✓ MetricsView component  
  └─ ✓ GrafanaDashboardView component

✓ Backend API (port 3000)
  └─ ✓ Express server running
  └─ ✓ WebSocket connection ready
  └─ ✓ Grafana client initialized
  └─ ✓ Actions registered

✓ Prometheus (port 9090)
  └─ ✓ Metrics available

✓ Grafana (port 3000 in docker)
  └─ ✓ Dashboards available
  └─ ✓ API accessible
```

---

## 🎯 Success Criteria

| Feature | Status | How to Verify |
|---------|--------|---------------|
| CopilotChat loads | ✓ | Visible in Chat tab |
| Chat responds | ✓ | Sends message, gets response |
| Metrics display | ✓ | 4 cards show with data |
| Dashboards list | ✓ | Dashboards appear in list |
| Connection status | ✓ | Shows "Connected (API/WebSocket)" |
| Error messages | ✓ | Clear errors if services fail |

All items ✓ = **Frontend is working correctly**

---

## 📝 Test Report Template

```markdown
## Ops Assistant Test Report - [Date]

### Environment
- Docker: [version]
- Node: [version]
- Browser: [name/version]

### Results
- [ ] Backend health check: PASS/FAIL
- [ ] API endpoints respond: PASS/FAIL
- [ ] Chat tab loads: PASS/FAIL
- [ ] Metrics tab shows data: PASS/FAIL
- [ ] Dashboards tab shows data: PASS/FAIL

### Issues Found
[List any issues]

### Overall Status
✅ WORKING / ⚠️ PARTIAL / ❌ BROKEN
```

---

**Last Updated:** 2026-05-12
