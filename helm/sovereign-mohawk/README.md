# Sovereign Mohawk Helm Chart

Production-grade Helm chart for deploying Sovereign Mohawk to Kubernetes.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- PersistentVolume provisioner (StorageClass: standard or custom)
- Optional: Prometheus Operator for monitoring integration

## Quick Start

### Install

```bash
# Add Sovereign Mohawk Helm repository (when available)
helm repo add sovereign-mohawk https://charts.sovereign-mohawk.local
helm repo update

# Install with default values
helm install sovereign-mohawk sovereign-mohawk/sovereign-mohawk \
  --namespace sovereign-mohawk \
  --create-namespace

# Or install from local chart directory
helm install sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk \
  --create-namespace
```

### Verify Installation

```bash
# Check pod status
kubectl get pods -n sovereign-mohawk

# Check services
kubectl get svc -n sovereign-mohawk

# Check persistent volumes
kubectl get pvc -n sovereign-mohawk

# View logs
kubectl logs -n sovereign-mohawk -f deployment/sovereign-mohawk-orchestrator
```

### Upgrade

```bash
helm upgrade sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk \
  -f values-prod.yaml
```

### Uninstall

```bash
helm uninstall sovereign-mohawk --namespace sovereign-mohawk
```

## Configuration

### Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `orchestrator.replicaCount` | 3 | Number of orchestrator replicas |
| `orchestrator.persistence.size` | 100Gi | Ledger storage size |
| `orchestrator.resources.limits.memory` | 2Gi | Memory limit per orchestrator pod |
| `nodeAgent.replicaCount` | 3 | Number of node-agent replicas |
| `nodeAgent.strategy` | Deployment | Deployment or DaemonSet |
| `prometheus.retention` | 30d | Prometheus metrics retention period |
| `networkPolicy.enabled` | true | Enable network policies |

### Common Configurations

#### Production Deployment

```bash
helm install sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk \
  --create-namespace \
  -f values-prod.yaml \
  --set orchestrator.replicaCount=5 \
  --set orchestrator.persistence.size=500Gi \
  --set orchestrator.resources.limits.memory=4Gi
```

#### Development Deployment

```bash
helm install sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk-dev \
  --create-namespace \
  -f values-dev.yaml \
  --set orchestrator.replicaCount=1 \
  --set nodeAgent.replicaCount=2
```

#### With Custom Storage Class

```bash
helm install sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk \
  --create-namespace \
  --set orchestrator.persistence.storageClass=fast-ssd \
  --set ipfs.storageClass=fast-ssd
```

#### With TLS Ingress

```bash
helm install sovereign-mohawk ./helm/sovereign-mohawk \
  --namespace sovereign-mohawk \
  --create-namespace \
  --set orchestrator.ingress.enabled=true \
  --set orchestrator.ingress.hosts[0].host=orchestrator.example.com \
  --set orchestrator.ingress.tls[0].secretName=orchestrator-tls
```

## Architecture

### Components

- **Orchestrator**: Central coordination server (Deployment, 3 replicas default)
- **Node Agents**: Worker nodes (Deployment, 3 replicas default)
- **IPFS**: Distributed storage backend
- **Prometheus**: Metrics collection
- **Grafana**: Observability dashboards
- **AlertManager**: Alert routing and aggregation

### Storage

- **Orchestrator Ledger**: 100Gi PVC (default), contains state and audit logs
- **Prometheus**: 50Gi PVC, metrics retention
- **Grafana**: 10Gi PVC, dashboard configurations
- **IPFS**: 100Gi PVC, distributed storage
- **AlertManager**: 5Gi PVC, alerting state

### Networking

- **Network Policies**: Enabled by default
  - Orchestrator can receive from node-agents and Prometheus
  - Node-agents can communicate with orchestrator and each other
  - DNS and external HTTPS allowed by default
- **Service Discovery**: ClusterIP services within namespace
- **Ingress**: Optional, disabled by default

### Security

- **Pod Security Context**:
  - Non-root user (UID: 65534)
  - Read-only root filesystem
  - Dropped all Linux capabilities
  - Enabled SELinux (if available)

- **RBAC**:
  - Dedicated service account per deployment
  - Minimal permissions (read pods, services, events)
  - Namespace-scoped roles

