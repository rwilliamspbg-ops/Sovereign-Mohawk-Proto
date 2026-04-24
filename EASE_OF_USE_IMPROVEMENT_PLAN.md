# EASE-OF-USE IMPROVEMENT PLAN
## Comprehensive Strategy for All Environments

**Date:** 2025-06-21  
**Status:** Detailed Analysis & Actionable Plan  
**Priority:** HIGH - Critical for developer experience

---

## EXECUTIVE SUMMARY

**Why PyAPI doesn't run in Docker Compose:**
The `pyapi-metrics-exporter` service uses `image: golang:1.25` which expects **Go source code** in `/workspace`, but:
1. The SDK is in `sdk/python/` (Python, not Go)
2. The command `go run ./cmd/pyapi-metrics-exporter` tries to build Go, not Python
3. There's a **fundamental architectural mismatch** between the service name and implementation

**Overall Ease-of-Use Issues:**
1. Complex multi-environment setup (local, Docker Compose, Kubernetes)
2. Confusing naming and infrastructure mismatches
3. Lengthy documentation without clear quick-start paths
4. Missing development convenience tools
5. Insufficient validation and setup verification

---

## PART 1: PYAPI DOCKER COMPOSE ISSUE - ROOT CAUSE ANALYSIS

### Current Problem

**In docker-compose.yml:**
```yaml
pyapi-metrics-exporter:
  image: golang:1.25          # Go runtime
  command: ["go", "run", "./cmd/pyapi-metrics-exporter"]  # Run Go command
```

**But cmd/pyapi-metrics-exporter contains Go code**, not Python! The SDK is at `sdk/python/`.

### Why This Mismatch Exists

The "pyapi" name is **misleading**:
- The **exporter** (`cmd/pyapi-metrics-exporter`) = **Go program** that exports Python API metrics
- The **SDK** (`sdk/python/`) = **Python client library**
- They are **different components** with different purposes

### Solution 1: Fix the Docker Compose Service (IMMEDIATE)

**Option A: Build Proper Go Service (Recommended)**

```yaml
pyapi-metrics-exporter:
  build:
    context: .
    dockerfile: cmd/pyapi-metrics-exporter/Dockerfile
  container_name: pyapi-metrics-exporter
  environment:
    - MOHAWK_PYAPI_TRAFFIC_INTERVAL_SECONDS=10
    - MOHAWK_PYAPI_EXPORTER_PORT=9104
  ports:
    - "9104:9104"
  depends_on:
    orchestrator:
      condition: service_healthy
  healthcheck:
    test: ["CMD-SHELL", "wget -q -O - http://localhost:9104/metrics || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 3
  networks:
    - mohawk-net
```

**Option B: Add Python SDK Service**

```yaml
pyapi-client:
  image: python:3.11-slim
  container_name: pyapi-client
  working_dir: /app
  command: ["python", "-m", "mohawk.examples.basic"]
  environment:
    - MOHAWK_ORCHESTRATOR_URL=http://orchestrator:8080
    - PYTHONUNBUFFERED=1
  volumes:
    - ./sdk/python:/app
    - .:/workspace
  depends_on:
    orchestrator:
      condition: service_healthy
  networks:
    - mohawk-net
```

---

## PART 2: EASE-OF-USE IMPROVEMENTS ACROSS ALL ENVIRONMENTS

### 2.1 LOCAL DEVELOPMENT (Laptop/Desktop)

#### Problems Identified
1. **Complex prerequisite setup** - No validation script
2. **Long docker compose startup** - No progress feedback
3. **Multi-step initialization** - Runtime secrets, directories, configs
4. **Unclear environment variables** - Many optional, not documented
5. **Limited logging** - Hard to debug startup issues

#### Solutions

**A. Add Setup Validation Script**

```bash
#!/bin/bash
# scripts/validate-dev-environment.sh

echo "Validating local development environment..."

# Check prerequisites
checks=()
docker --version >/dev/null 2>&1 || checks+=("Docker")
docker compose version >/dev/null 2>&1 || checks+=("Docker Compose")
which go >/dev/null 2>&1 || checks+=("Go 1.25+")
which python3 >/dev/null 2>&1 || checks+=("Python 3.9+")

if [ ${#checks[@]} -gt 0 ]; then
  echo "ERROR: Missing prerequisites:"
  printf '  - %s\n' "${checks[@]}"
  exit 1
fi

# Verify directory structure
required_dirs=(
  "cmd/orchestrator"
  "cmd/node-agent"
  "sdk/python"
  "monitoring"
  "proofs"
)

for dir in "${required_dirs[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "ERROR: Missing directory: $dir"
    exit 1
  fi
done

# Create required directories
mkdir -p data/utility-ledger data/router runtime-secrets

echo "✓ All validations passed!"
echo "Ready to start: docker compose up -d"
```

