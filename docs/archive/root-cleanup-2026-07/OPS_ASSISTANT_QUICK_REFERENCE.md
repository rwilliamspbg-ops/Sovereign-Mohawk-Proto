# CopilotKit Ops Assistant - Quick Reference

## What Is This?

A **conversational AI assistant** that answers questions about your Sovereign Mohawk cluster using real-time Prometheus metrics and Grafana dashboards.

## Quick Start (30 seconds)

```bash
# 1. Launch the cluster
./genesis-launch.sh

# 2. Wait for "CopilotKit Ops: http://localhost:3001 ✨" message

# 3. Open browser to http://localhost:3001

# 4. Start asking questions!
```

## Example Questions to Ask

### Metrics & Throughput
```
"What's the current gradient throughput?"
"Show me proof verification rates"
"How many accelerator operations per second?"
"What's the failure rate right now?"
```

### Analysis & Incidents
```
"Generate an incident summary"
"Were there any Byzantine attacks in the last hour?"
"Analyze the last 30 minutes for anomalies"
"What happened 15 minutes ago?"
```

### Dashboards
```
"Explain the ops-overview dashboard"
"What does the MRC transport dashboard measure?"
"Tell me about v2-14-ops-mrc-transport"
"What's on the incident dashboard?"
```

### Custom Queries
```
"Query: rate(mohawk:gradient_submit:total[1m])"
"Get the last hour of round latency data"
"Show me Byzantine filter rejections"
```

## Architecture at a Glance

```
Your Browser (http://localhost:3001)
           ↓ (Chat messages)
CopilotKit AI Assistant (React + Chat UI)
           ↓ (API calls)
Express Backend (Query handler)
           ↓ (PromQL queries)
Prometheus (Metrics database)
```

## Ports

| Service | Port | Purpose |
|---------|------|---------|
| **Ops Assistant** | `3001` | 🎯 **Main entry point** |
| Grafana | `3000` | Dashboard visualization |
| Prometheus | `9090` | Metrics database |
| Orchestrator | `8080` | Cluster management |

## Key Features

✅ **Real-time Metrics** - Direct access to all Prometheus data  
✅ **Incident Analysis** - Automatic anomaly detection  
✅ **Dashboard Explanations** - Understand what metrics mean  
✅ **AI-Powered** - Natural language interface  
✅ **Production-Ready** - Health checks, resource limits  
✅ **Containerized** - Lightweight Docker deployment  

## API Endpoints (Advanced)

Use these directly if not using the chat interface:

```bash
# Check health
curl http://localhost:3001/api/health

# Query Prometheus
curl -X POST http://localhost:3001/api/prometheus/query \
  -H "Content-Type: application/json" \
  -d '{"query":"rate(mohawk:gradient_submit:total[1m])"}'

# Get incident summary
curl -X POST http://localhost:3001/api/incident-summary \
  -H "Content-Type: application/json" \
  -d '{"startTime":"30m ago","endTime":"now"}'

# Explain a dashboard
curl -X POST http://localhost:3001/api/dashboard/explain \
  -H "Content-Type: application/json" \
  -d '{"dashboardName":"v2-10-ops-overview"}'
```

## Troubleshooting

**"Can't connect to ops-assistant"**
```bash
# Check if it's running
docker ps | grep ops-assistant

# View logs
docker logs ops-assistant

# Verify health
curl http://localhost:3001/api/health
```

**"Prometheus returned no data"**
```bash
# Verify Prometheus is running
docker ps | grep prometheus

# Test Prometheus directly
curl http://localhost:9090/api/v1/query?query=up
```

**"Chat feels slow"**
- Depending on Prometheus query complexity (200-500ms typical)
- Large time ranges with low step values take longer
- Try shorter time windows or more specific PromQL queries

## Available Metrics

```
Throughput:
  • mohawk:gradient_submit:rate1m
  • mohawk:proof_verifications:rate1m
  • mohawk:accelerator_ops:rate1m

Failures:
  • mohawk:gradient_submit:failure_rate_5m
  • mohawk_fedavg_byzantine_filtered_total

Latency:
  • mohawk_fedavg_round_latency_quantile_ms
  • mohawk_operator_op_latency_ms
  • mohawk_migration_request_latency_ms
  
→ Plus 1000+ standard Prometheus metrics
```

## Development vs Production

### Development (Local Testing)

```bash
cd web/ops-assistant
npm install
npm run dev          # Vite dev server :5173
# In another terminal:
npm run server       # Express backend :3000
```

### Production (Docker)

```bash
# Via docker-compose (recommended)
docker-compose up -d ops-assistant
# OR manual build
docker build -t ops-assistant:latest web/ops-assistant/
docker run -p 3001:3000 ops-assistant:latest
```

## File Locations

| What | Where |
|------|-------|
| Source Code | `web/ops-assistant/` |
| Configuration | `web/ops-assistant/.env.example` |
| Dockerfile | `web/ops-assistant/Dockerfile` |
| Docker Compose | `docker-compose.yml` (ops-assistant service) |
| Architecture | `COPILOTKIT_OPS_ASSISTANT_ARCHITECTURE.md` |
| Implementation | `COPILOTKIT_OPS_ASSISTANT_IMPLEMENTATION.md` |

## Key Components

| Component | Purpose | Tech |
|-----------|---------|------|
| **Frontend** | Chat interface & results | React + CopilotKit |
| **Backend** | API & query handler | Express.js + TypeScript |
| **Client SDK** | Prometheus queries | axios |
| **Container** | Deployable package | Docker Alpine |

## Next Steps

1. **Explore dashboards** via chat: "Tell me about each dashboard"
2. **Run diagnostics**: "Generate incident summary from last 5 minutes"
3. **Integrate with CI/CD**: Call REST APIs from automation
4. **Custom queries**: Build your own PromQL queries
5. **Extend actions**: Add new CopilotKit actions for custom logic

## Documentation

- **Full Architecture**: See `COPILOTKIT_OPS_ASSISTANT_ARCHITECTURE.md`
- **Implementation Details**: See `COPILOTKIT_OPS_ASSISTANT_IMPLEMENTATION.md`
- **Project README**: See `web/ops-assistant/README.md`

## Support

Issues? Check:
1. Docker logs: `docker logs ops-assistant`
2. Health endpoint: `curl http://localhost:3001/api/health`
3. Prometheus availability: `curl http://localhost:9090/-/healthy`
4. Network: `docker network inspect mohawk-net`

---

**Ready to chat with your cluster?** 🚀  
Visit: http://localhost:3001
