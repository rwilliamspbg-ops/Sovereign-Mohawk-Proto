# CopilotKit Operations Assistant - Quick Start Guide

**Status**: ✅ READY TO DEPLOY  
**Version**: 1.1.0  
**Time to Setup**: 15 minutes  

---

## 🚀 Quick Start (5 Steps)

### Step 1: Install Dependencies (5 minutes)

```bash
cd /workspaces/Sovereign-Mohawk-Proto/web/ops-assistant

# Install all dependencies
npm install
```

**What gets installed:**
- CopilotKit (chat AI)
- A2UI + AG-UI (interactive patterns)
- WebSocket libraries (real-time)
- Recharts (data visualization)
- React Flow (topology)
- Zod (validation)
- All dev dependencies

### Step 2: Set Environment Variables (2 minutes)

Create `.env` file in `/web/ops-assistant/`:

```env
# Server Port
PORT=3000

# Prometheus Configuration
PROMETHEUS_URL=http://prometheus:9090

# Grafana Configuration
GRAFANA_URL=http://grafana:3000
GRAFANA_API_TOKEN=admin
```

### Step 3: Start Backend Server (2 minutes)

In one terminal:

```bash
cd /workspaces/Sovereign-Mohawk-Proto/web/ops-assistant
npm run server
```

**You should see:**
```
[Server] Operations Assistant running on port 3000
[Server] WebSocket: ws://localhost:3000
[Server] Health: http://localhost:3000/health
[Server] Available Actions: 10
```

### Step 4: Start Frontend Dev Server (3 minutes)

In another terminal:

```bash
cd /workspaces/Sovereign-Mohawk-Proto/web/ops-assistant
npm run dev
```

**You should see:**
```
VITE v5.0.0 ready in ... ms

➜  Local:   http://localhost:5173/
```

### Step 5: Open in Browser (3 minutes)

Navigate to: **http://localhost:5173**

---

## ✅ Verification Checklist

### Server Endpoints
```bash
# Test server health
curl http://localhost:3000/health

# Expected response:
# {
#   "status": "healthy",
#   "wsClients": 0,
#   "wsSubscriptions": 0
# }
```

### WebSocket Connection
Check browser console - should see:
```
[Hook] Connected to WebSocket
[Server] New WebSocket connection: client_...
```

### Available Actions
```bash
curl http://localhost:3000/api/actions

# Should list 10 actions:
# queryMetric, explainDashboard, identifyAnomaly, 
# compareMetrics, predictTrend, searchEvents,
# getNetworkTopology, alertOnCondition, 
# analyzePerformance, getNetworkStats
```

### Test Metrics
```bash
curl http://localhost:3000/api/test-metrics

# Should return mock metrics
```

---

## 🧭 Navigation Guide

### Chat View (Default)
- **URL**: http://localhost:5173
- **Features**: AI-powered chat interface
- **Use Case**: Ask questions about your metrics

### Metrics View
- **Button**: 📊 Metrics tab
- **Features**: Real-time metric cards with charts
- **Use Case**: Monitor live system metrics

### Dashboards View
- **Button**: 📈 Dashboards tab
- **Features**: Browse and search Grafana dashboards
- **Use Case**: View detailed dashboard analytics

---

## 🔧 Common Tasks

### Test WebSocket Streaming

```bash
# In browser console:
ws = new WebSocket('ws://localhost:3000');
ws.send(JSON.stringify({
  type: 'subscribe',
  query: 'up',
  interval: 1000
}));
ws.onmessage = (e) => console.log(JSON.parse(e.data));
```

### Query Prometheus

```bash
curl -X POST http://localhost:3000/api/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "up",
    "timeRange": "1h",
    "step": "1m"
  }'
```

### Get Grafana Dashboards

```bash
curl http://localhost:3000/api/grafana/dashboards
```

### Search Dashboards

```bash
curl "http://localhost:3000/api/grafana/search?query=network"
```

---

## 🐛 Troubleshooting

### Issue: WebSocket Connection Failed

**Solution:**
```bash
# Check server is running
curl http://localhost:3000/health

# Check firewall/ports
lsof -i :3000
```

### Issue: Prometheus Not Available

**Solution:**
```bash
# Set correct Prometheus URL
export PROMETHEUS_URL=http://your-prometheus:9090

# Verify connectivity
curl http://prometheus:9090/api/v1/query?query=up
```

### Issue: Grafana API Token Error

**Solution:**
```bash
# Check Grafana is running
curl http://grafana:3000

# Get new API token from Grafana UI
# Settings → API Keys → Create API Key

# Update .env
GRAFANA_API_TOKEN=your_new_token
```

### Issue: Port 3000 Already in Use

**Solution:**
```bash
# Change port in .env
PORT=3001

# Reconnect frontend to new port
# Update WebSocket URL in components if needed
```

---

## 📈 Performance Tips

### Optimize Metrics View

1. **Reduce Poll Interval** (for lower latency):
   ```jsx
   <MetricsView pollInterval={2000} />  // 2 seconds instead of 5
   ```

2. **Add Caching**:
   Frontend cache: 30-second results
   Server cache: Redis (optional)

3. **Limit Subscriptions**:
   Start with 3-5 critical metrics
   Add more as needed