**B. Add Quick Start Script**

```bash
#!/bin/bash
# scripts/quick-start-dev.sh

set -e

echo "Sovereign-Mohawk Quick Start"
echo "=============================="
echo ""

# Step 1: Validate environment
./scripts/validate-dev-environment.sh

# Step 2: Create directories
echo "Setting up local directories..."
mkdir -p data/{utility-ledger,router}
mkdir -p runtime-secrets monitoring/prometheus monitoring/grafana monitoring/alertmanager

# Step 3: Start services with progress
echo "Starting Docker Compose services..."
docker compose up -d --wait

# Step 4: Verify services
echo "Verifying services..."
sleep 5

services=("orchestrator" "prometheus" "grafana" "ipfs")
for service in "${services[@]}"; do
  if docker ps | grep -q "$service"; then
    echo "  ✓ $service running"
  else
    echo "  ✗ $service failed"
    exit 1
  fi
done

echo ""
echo "Services ready:"
echo "  Orchestrator: http://localhost:8080"
echo "  Grafana:      http://localhost:3000"
echo "  Prometheus:   http://localhost:9090"
echo "  IPFS:         http://localhost:5001"
echo ""
echo "Next: Set admin token with:"
echo "  export MOHAWK_TOKEN=\$(cat runtime-secrets/mohawk_api_token)"
```

**C. Add Interactive Configuration Wizard**

```bash
#!/bin/bash
# scripts/configure-dev-env.sh

echo "Configure Sovereign-Mohawk Development Environment"
echo "=================================================="
echo ""

# Ask for node count
read -p "Number of node agents (default 3): " NODE_COUNT
NODE_COUNT=${NODE_COUNT:-3}

# Ask for model deployment
read -p "Deploy AI models? (y/n, default y): " DEPLOY_MODELS
DEPLOY_MODELS=${DEPLOY_MODELS:-y}

# Ask for debug logging
read -p "Enable debug logging? (y/n, default n): " DEBUG
DEBUG=${DEBUG:-n}

# Create .env file
cat > .env.local << EOF
NODE_COUNT=$NODE_COUNT
DEPLOY_MODELS=$DEPLOY_MODELS
DEBUG_LOGGING=$DEBUG
MOHAWK_TRANSPORT_KEX_MODE=x25519-mlkem768-hybrid
MOHAWK_TPM_IDENTITY_SIG_MODE=xmss
MOHAWK_ROUTER_ALLOW_INSECURE_DEV_QUOTES=true
EOF

echo ""
echo "Configuration saved to .env.local"
echo "Start services with: docker compose --env-file .env.local up -d"
```

---

### 2.2 DOCKER COMPOSE (Full Stack)

#### Problems Identified
1. **Complex yaml file** - 300+ lines, hard to navigate
2. **Optional services unclear** - What can be disabled?
3. **Profiles not used** - No way to run subset of services
4. **Missing convenience commands** - No logs, status, reset in one place
5. **Data management unclear** - How to backup/restore volumes?

#### Solutions

**A. Restructure docker-compose.yml with Profiles**

```yaml
version: '3.9'

services:
  # CORE INFRASTRUCTURE
  runtime-secrets-init:
    profiles: ["core"]
    # ... existing config
  
  orchestrator:
    profiles: ["core"]
    # ... existing config
  
  # OBSERVABILITY (optional)
  prometheus:
    profiles: ["observability"]
    # ...
  
  grafana:
    profiles: ["observability"]
    # ...
  
  # DEVELOPMENT (optional)
  tpm-metrics:
    profiles: ["dev"]
    # ...
  
  # DATA STORAGE
  ipfs:
    profiles: ["core"]
    # ...
  
  # NODE AGENTS
  node-agent-1:
    profiles: ["core"]
    # ...
```

**B. Add Makefile for Common Tasks**

```makefile
.PHONY: help start stop status logs reset clean

help:
	@echo "Sovereign-Mohawk Development Commands"
	@echo "======================================="
	@echo "  make start          - Start all services"
	@echo "  make start-core     - Start only core services"
	@echo "  make start-dev      - Start with dev tools"
	@echo "  make stop           - Stop all services"
	@echo "  make status         - Show service status"
	@echo "  make logs           - Tail all logs"
	@echo "  make logs-service   - Tail service logs (make logs-orchestrator)"
	@echo "  make reset          - Reset all data"
	@echo "  make clean          - Remove all containers/volumes"

start:
	docker compose up -d

start-core:
	docker compose --profile core up -d

start-dev:
	docker compose --profile core --profile dev --profile observability up -d

stop:
	docker compose down

status:
	docker compose ps

logs:
	docker compose logs -f

logs-%:
	docker compose logs -f $*

reset:
	docker compose down -v
	rm -rf data/
	mkdir -p data/{utility-ledger,router}

clean:
	docker compose down
	docker system prune -f
```

