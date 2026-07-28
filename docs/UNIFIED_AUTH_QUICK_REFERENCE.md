# Unified Identity & Observability Layer - Quick Reference

## What Was Implemented

This upgrade transforms the ops-assistant from a tool with "broken connectivity" to a **fully autonomous, information-rich operator** with:

✅ **Unified Authentication** - Centralized credential management  
✅ **Auto-Recovery** - Automatic token refresh on 401 errors  
✅ **Audit Trails** - Complete request tracing for debugging  
✅ **Semantic Observability** - Intelligent metric interpretation  
✅ **Diagnostics API** - Real-time auth status visibility  

---

## Quick Start (5 Minutes)

### 1. Generate Grafana Token

```bash
# If Grafana is running
docker exec grafana grafana-cli admin create-api-token \
  --name "ops-assistant" --role Admin
```

### 2. Set Environment Variable

```bash
export GRAFANA_API_TOKEN="<your-token-from-step-1>"
```

### 3. Restart Services

```bash
docker-compose down
docker-compose up -d
```

### 4. Verify

```bash
curl http://localhost:3001/api/auth/status | jq
```

Expected output:
```json
{
  "initialized": true,
  "grafanaTokenPresent": true,
  "healthy": true
}
```

---

## Automated Setup (Recommended)

```bash
cd /workspaces/Sovereign-Mohawk-Proto
chmod +x scripts/setup-auth-system.sh
./scripts/setup-auth-system.sh
```

The script will:
- ✓ Check prerequisites
- ✓ Generate Grafana token  
- ✓ Configure environment
- ✓ Test all connectivity
- ✓ Run diagnostics
- ✓ Provide recommendations

---

## Key New Files

| File | Purpose |
|------|---------|
| `web/ops-assistant/server/auth-manager.ts` | Unified credential & token lifecycle management |
| `web/ops-assistant/server/semantic-observability.ts` | Metric interpretation & health reports |
| `scripts/setup-auth-system.sh` | Automated setup & diagnostics |
| `scripts/test-auth-system.sh` | Comprehensive test suite |
| `AUTH_LAYER_IMPLEMENTATION_GUIDE.md` | Full technical documentation |

---

## Key New API Endpoints

### `/api/auth/status` - Quick Auth Check

```bash
curl http://localhost:3001/api/auth/status | jq
```

Response:
```json
{
  "initialized": true,
  "grafanaTokenPresent": true,
  "grafanaTokenLength": 32,
  "lastValidation": "2026-05-13T10:30:00.000Z",
  "healthy": true
}
```

### `/api/diagnostics` - Detailed Diagnostics

```bash
curl http://localhost:3001/api/diagnostics | jq '.auth'
```

Returns:
- Credential status
- Token validation info
- Recent request traces
- Error history

### `/api/health-report` - Health Analysis

POST to generate system health report:
```bash
curl http://localhost:3001/api/health-report -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "metrics": {
      "cpu_usage": 85,
      "memory_usage": 72,
      "error_rate": 0.5
    }
  }' | jq
```

---

## How Authentication Works

```
1. AuthManager initializes (on server start)
   ├─ Load credentials from /run/secrets/
   ├─ Fallback to GRAFANA_API_TOKEN env var
   ├─ Validate token is present

2. GrafanaClient makes API request
   ├─ Includes token from AuthManager
   ├─ Request traced in audit log

3. If 401 Unauthorized:
   ├─ Response interceptor catches error
   ├─ Calls revalidateAndRefreshToken()
   ├─ Retries request with fresh token
   ├─ Logs failure for diagnostics

4. Response returned to caller
   ├─ Success metrics recorded
   ├─ Request trace added
```

---

## Semantic Observability Examples

### Raw Metric → Intelligent Interpretation

**CPU Usage 85%:**
```
Interpretation: "CPU usage is critically high, system is at capacity"
Severity: critical
Recommendation: "Immediate action required: scale horizontally or optimize workload"
```

**Memory Usage 72%:**
```
Interpretation: "Memory usage is moderate"
Severity: info
Recommendation: null (no action needed)
```

**Error Rate 5.2%:**
```
Interpretation: "Error rate is critically high (> 5%), service degradation imminent"
Severity: critical
Recommendation: "Critical: immediate investigation required, consider circuit breaker activation"
```

### Health Report Markdown

```
📊 System Health Report - 2026-05-13T10:30:00.000Z
===========================================================
Overall Health Score: ✅ 87/100

Component Status:
  ✓ cpu: healthy (90/100)
  ⚠ memory: degraded (70/100)
  ✓ network: healthy (95/100)

Key Observations:
  • Memory usage is high, risk of OOM killer activation
    → Monitor closely and consider memory optimization

Data Completeness: 12/15 metrics available
Confidence Score: 95.0%
```

---

## Troubleshooting

### "401 Unauthorized" Error