- **Network Policies**:
  - Segmented by component
  - Deny-by-default with explicit allow rules
  - Metrics access restricted to monitoring namespace

## Persistence

### Ledger Data

Orchestrator ledger data is persisted to a PVC mounted at `/var/lib/mohawk`.

```yaml
# To use a specific storage class
orchestrator:
  persistence:
    storageClass: "fast-ssd"
    size: 500Gi
```

### Backup and Restore

```bash
# Backup ledger data
kubectl exec -n sovereign-mohawk \
  statefulset/sovereign-mohawk-orchestrator \
  -- tar czf - /var/lib/mohawk | tar xzf - -C ./backups/

# Restore from backup
kubectl cp ./backups/var/lib/mohawk \
  sovereign-mohawk/sovereign-mohawk-orchestrator-0:/var/lib/
```

## Monitoring

### Prometheus Integration

Metrics are automatically scraped from:
- Orchestrator: `:9091/metrics`
- Node-agents: `:9091/metrics`
- IPFS: `:5001/debug/metrics`

### Grafana Dashboards

Pre-configured dashboards are available:
- Sovereign Mohawk | Operations Overview
- Sovereign Mohawk | Node Agents
- Byzantine Detection
- Tokenomics Flow

To import dashboards:

```bash
# Forward Grafana port
kubectl port-forward -n sovereign-mohawk svc/sovereign-mohawk-grafana 3000:80

# Access at http://localhost:3000
# Admin password: changeme (change in production!)
```

### Custom Alerts

Create PrometheusRule for custom alerts:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sovereign-mohawk-alerts
spec:
  groups:
  - name: sovereign-mohawk
    interval: 30s
    rules:
    - alert: OrchestratorDown
      expr: up{job="orchestrator"} == 0
      for: 5m
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n sovereign-mohawk <pod-name>

# Check logs
kubectl logs -n sovereign-mohawk <pod-name>

# Check events
kubectl get events -n sovereign-mohawk --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n sovereign-mohawk

# Describe PVC for events
kubectl describe pvc -n sovereign-mohawk <pvc-name>

# Check available storage
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeralStorage
```

### Network Connectivity

```bash
# Test connectivity between pods
kubectl run -it --rm debug --image=nicolaka/netcat --restart=Never -- \
  nc -zv sovereign-mohawk-orchestrator.sovereign-mohawk 8080

# Check network policies
kubectl get networkpolicy -n sovereign-mohawk
kubectl describe networkpolicy -n sovereign-mohawk sovereign-mohawk-orchestrator
```

## Performance Tuning

### Increase Orchestrator Capacity

```bash
helm upgrade sovereign-mohawk ./helm/sovereign-mohawk \
  --set orchestrator.replicaCount=10 \
  --set orchestrator.resources.limits.memory=4Gi \
  --set orchestrator.resources.limits.cpu="4" \
  --set orchestrator.persistence.size=500Gi
```

### Scale Node Agents

```bash
# As Deployment
helm upgrade sovereign-mohawk ./helm/sovereign-mohawk \
  --set nodeAgent.strategy=Deployment \
  --set nodeAgent.replicaCount=100

# As DaemonSet (one per node)
helm upgrade sovereign-mohawk ./helm/sovereign-mohawk \
  --set nodeAgent.strategy=DaemonSet
```

### Adjust Resource Requests

```bash
helm upgrade sovereign-mohawk ./helm/sovereign-mohawk \
  --set orchestrator.resources.requests.memory=2Gi \
  --set orchestrator.resources.requests.cpu="1" \
  --set nodeAgent.resources.requests.memory=1Gi \
  --set nodeAgent.resources.requests.cpu="500m"
```

## Values Files

### values-prod.yaml

Production configuration with:
- 5 orchestrator replicas
- 500Gi ledger storage
- 4Gi memory limits
- Network policies enabled
- Pod disruption budgets
- Affinity rules for HA

### values-dev.yaml

Development configuration with:
- 1 orchestrator replica
- 20Gi ledger storage
- 1Gi memory limits
- Network policies disabled (for easier debugging)
- No pod disruption budgets
- No affinity requirements

## Related Documentation

- [Main README](../../README.md)
- [Deployment Guide](../../DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md)
- [Operations Runbook](../../OPERATIONS_RUNBOOK.md)
- [Security Policy](../../SECURITY.md)