### Optimize Dashboard View

1. **Lazy Load Panels**:
   Only load visible panels initially
   Load details on-demand

2. **Pagination**:
   Show 20 dashboards per page
   Load more as user scrolls

3. **Search Debouncing**:
   Wait 300ms after typing
   Reduce API calls

---

## 🔐 Security Checklist

Before production deployment:

- [ ] Update GRAFANA_API_TOKEN (generate new)
- [ ] Enable HTTPS (TLS certificates)
- [ ] Set CORS whitelist (don't use *)
- [ ] Enable rate limiting (see Best Practices)
- [ ] Add authentication to chat
- [ ] Set up audit logging
- [ ] Enable input validation (already done with Zod)
- [ ] Update CORS headers

### Add Rate Limiting

```typescript
// server/index.ts
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

---

## 📊 Monitoring

### Key Metrics to Monitor

1. **Server Health**
   ```bash
   curl http://localhost:3000/health
   ```
   - Check: uptime, wsClients, wsSubscriptions

2. **WebSocket Health**
   - Connections: Should stay stable
   - Subscriptions: Should match active users
   - Memory: Should not grow unbounded

3. **API Response Times**
   - Prometheus queries: < 500ms
   - Grafana calls: < 1000ms
   - WebSocket: < 100ms

4. **Error Rates**
   - HTTP errors: < 1%
   - Connection errors: < 0.1%
   - Message parse errors: 0

### Set Up Monitoring

```bash
# Monitor server logs
docker-compose logs -f ops-assistant-server

# Monitor memory
watch -n 1 'curl http://localhost:3000/health'

# Monitor connections
watch -n 1 'lsof -i :3000'
```

---

## 🚀 Deployment

### Development
```bash
npm run dev          # Frontend (Vite)
npm run server       # Backend (tsx watch)
```

### Production Build
```bash
npm run build        # TypeScript + Vite build
npm start            # Run compiled version
```

### Docker Deployment
```bash
docker-compose up --build -d
```

### Environment Setup
```bash
# Development
NODE_ENV=development
DEBUG=*

# Production
NODE_ENV=production
DEBUG=
PORT=3000
```

---

## 📚 File Structure

```
/web/ops-assistant/
├── client/
│   ├── components/
│   │   ├── MetricsView.tsx
│   │   ├── GrafanaDashboardView.tsx
│   │   └── ChatInterface.tsx
│   ├── hooks/
│   │   └── useWebSocket.ts
│   ├── styles/
│   │   ├── app.css
│   │   ├── metrics.css
│   │   └── grafana.css
│   ├── App.tsx
│   └── main.tsx
├── server/
│   ├── index.ts (Main Express + WebSocket)
│   ├── websocket-manager.ts
│   ├── grafana-client.ts
│   ├── actions.ts
│   └── prometheus-client.ts
├── package.json
├── tsconfig.json
├── vite.config.ts
└── .env
```

---

## 📞 API Reference

### REST Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/health` | Server health |
| POST | `/api/query` | Range queries |
| GET | `/api/query/instant` | Instant queries |
| GET | `/api/grafana/dashboards` | List dashboards |
| GET | `/api/grafana/dashboards/:uid` | Dashboard details |
| GET | `/api/grafana/search` | Search dashboards |
| GET | `/api/grafana/alerts` | List alerts |
| GET | `/api/grafana/annotations` | Get annotations |
| GET | `/api/subscriptions` | Active subscriptions |
| GET | `/api/actions` | Available actions |
| WS | `/` | WebSocket connection |

### WebSocket Messages

```javascript
// Subscribe to metric
{
  "type": "subscribe",
  "query": "up",
  "interval": 1000
}

// Unsubscribe
{
  "type": "unsubscribe",
  "query": "up"
}

// One-time query
{
  "type": "query",
  "query": "up"
}

// Ping
{
  "type": "ping"
}
```

---

## ✅ Success Criteria

Your setup is successful when:

✅ Server starts without errors  
✅ Frontend loads at http://localhost:5173  
✅ WebSocket connects (check console)  
✅ Metrics view shows real-time data  
✅ Dashboards view lists Grafana dashboards  
✅ Chat interface is interactive  
✅ All API endpoints respond  

---

## 🎯 Next Steps

1. **Testing**
   - Run the test suite: `npm test`
   - Load test: `npm run test:load`
   - E2E test: `npm run test:e2e`

2. **Configuration**
   - Customize metric queries
   - Add more dashboards
   - Configure alerts

3. **Deployment**
   - Set up production environment
   - Configure HTTPS
   - Deploy to server

4. **Optimization**
   - Monitor performance
   - Tune metric intervals
   - Add caching layers

5. **Team Training**
   - Share documentation
   - Conduct training sessions
   - Gather feedback

---

**Ready to go!** 🚀

Start with Step 1 above and you'll have a fully functional Operations Assistant in 15 minutes.

For detailed documentation, see:
- COPILOTKIT_OPS_ASSISTANT_ADVANCED_ENHANCEMENT.md
- COPILOTKIT_OPS_ASSISTANT_INTEGRATION_GUIDE.md
- COPILOTKIT_OPS_ASSISTANT_PATTERNS_BEST_PRACTICES.md