**C. Create Docker Compose Variants**

```bash
# docker-compose.dev.yml - Development mode (all services)
# docker-compose.prod.yml - Production mode (minimal overhead)
# docker-compose.test.yml - Test mode (mock services)
```

---

### 2.3 KUBERNETES (Production)

#### Problems Identified
1. **Helm chart complexity** - Too many customization points
2. **Installation steps unclear** - What comes first?
3. **No quick verification** - How to know deployment is healthy?
4. **Missing upgrade path** - How to update safely?
5. **Observability gaps** - How to troubleshoot in K8s?

#### Solutions

**A. Create Helm Quick-Install Script**

```bash
#!/bin/bash
# scripts/helm-install.sh

RELEASE_NAME=${1:-sovereign-mohawk}
NAMESPACE=${2:-sovereign-mohawk}
VALUES_FILE=${3:-helm/values-prod.yaml}

echo "Installing Sovereign-Mohawk Helm Chart"
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install chart
helm install $RELEASE_NAME ./helm/sovereign-mohawk \
  --namespace $NAMESPACE \
  --values $VALUES_FILE \
  --wait

# Wait for deployment
echo "Waiting for deployment..."
kubectl rollout status deployment/sovereign-mohawk-orchestrator -n $NAMESPACE

# Show status
echo ""
echo "Installation complete!"
kubectl get all -n $NAMESPACE
```

**B. Add Health Check Dashboard**

```bash
#!/bin/bash
# scripts/k8s-health-check.sh

NAMESPACE=${1:-sovereign-mohawk}

echo "Sovereign-Mohawk Kubernetes Health Check"
echo "========================================"
echo ""

# Pod status
echo "Pod Status:"
kubectl get pods -n $NAMESPACE

# Service status
echo ""
echo "Service Status:"
kubectl get svc -n $NAMESPACE

# Deployment status
echo ""
echo "Deployment Rollout:"
kubectl rollout status deployment -n $NAMESPACE

# Recent events
echo ""
echo "Recent Events (last 10):"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

# PVC status
echo ""
echo "Persistent Volume Claims:"
kubectl get pvc -n $NAMESPACE
```

**C. Create Deployment Profiles**

```yaml
# helm/values-dev.yaml - Development (1 replica, no HA)
# helm/values-staging.yaml - Staging (3 replicas, basic HA)
# helm/values-prod.yaml - Production (5+ replicas, full HA, backup)
```

---

### 2.4 DOCUMENTATION IMPROVEMENTS

#### Current State
- 40+ markdown files scattered across repo
- 2,700+ lines of guides, but no clear entry point
- Separate docs for each environment
- Examples not discoverable

#### Solutions

**A. Create docs/README.md (Single Entry Point)**

```markdown
# Sovereign-Mohawk Documentation

## Quick Start (5 minutes)
- **Local Development**: [Getting Started Guide](getting-started-local.md)
- **Docker Compose**: [Docker Stack Guide](deployment/docker-compose.md)
- **Kubernetes**: [Kubernetes Deployment](deployment/kubernetes.md)

## User Guides
- [Running Your First Proof](guides/first-proof.md)
- [Using the Python SDK](guides/python-sdk.md)
- [Configuring Nodes](guides/node-configuration.md)

## Operations
- [Monitoring & Observability](ops/monitoring.md)
- [Troubleshooting](ops/troubleshooting.md)
- [Scaling Guide](ops/scaling.md)

## Reference
- [Environment Variables](reference/environment-variables.md)
- [API Documentation](reference/api.md)
- [Formal Proofs](proofs/README.md)
```

**B. Create Getting Started Script**

```bash
#!/bin/bash
# scripts/interactive-setup.sh

select env in "Local (Laptop)" "Docker Compose" "Kubernetes" "Exit"; do
  case $env in
    "Local (Laptop)")
      echo "Starting local development setup..."
      ./scripts/quick-start-dev.sh
      break
      ;;
    "Docker Compose")
      echo "Starting Docker Compose setup..."
      docker compose up -d --wait
      ./scripts/docker-compose-info.sh
      break
      ;;
    "Kubernetes")
      echo "Starting Kubernetes setup..."
      ./scripts/helm-install.sh
      break
      ;;
    "Exit")
      exit 0
      ;;
  esac
done
```

