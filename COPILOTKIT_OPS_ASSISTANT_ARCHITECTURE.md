# CopilotKit Operations Assistant Architecture

## Overview

A React-based AI operations companion powered by CopilotKit that reads Grafana/Prometheus telemetry and can:
- Explain dashboard panels and metrics
- Suggest PromQL queries for investigation
- Generate incident summaries from time-range data
- Provide real-time cluster health insights

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Browser / Operator                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  CopilotKit React Frontend (ops-assistant:3001)           │ │
│  │  - CopilotKitProvider wrapper                             │ │
│  │  - Chat UI component                                      │ │
│  │  - Metric visualization                                   │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│              │ HTTP/REST API (axios)                            │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Express.js Backend (ops-assistant:3000 internal)         │ │
│  │  - /api/prometheus/query/range                            │ │
│  │  - /api/prometheus/query/instant                          │ │
│  │  - /api/dashboard/metrics/{dashboard}                     │ │
│  │  - /api/health                                            │ │
│  │  - CopilotKit action handlers (server-side)               │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
└──────────────┼──────────────────────────────────────────────────┘
               │
               │ PromQL / HTTP
               ▼
        ┌─────────────────────┐
        │  Prometheus :9090   │
        │  (in docker-compose)│
        └─────────────────────┘
```

## Directory Structure

```
/web/ops-assistant/
├── package.json                          # Node.js dependencies
├── vite.config.ts                       # Vite build config
├── tsconfig.json                        # TypeScript config
├── Dockerfile                           # Multi-stage build
├── .dockerignore
│
├── server/                              # Express backend
│   ├── index.ts                         # Server entry point
│   ├── prometheus-client.ts             # Prometheus API wrapper
│   ├── actions/                         # CopilotKit action handlers
│   │   ├── query-prometheus.ts
│   │   ├── explain-dashboard.ts
│   │   └── incident-summary.ts
│   └── middleware/
│       └── error-handler.ts
│
├── client/                              # React frontend
│   ├── main.tsx                         # React entry point
│   ├── App.tsx                          # Root component
│   ├── components/
│   │   ├── ChatInterface.tsx            # CopilotKit chat
│   │   ├── MetricDisplay.tsx            # Query results
│   │   └── HealthStatus.tsx             # Cluster overview
│   └── styles/
│       └── index.css
│
├── public/                              # Static assets
│   └── index.html
│
└── dist/                                # (generated) Build output
```

## CopilotKit Action Handlers

### 1. queryPrometheus
**Purpose**: Execute PromQL queries and return time-series data

```typescript
{
  name: "queryPrometheus",
  description: "Execute a PromQL query against Prometheus for instant or range data",
  parameters: [
    { name: "query", type: "string", description: "PromQL expression" },
    { name: "rangeMinutes", type: "number", description: "Time range in minutes (optional)" }
  ],
  handler: async (query: string, rangeMinutes?: number) => {
    // Calls /api/prometheus/query/range or /api/prometheus/query/instant
    // Returns JSON: { status, data: { result: [...] } }
  }
}
```

### 2. explainDashboard
**Purpose**: Describe what a Grafana dashboard measures and why it matters

```typescript
{
  name: "explainDashboard",
  description: "Explain the purpose, panels, and key metrics of a Grafana dashboard",
  parameters: [
    { name: "dashboardName", type: "string", description: "Dashboard ID (e.g., 'v2-14-ops-mrc-transport')" }
  ],
  handler: async (dashboardName: string) => {
    // Reads dashboard JSON metadata
    // Returns: { title, description, panels: [...], keyMetrics: [...] }
  }
}
```

### 3. generateIncidentSummary
**Purpose**: Analyze metrics over a time window and summarize anomalies

```typescript
{
  name: "generateIncidentSummary",
  description: "Summarize cluster health metrics and flag anomalies from a time range",
  parameters: [
    { name: "startTime", type: "string", description: "RFC3339 or relative time (e.g., '30m ago')" },
    { name: "endTime", type: "string", description: "RFC3339 or relative time (default: now)" }
  ],
  handler: async (startTime: string, endTime: string) => {
    // Queries key metrics: gradient_submit:rate1m, proof_verifications:rate1m, failure rates
    // Analyzes trends and detects drops
    // Returns: { summary: "...", anomalies: [...], recommendations: [...] }
  }
}
```

### 4. suggestQuery
**Purpose**: Recommend PromQL queries for common troubleshooting tasks

```typescript
{
  name: "suggestQuery",
  description: "Suggest relevant PromQL queries based on a description of what to investigate",
  parameters: [
    { name: "problemDescription", type: "string", description: "What the operator wants to investigate" }
  ],
  handler: async (problemDescription: string) => {
    // Uses a map of keywords → recommended PromQL expressions
    // Returns: { suggestions: [{ query, description, metric }, ...] }
  }
}
```

## Integration with Launch Stack

### 1. Docker Compose Addition

Add to `docker-compose.yml`:

```yaml
ops-assistant:
  build: ./web/ops-assistant
  container_name: ops-assistant
  ports:
    - "3001:3000"  # Internal port 3000, exposed as 3001
  environment:
    - PROMETHEUS_URL=http://prometheus:9090
    - NODE_ENV=production
  depends_on:
    - prometheus
  networks:
    - mohawk-net
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
    interval: 10s
    timeout: 3s
    retries: 3
