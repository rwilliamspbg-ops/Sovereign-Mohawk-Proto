# CopilotKit Ops Assistant

Minimal AI-powered operations assistant for Sovereign Mohawk, built with CopilotKit.

## Quick Start

### Development

```bash
# Install dependencies
npm install

# Start development server (Vite dev server + Node backend)
npm run dev

# In another terminal, start the Express backend
npm run server

# Visit http://localhost:5173
```

### Production Build

```bash
# Build for production
npm run build

# Start production server
npm start
```

## Architecture

- **Frontend**: React 18 + CopilotKit + Vite
- **Backend**: Express.js + TypeScript
- **Data Source**: Prometheus API

## Environment Variables

```
PROMETHEUS_URL=http://prometheus:9090   # Prometheus API endpoint
GRAFANA_URL=http://grafana:3000         # Grafana API endpoint
GRAFANA_API_TOKEN=admin                 # Grafana API token with dashboard read privileges
CORS_ORIGIN=http://localhost:3000       # Comma-separated browser origins allowed to call the API
CORS_METHODS=GET,POST,OPTIONS           # Allowed CORS methods
PORT=3000                                # Backend port
NODE_ENV=production                      # Environment
VITE_API_BASE_URL=http://localhost:3000  # Frontend API base URL (optional)
VITE_WS_URL=ws://localhost:3000          # Frontend WebSocket URL (optional)
```

## API Endpoints

### Health Check
```
GET /api/health
```
Returns system health status and Prometheus connectivity.

### Query Prometheus
```
POST /api/prometheus/query
Content-Type: application/json

{
  "query": "rate(mohawk:gradient_submit:total[1m])",
  "rangeMinutes": 30              // Optional: for range queries
}
```

### Generate Incident Summary
```
POST /api/incident-summary
Content-Type: application/json

{
  "startTime": "30m ago",         // Optional: default "30m ago"
  "endTime": "now"                // Optional: default "now"
}
```

### Explain Dashboard
```
POST /api/dashboard/explain
Content-Type: application/json

{
  "dashboardName": "v2-10-ops-overview"
}
```

## CopilotKit Actions

### queryPrometheus
Query Prometheus for metrics data.

```typescript
{
  query: "rate(mohawk:gradient_submit:total[1m])",
  rangeMinutes: 30  // optional
}
```

### generateIncidentSummary
Analyze metrics and generate incident summary with anomalies and recommendations.

```typescript
{
  startTime: "30m ago",  // optional
  endTime: "now"         // optional
}
```

### explainDashboard
Get explanation of a Grafana dashboard's purpose and key metrics.

```typescript
{
  dashboardName: "v2-10-ops-overview"
}
```

## Dockerfile

Multi-stage build for optimized production images:
- **Build stage**: Compiles TypeScript, builds React frontend
- **Runtime stage**: Minimal Node.js-alpine image with production deps only

```bash
docker build -t ops-assistant:latest .
docker run \
  -e PROMETHEUS_URL=http://prometheus:9090 \
  -e GRAFANA_URL=http://grafana:3000 \
  -p 3000:3000 \
  ops-assistant:latest
```

## Integration with docker-compose

Add to your `docker-compose.yml`:

```yaml
ops-assistant:
  build: ./web/ops-assistant
  container_name: ops-assistant
  ports:
    - "3001:3000"
  environment:
    - PROMETHEUS_URL=http://prometheus:9090
    - GRAFANA_URL=http://grafana:3000
    - GRAFANA_API_TOKEN=${GRAFANA_API_TOKEN}
    - CORS_ORIGIN=http://localhost:3001,http://localhost:5173
    - NODE_ENV=production
  depends_on:
    - prometheus
    - grafana
  networks:
    - mohawk-net
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
    interval: 10s
    timeout: 3s
    retries: 3
```

Then access at: `http://localhost:3001`

If you expose the API from a different browser origin, set `CORS_ORIGIN` to a comma-separated allowlist of exact origins before starting the server.

## Project Structure

```
.
├── server/                      # Express backend
│   ├── index.ts                # Server entry point
│   ├── prometheus-client.ts     # Prometheus API wrapper
│   └── actions.ts              # API handlers
├── client/                      # React frontend
│   ├── main.tsx                # Entry point
│   ├── App.tsx                 # Root component with CopilotKit
│   ├── components/
│   │   ├── ChatInterface.tsx    # Chat UI
│   │   └── HealthStatus.tsx     # System status
│   └── index.css               # Styles
├── public/
│   └── index.html              # Static HTML
├── package.json                # Dependencies
├── tsconfig.json               # TypeScript config
├── vite.config.ts              # Vite config
└── Dockerfile                  # Production build
```

## Key Features

- ✅ Real-time Prometheus data querying
- ✅ Incident analysis and summarization
- ✅ Dashboard explanations
- ✅ CopilotKit AI chat interface
- ✅ System health monitoring
- ✅ Docker containerization
- ✅ TypeScript for type safety
- ✅ Production-optimized build

## Next Steps

1. **More Actions**: Add anomaly detection, alert integration, query suggestions
2. **Visualization**: Sparklines, gauge charts for metrics
3. **History**: Save favorite queries and dashboards
4. **Alerts**: Integration with Grafana alerting
5. **Team**: Multi-user support, role-based access

## License

MIT - Sovereign Mohawk Project