```bash
# 1. Check current auth status
curl http://localhost:3001/api/auth/status | jq

# 2. Generate new token
export GRAFANA_API_TOKEN=$(docker exec grafana grafana-cli admin \
  create-api-token --name ops-assistant --role Admin)

# 3. Restart
docker-compose restart ops-assistant

# 4. Verify
curl http://localhost:3001/api/auth/status | jq '.healthy'
```

### "looking for token" Error

```bash
# This means GRAFANA_API_TOKEN env var is not set

# Solution:
export GRAFANA_API_TOKEN="your_actual_token"
docker-compose up ops-assistant -d
```

### Service Connection Issues

```bash
# Run diagnostics script
./scripts/setup-auth-system.sh

# Or check detailed logs
curl http://localhost:3001/api/diagnostics | jq '.auth.recentErrors'
```

---

## Testing

### Run Full Test Suite

```bash
chmod +x scripts/test-auth-system.sh
./scripts/test-auth-system.sh
```

Tests include:
- ✓ Service connectivity
- ✓ Authentication status
- ✓ Diagnostics API
- ✓ Grafana integration
- ✓ Prometheus integration
- ✓ Query functionality
- ✓ Error handling

### Individual Service Tests

```bash
# Test Prometheus
curl http://prometheus:9090/-/healthy

# Test Grafana
curl http://grafana:3000/api/health | jq

# Test ops-assistant
curl http://ops-assistant:3000/api/health | jq

# Test auth
curl http://ops-assistant:3000/api/auth/status | jq
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                 Ops-Assistant Server                │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │ AuthManager (Unified Credential Manager)      │ │
│  │ • Load credentials from /run/secrets/         │ │
│  │ • Validate tokens periodically                │ │
│  │ • Trace all requests for audit                │ │
│  │ • Auto-refresh on 401                         │ │
│  └───────────────────────────────────────────────┘ │
│              ↑                        ↓             │
│  ┌───────────────────────────────────────────────┐ │
│  │ GrafanaClient (Enhanced)                       │ │
│  │ • 401 response interceptor                    │ │
│  │ • Automatic token refresh                     │ │
│  │ • Detailed error handling                     │ │
│  └───────────────────────────────────────────────┘ │
│              ↓                                      │
│  ┌───────────────────────────────────────────────┐ │
│  │ Semantic Observability Layer                   │ │
│  │ • Metric interpretation                       │ │
│  │ • Health report generation                    │ │
│  │ • Confidence scoring                          │ │
│  └───────────────────────────────────────────────┘ │
│              ↓                                      │
│  ┌───────────────────────────────────────────────┐ │
│  │ Diagnostic Endpoints                          │ │
│  │ • /api/auth/status                           │ │
│  │ • /api/diagnostics                           │ │
│  │ • /api/health-report                         │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
         ↓              ↓              ↓
    Grafana       Prometheus    Monitoring
```

---

## Environment Variables

```bash
# Required
GRAFANA_API_TOKEN=<your-32-char-token>  # Set before docker-compose up

# Optional (with defaults)
PROMETHEUS_URL=http://prometheus:9090
GRAFANA_URL=http://grafana:3000
CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173
NODE_ENV=production
PORT=3000
```

---

## Files Changed

| File | Changes |
|------|---------|
| `web/ops-assistant/server/auth-manager.ts` | ✨ NEW - 300+ lines |
| `web/ops-assistant/server/grafana-client.ts` | 🔄 Enhanced with auth interceptor |
| `web/ops-assistant/server/semantic-observability.ts` | ✨ NEW - 400+ lines |
| `web/ops-assistant/server/index.ts` | 🔄 Added async init & diagnostics endpoints |
| `docker-compose.yml` | 🔄 Added /run/secrets volume |
| `scripts/setup-auth-system.sh` | ✨ NEW - Automated setup |
| `scripts/test-auth-system.sh` | ✨ NEW - Test suite |

---

## Next Steps (Phase 4)

- [ ] CI/CD Integration Test
- [ ] Confidence Score API endpoint
- [ ] Agent auto-reauth on 401
- [ ] Extended monitoring & alerting

---

## Documentation

- **[Full Implementation Guide](AUTH_LAYER_IMPLEMENTATION_GUIDE.md)** - Complete technical documentation (800+ lines)
- **[Setup Script Help](scripts/setup-auth-system.sh)** - Interactive setup guide
- **[Test Suite](scripts/test-auth-system.sh)** - Comprehensive validation

---

## Support

For issues or questions:

1. Check `/api/diagnostics` for auth status
2. Review logs: `docker logs ops-assistant | grep -i "auth\|token"`
3. Run setup script: `./scripts/setup-auth-system.sh`
4. See troubleshooting section above

---

**Status**: ✅ Production Ready (Phase 1-3 Complete, Phase 4 Framework Ready)