```

### 2. Genesis Launch Script Integration

Update `genesis-launch.sh` to:
1. Build ops-assistant Docker image (if needed)
2. Include ops-assistant in docker-compose up output
3. Display ops-assistant URL (http://localhost:3001) after launch
4. Add health check for ops-assistant availability

### 3. Port Allocation

| Service           | Port (Host) | Purpose                    |
|-------------------|-------------|----------------------------|
| api-dashboard     | 8081        | Historical API server      |
| grafana           | 3000        | Prometheus visualization   |
| **ops-assistant** | **3001**    | CopilotKit chat interface  |
| prometheus        | 9090        | Metrics API (internal)     |
| orchestrator      | 8080        | Cluster orchestrations     |

## Prometheus API Integration

### Key Metrics to Query

**Throughput & Health**:
- `mohawk:gradient_submit:rate1m` - Gradient submission rate
- `mohawk:proof_verifications:rate1m` - Verification rate
- `mohawk_fedavg_gradient_throughput_per_sec` - FedAvg gradient throughput

**Failures & Anomalies**:
- `mohawk:gradient_submit:failure_rate_5m` - Submit failure rate
- `mohawk_fedavg_byzantine_filtered_total` - Byzantine rejections
- (aggregate quantile: failures / (successes + failures))

**Latency & Performance**:
- `mohawk_fedavg_round_latency_quantile_ms` - Round latency p50/p95/p99
- `mohawk_operator_op_latency_ms` - Operator latency quantiles
- `mohawk_migration_request_latency_ms` - Migration latency

**MRC Transport** (from v2-14 dashboard):
- `rate(mohawk:gradient_submit:total[1m])` - MRC transport success rate
- `increase(mohawk_fedavg_byzantine_filtered_total[5m])` - Byzantine rejection trend

### Prometheus API Endpoints Used

- `GET http://prometheus:9090/api/v1/query?query=<expr>` - Instant queries
- `GET http://prometheus:9090/api/v1/query_range?query=<expr>&start=<ts>&end=<ts>&step=<duration>` - Range queries
- `GET http://prometheus:9090/api/v1/series?match[]=<expr>` - Series discovery

## Technology Stack

### Frontend
- **React 18+** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool (fast dev, optimized production)
- **CopilotKit** - AI chat framework
- **Tailwind CSS** - Styling
- **axios** - HTTP client

### Backend
- **Node.js 20-alpine** - Runtime
- **Express.js** - HTTP server
- **axios** - Prometheus API client
- **TypeScript** - Type safety
- **dotenv** - Environment configuration

### Deployment
- **Docker** - Multi-stage build (node:20-alpine)
- **docker-compose** - Service orchestration
- **Alpine Linux** - Minimal base image (~50MB)

## Security Considerations

1. **Prometheus Access**: Ops-assistant backend only; frontend makes no direct Prometheus calls
2. **Environment Variables**: `PROMETHEUS_URL` passed via docker-compose, never exposed in frontend
3. **CORS**: Backend proxies all Prometheus requests; frontend only talks to ops-assistant backend
4. **Query Validation**: Backend validates PromQL expressions before forwarding to Prometheus
5. **Rate Limiting**: Consider adding query rate limits to prevent resource exhaustion

## MVP Implementation Scope

**Phase 1 (Minimal Viable)**: 3-4 working actions
- ✅ Query Prometheus (instant + range queries)
- ✅ Explain Dashboard (query dashboard metadata)
- ✅ Incident Summary (analyze last 30min of key metrics)

**Phase 2 (Enhancement)**: Add more actions
- Suggest PromQL queries based on description
- Correlated anomaly detection (identify root causes)
- Real-time alerts integration

**Phase 3 (Polish)**: UI/UX improvements
- Metric visualization (sparklines, gauges)
- Query history & favorites
- Dashboard comparison

## References

- CopilotKit Docs: https://docs.copilotkit.ai/
- Prometheus HTTP API: https://prometheus.io/docs/prometheus/latest/querying/api/
- Grafana Dashboard JSON Format: `doc/grafana-dashboard-format.md` (if exists)
- Existing Prometheus Queries: `/monitoring/grafana/dashboards/v2/v2-14-ops-mrc-transport.json`
