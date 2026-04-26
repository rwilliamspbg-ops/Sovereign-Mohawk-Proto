# Sovereign-Mohawk Documentation Hub

Welcome to **Sovereign-Mohawk**, a trusted execution environment for cryptographic operations using TPM-backed secrets and orchestration.

This is your central entry point for getting started, learning the system, and operating it in production.

---

## 🚀 Quick Start (5 minutes)

### Local Development

```bash
# Validate your environment
make validate

# Start everything with one command
make quick-start

# Check service status
make status
```

**That's it!** All services will be running. See logs with `make logs`.

### Docker Compose (Full Stack)

```bash
# Start all services
docker-compose up -d

# Verify services
docker-compose ps

# View logs
docker-compose logs -f
```

### Kubernetes (Production)

```bash
# Quick install with defaults
./scripts/helm-install.sh

# Verify deployment
./scripts/k8s-health-check.sh
```

---

## 📚 Documentation Index

- **[Adoption Acceleration Plan (30/60/90)](ADOPTION_ACCELERATION_PLAN.md)** — execution plan to convert technical strengths into ecosystem growth

### Getting Started
- **[Quick Start](#quick-start)** — 5-minute setup above
- **[Local Development Guide](#local-development)** — Laptop setup, debugging, hot reload
- **[Docker Compose Guide](#docker-compose)** — Full-stack containerized deployment
- **[Kubernetes Deployment](#kubernetes)** — Production-ready cloud deployment

### User Guides
- **[Running Your First Proof](#first-proof)** — Step-by-step example
- **[Python SDK Guide](#python-sdk)** — Integrate with Python applications
- **[Node Configuration](#node-configuration)** — Customize node behavior

### Operations & Reference
- **[Service Architecture](#architecture)** — Component overview
- **[Troubleshooting](#troubleshooting)** — Common issues and solutions
- **[API Reference](#api-reference)** — REST API endpoints
- **[Configuration Reference](#configuration)** — Environment variables and settings

---

## 🏗️ Architecture Overview

**Sovereign-Mohawk** consists of these core components:

```
┌─────────────────────────────────────────────────────┐
│  Client Applications (Python, Go, etc.)             │
└────────────────┬────────────────────────────────────┘
                 │
                 ↓ HTTP/gRPC
┌─────────────────────────────────────────────────────┐
│  API Server                                         │
│  - REST/gRPC endpoints                              │
│  - Request validation & routing                     │
│  - Metrics collection (port 8081)                   │
└────────────────┬────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────┐
│  Orchestrator                                       │
│  - Proof orchestration                              │
│  - TPM secret management                            │
│  - Node coordination                                │
└────────────────┬────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    ↓            ↓            ↓
┌────────┐  ┌────────┐  ┌────────┐
│ Node 1 │  │ Node 2 │  │ Node N │
│ (TPM)  │  │ (TPM)  │  │ (TPM)  │
└────────┘  └────────┘  └────────┘
```

### Services

| Service | Port | Purpose |
|---------|------|---------|
| **API** | 8080 | REST/gRPC endpoints for clients |
| **Metrics** | 8081 | Prometheus metrics for API |
| **Orchestrator** | 8090 | Proof orchestration & coordination |
| **Node** | 9080 | TPM-backed computation node |
| **Metrics Exporter** | 9090 | System metrics (Prometheus) |

---

## 🛠️ Local Development

### Prerequisites

```bash
# Check your setup
make validate

# Install missing dependencies
# macOS:
brew install docker docker-compose go python3

# Ubuntu:
sudo apt-get install docker.io docker-compose golang python3
```

### Development Workflow

**1. Start services:**
```bash
make quick-start
```

**2. View logs (in another terminal):**
```bash
make logs-orch      # Orchestrator logs
make logs-api       # API logs
make info           # Service connection info
```

**3. Run tests:**
```bash
make test

# Or in specific service:
docker-compose exec orchestrator go test ./...
```

**4. Make code changes:**
- Edit `cmd/orchestrator/main.go`, `sdk/python`, etc.
- Services auto-restart on rebuild
- View changes in logs: `make logs`

**5. Stop when done:**
```bash
make stop
```

### Hot Reload (Coming Soon)

To enable automatic rebuilds on code changes, uncomment `develop:` section in `docker-compose.yml`.

---

## 🐳 Docker Compose Deployment

### Start Full Stack

```bash
docker-compose up -d
```

### Service Profiles (Selective Startup)

Start only what you need:

```bash
# Core services only (API + Orchestrator)
docker-compose --profile core up -d

# With metrics
docker-compose --profile core --profile metrics up -d

# All services
docker-compose up -d
```

### Managing Services

```bash
# View status
docker-compose ps

# View logs
docker-compose logs -f orchestrator

# Shell access
docker-compose exec orchestrator /bin/bash

# Stop everything
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Networking

Services communicate within the Docker network (`sovereign-mohawk`):

- **API** → **Orchestrator**: `http://orchestrator:8090`
- **Orchestrator** → **Nodes**: `http://node:9080`
- **Client** → **API**: `http://localhost:8080`

---

## ☸️ Kubernetes Deployment

### Quick Install

```bash
# 1. Prerequisites check
kubectl version --client
helm version

# 2. Deploy to current cluster
./scripts/helm-install.sh

# 3. Verify deployment
./scripts/k8s-health-check.sh

# 4. Port forward for local access
kubectl port-forward svc/api 8080:8080
```

### Manual Helm Install

```bash
# Add repo and update
helm repo add sovereign-mohawk <repo-url>
helm repo update

# Install with defaults
helm install mohawk sovereign-mohawk/sovereign-mohawk

# Or customize
helm install mohawk sovereign-mohawk/sovereign-mohawk \
  --set api.replicas=3 \
  --set orchestrator.replicas=2
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n sovereign-mohawk

# View logs
kubectl logs -f deployment/api -n sovereign-mohawk

# Describe for troubleshooting
kubectl describe pod <pod-name> -n sovereign-mohawk
```

---

## 📝 Running Your First Proof

### 1. Start the system
```bash
make quick-start
```

### 2. Create a proof request
```bash
curl -X POST http://localhost:8080/v1/proofs \
  -H "Content-Type: application/json" \
  -d '{
    "proof_type": "tpm_quote",
    "nonce": "abc123def456",
    "pcr_indices": [0, 1, 2]
  }'
```

### 3. Monitor execution
```bash
make logs-orch     # See orchestration steps
make logs-metrics  # See performance metrics
```

### 4. Retrieve result
```bash
curl http://localhost:8080/v1/proofs/<proof_id>
```

---

## 🐍 Python SDK

### Installation

```bash
pip install sovereign-mohawk
```

### Basic Usage

```python
from sovereign_mohawk import MohawkClient

# Initialize client
client = MohawkClient(api_url="http://localhost:8080")

# Create proof request
proof = client.create_proof(
    proof_type="tpm_quote",
    nonce="abc123def456",
    pcr_indices=[0, 1, 2]
)

# Wait for completion
result = client.wait_for_proof(proof.id, timeout=30)
print(result.quote)
```

### Advanced Usage

See `sdk/python/examples/` for complete examples.

---

## ⚙️ Configuration Reference

### Environment Variables

**API Server:**
```bash
MOHAWK_API_LISTEN_PORT=8080          # REST/gRPC listen port
MOHAWK_API_METRICS_PORT=8081         # Metrics port
```

**Orchestrator:**
```bash
MOHAWK_ORCHESTRATOR_LISTEN_PORT=8090 # Orchestrator listen port
```

**Node:**
```bash
MOHAWK_NODE_ID=node-1                # Unique node identifier
MOHAWK_NODE_LISTEN_PORT=9080         # Node listen port
```

**TPM:**
```bash
MOHAWK_TPM_CLIENT_CERT_POOL_SIZE=128 # Certificate pool size
```

### Development Flags

```bash
DEBUG=true                 # Enable debug logging
RUST_LOG=debug            # Log level (debug, info, warn, error)
```

### Configuration Files

- `.env` — Environment variables (auto-generated by `make setup`)
- `docker-compose.yml` — Full stack definition
- `helm/values.yaml` — Kubernetes customization

---

## 🔍 Troubleshooting

### Services not starting?

```bash
# 1. Validate prerequisites
make validate

# 2. Check Docker daemon
docker ps

# 3. View detailed logs
docker-compose logs
```

### API connection refused?

```bash
# 1. Check if API is running
docker-compose ps api

# 2. Verify port binding
docker-compose ps api --format "{{.Ports}}"

# 3. Test connectivity
curl http://localhost:8080/v1/health
```

### Orchestrator errors?

```bash
# View orchestrator logs
make logs-orch

# Check service connectivity
docker-compose exec orchestrator \
  curl http://node:9080/v1/health
```

### Out of memory?

```bash
# Check Docker stats
docker stats

# Increase Docker memory limit
# Docker Desktop: Settings → Resources → Memory
# Or docker daemon config
```

### Disk full?

```bash
# Check usage
docker system df

# Clean up unused resources
docker system prune -a --volumes
```

---

## 📊 Monitoring

### Prometheus Metrics

Metrics are exposed on:
- **API**: `http://localhost:8081/metrics`
- **Exporter**: `http://localhost:9090/metrics`

### View Metrics

```bash
curl http://localhost:8081/metrics | grep mohawk_
```

### Grafana Dashboard (Coming Soon)

Pre-built dashboards for:
- Request latency & throughput
- Error rates
- TPM operation timing
- Resource utilization

---

## 🔐 Security Notes

- **Secrets**: Automatically generated and stored in Docker volumes
- **TPM Access**: Limited to node services
- **API Authentication**: (See API Reference for current status)
- **Network Isolation**: Docker network or Kubernetes NetworkPolicies

---

## 📞 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: `docs/` directory
- **Examples**: `sdk/python/examples/`

---

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feat/my-feature`
2. Make changes
3. Run tests: `make test`
4. Submit PR

---

## 📄 License

Apache License 2.0 — See LICENSE file

---

**Last Updated**: 2026-04-22  
**Status**: Phase 1 — Core Improvements