---

## PART 3: IMPLEMENTATION ROADMAP

### Phase 1: Immediate (Week 1) - Fix Critical Issues

**Priority: HIGH**

1. **Fix PyAPI in Docker Compose** (2 hours)
   - Create `cmd/pyapi-metrics-exporter/Dockerfile`
   - Update `docker-compose.yml` service
   - Test locally

2. **Add Setup Validation** (1 hour)
   - `scripts/validate-dev-environment.sh`
   - Test on 3 platforms (Linux, macOS, Windows)

3. **Create Quick Start Script** (1.5 hours)
   - `scripts/quick-start-dev.sh`
   - Test with clean environment

4. **Fix Docker Compose Structure** (1 hour)
   - Add profiles for core/dev/observability
   - Update documentation

### Phase 2: Short-Term (Week 2-3) - Convenience Tools

**Priority: MEDIUM**

1. **Add Makefile** (1 hour)
   - Common docker compose commands
   - Service-specific logs

2. **Create Helm Quick-Install** (2 hours)
   - `scripts/helm-install.sh`
   - `scripts/k8s-health-check.sh`

3. **Add Configuration Wizard** (1.5 hours)
   - Interactive environment setup
   - Generate .env files

4. **Refactor Documentation** (2 hours)
   - Single entry point
   - Clear path per environment

### Phase 3: Long-Term (Week 4+) - Advanced UX

**Priority: LOW**

1. **Add CLI Tool** (4 hours)
   - `mohawk` command with subcommands
   - Lifecycle management
   - Configuration management

2. **Create VS Code Dev Container** (2 hours)
   - `.devcontainer/devcontainer.json`
   - Auto-setup on open

3. **Add Docker Compose Watch** (1 hour)
   - Hot reload for development
   - File sync automation

---

## PART 4: SPECIFIC FILE IMPROVEMENTS

### New Files to Create

1. **scripts/validate-dev-environment.sh** - Prerequisite checker
2. **scripts/quick-start-dev.sh** - One-command setup
3. **scripts/configure-dev-env.sh** - Interactive wizard
4. **scripts/helm-install.sh** - K8s quick deploy
5. **scripts/k8s-health-check.sh** - K8s verification
6. **scripts/docker-compose-info.sh** - Service info
7. **Makefile** - Development commands
8. **docs/README.md** - Documentation hub
9. **docker-compose.dev.yml** - Dev variant
10. **.devcontainer/devcontainer.json** - VS Code setup

### Files to Refactor

1. **docker-compose.yml**
   - Add profiles
   - Separate concerns
   - Fix pyapi service

2. **README.md**
   - Add quick links to setup scripts
   - Reduce to essential info only

3. **helm/sovereign-mohawk/README.md**
   - Add quick install section
   - Add helm install script reference

---

## PART 5: SUMMARY OF IMPROVEMENTS

### Local Development Impact
- **Setup time:** 30 mins → 5 mins (6x faster)
- **Validation:** Manual → Automated
- **Debugging:** Stack traces → Clear error messages
- **Onboarding:** Complex → Interactive wizard

### Docker Compose Impact
- **Start time:** 5 mins → 3 mins (with profiles)
- **Flexibility:** Single config → Multiple profiles
- **Debugging:** Grep logs manually → `make logs-service`
- **Management:** Manual commands → `make` targets

### Kubernetes Impact
- **Installation:** 10 steps → 1 command
- **Verification:** Manual checks → `helm-install.sh --verify`
- **Troubleshooting:** Complex → `k8s-health-check.sh`
- **Upgrades:** Manual → `helm upgrade` script

---

## CONCLUSION

**The ease-of-use improvements will:**

1. ✅ **Fix PyAPI Docker Compose issue** - Proper Go service or separate Python SDK service
2. ✅ **Eliminate setup friction** - Automated validation and quick-start scripts
3. ✅ **Provide multiple entry points** - Local, Compose, K8s with clear guidance
4. ✅ **Add convenience tools** - Makefile, CLI, health checks
5. ✅ **Improve documentation** - Single entry point with clear paths

**Expected Outcomes:**
- Developer onboarding time: **8+ hours → 30 minutes**
- Production deployment time: **2 hours → 15 minutes**
- Troubleshooting efficiency: **Trial & error → Guided diagnostics**
- Team confidence: **Uncertain → Confident**

These improvements will make Sovereign-Mohawk **accessible to developers of all experience levels** while maintaining the sophisticated architecture underneath.
