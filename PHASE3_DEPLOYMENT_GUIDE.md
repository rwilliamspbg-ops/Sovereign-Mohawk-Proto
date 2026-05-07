# Phase 3 Deployment: Two-Level Aggregation Canary
## Staging Deployment & Benchmarking Guide

---

## Executive Summary

This document details the Phase 3 canary deployment for two-level hierarchical aggregation. The staging environment simulates a 100K-node network with:
- 1 Global Aggregator (L2)
- 10 Cluster Aggregators (L1) representing 10 clusters of 50 nodes each
- Gradient compression enabled (Top-K + INT8)
- Prometheus monitoring and Grafana dashboards

---

## Deployment Architecture

### Single-Level (Current Baseline)
```
Nodes (100K)
    ↓
Single Aggregator (orchestrator)
    ↓
Global Model
```
- Latency: 237ms P95 (estimated from 105ms L1 + buffer)
- Messages: 100K per round
- Throughput: 159 msg/sec

### Two-Level (Phase 3 Target)
```
Cluster 1-10 (50 nodes each)
    ↓
Cluster Aggregators (L1)
    ↓
Global Aggregator (L2)
    ↓
Global Model
```
- Latency: 81ms expected (33ms L1 + 48ms L2)
- Messages: ~4K per round (96% reduction)
- Throughput: 180+ msg/sec

---

## Prerequisites

✓ Local nodes running (orchestrator, node-agent-1/2/3)
✓ Docker Compose available
✓ 8GB RAM free (for staging cluster aggregators)
✓ Ports 8100-8103, 5001-5103, 9091, 3001 available

---

## Deployment Steps

### Step 1: Create Phase 3 Monitoring Config

```bash
mkdir -p monitoring/prometheus monitoring/grafana/provisioning/datasources

# Create prometheus-phase3.yml
cat > monitoring/prometheus/prometheus-phase3.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'global-aggregator'
    static_configs:
      - targets: ['global-aggregator:9091']
  
  - job_name: 'cluster-aggregators'
    static_configs:
      - targets:
          - 'cluster-agg-1:9091'
          - 'cluster-agg-2:9091'
          - 'cluster-agg-3:9091'
  
  - job_name: 'node-agents'
    static_configs:
      - targets:
          - 'node-agent-1:9100'
          - 'node-agent-2:9100'
          - 'node-agent-3:9100'
EOF
```

### Step 2: Deploy Phase 3 Staging Environment

```bash
# Start only Phase 3 components (separate from main network)
docker compose -f docker-compose.phase3-staging.yml up -d

# Verify deployment
docker compose -f docker-compose.phase3-staging.yml ps

# Expected output:
# global-aggregator      Up (healthy)
# cluster-agg-1          Up (healthy)
# cluster-agg-2          Up (healthy)
# cluster-agg-3          Up (healthy)
# prometheus-phase3      Up
# grafana-phase3         Up
```

### Step 3: Verify Inter-Component Communication

```bash
# Test global aggregator health
curl http://localhost:8100/health

# Check cluster aggregators registered
docker logs global-aggregator | grep "cluster.*registered"

# Verify metrics collection
curl http://localhost:9091/api/v1/targets | jq '.data.activeTargets[] | .labels.job'

# Expected metrics targets:
# - global-aggregator
# - cluster-agg-1
# - cluster-agg-2
# - cluster-agg-3
```

---

## Benchmarking Plan

### Benchmark 1: Latency Comparison

**Setup**:
- Send 100 gradient updates through both architectures
- Measure time from send to aggregation completion
- Compare P50, P95, P99 latencies

```bash
python3 << 'EOF'
import time
import requests
import statistics

# Single-level latency (baseline from orchestrator)
single_latencies = []
for i in range(100):
    start = time.time()
    # Simulate: send gradient to orchestrator
    requests.post('http://localhost:8080/api/gradient', json={'data': 'x'})
    latency_ms = (time.time() - start) * 1000
    single_latencies.append(latency_ms)

# Two-level latency (cluster -> global)
two_level_latencies = []
for i in range(100):
    start = time.time()
    # Simulate: send gradient to cluster aggregator
    requests.post('http://localhost:8101/api/gradient', json={'data': 'x'})
    latency_ms = (time.time() - start) * 1000
    two_level_latencies.append(latency_ms)

# Calculate statistics
print("Single-Level Latency:")
print(f"  P50: {statistics.median(single_latencies):.1f}ms")
print(f"  P95: {sorted(single_latencies)[int(0.95*len(single_latencies))]:.1f}ms")
print(f"  P99: {sorted(single_latencies)[int(0.99*len(single_latencies))]:.1f}ms")
print()
print("Two-Level Latency:")
print(f"  P50: {statistics.median(two_level_latencies):.1f}ms")
print(f"  P95: {sorted(two_level_latencies)[int(0.95*len(two_level_latencies))]:.1f}ms")
print(f"  P99: {sorted(two_level_latencies)[int(0.99*len(two_level_latencies))]:.1f}ms")
print()
improvement = (1 - statistics.mean(two_level_latencies) / statistics.mean(single_latencies)) * 100
print(f"Mean Improvement: {improvement:.1f}%")
EOF
```

### Benchmark 2: Message Count Reduction

**Expected Results**:
- Single-level: 100,000 messages per round (one per node)
- Two-level: ~4,000 messages per round (50 nodes per cluster + cluster aggregation)
- Reduction: 96%

**Measurement**:
```bash
# Capture network traffic (10 second sample)
docker exec global-aggregator tcpdump -i any -w /tmp/phase3.pcap 'dst port 5001' &
TCPDUMP_PID=$!
sleep 10
kill $TCPDUMP_PID

# Analyze packet count
docker exec global-aggregator tcpdump -r /tmp/phase3.pcap | wc -l
```

### Benchmark 3: Throughput

**Setup**:
- Measure messages processed per second
- Monitor during active aggregation round

```bash
# Query Prometheus for throughput metrics
curl -s 'http://localhost:9091/api/v1/query' \
  --data-urlencode 'query=rate(aggregator_gradients_processed_total[1m])' | \
  jq '.data.result[] | {job: .metric.job, throughput: .value[1]}'
```

### Benchmark 4: Convergence Validation

**Setup**:
- Run 10-epoch training simulation
- Compare loss curves between single-level and two-level
- Measure accuracy difference (<0.1% acceptable)

```bash
# Expected results:
# Loss should be identical or <0.1% difference
# Convergence rate should match
# Training time: 2x faster expected (50% latency improvement)
```

### Benchmark 5: Resource Utilization

**CPU & Memory**:
```bash
# Monitor during aggregation
docker stats --no-stream cluster-agg-1 cluster-agg-2 cluster-agg-3 global-aggregator

# Expected:
# Cluster aggregators: 0.5-1 CPU, 256-512MB RAM
# Global aggregator: 1-2 CPU, 512MB-1GB RAM
```

---

## Monitoring & Observability

### Grafana Dashboards (http://localhost:3001)

**Pre-built Dashboards**:
1. **Aggregation Performance**
   - Messages/second (cluster vs global)
   - Latency (P50, P95, P99)
   - Compression ratio

2. **Resource Usage**
   - CPU per aggregator
   - Memory per aggregator
   - Network I/O

3. **Cluster Health**
   - Active clusters (L1)
   - Global aggregator status (L2)
   - Message delivery success rate

### Prometheus Queries

```prometheus
# Latency percentiles
histogram_quantile(0.95, rate(aggregation_latency_seconds_bucket[1m]))

# Messages processed
rate(aggregator_gradients_processed_total[1m])

# Compression efficiency
rate(gradient_bytes_compressed[1m]) / rate(gradient_bytes_original[1m])

# Cluster connectivity
count(up{job="cluster-aggregators"})
```

---

## Success Criteria

| Metric | Target | Pass Threshold |
|--------|--------|----------------|
| P95 Latency | <85ms | <100ms |
| Message Reduction | 96% | >90% |
| Throughput | 180+ msg/sec | >150 msg/sec |
| Accuracy Loss | <0.1% | <0.5% |
| CPU/Cluster Agg | <1 CPU | <1.5 CPU |
| Memory/Cluster Agg | <512MB | <1GB |

---

## Rollout Plan (After Staging Validates)

### Week 1-2: Preparation
- [ ] Generate specs for full 100K node network (2000 clusters)
- [ ] Size infrastructure (CPU, memory, network)
- [ ] Create automation and monitoring alerts
- [ ] Train ops team on two-level operations

### Week 3-4: Canary (10% Production)
- [ ] Deploy to 10% of nodes (10K nodes, 200 clusters)
- [ ] Monitor convergence, latency, accuracy
- [ ] Gradually increase: 10% → 25%

### Week 5: Full Rollout
- [ ] 25% → 50% (50K nodes)
- [ ] 50% → 100% (100K nodes)
- [ ] Decommission single-level infrastructure

### Post-Deployment (Week 6+)
- [ ] Validate production metrics match staging
- [ ] Optimize cluster sizes per region
- [ ] Plan Phase 4 (federation sharding for 10M+)

---

## Rollback Plan

If issues occur:

**Immediate** (< 1 minute):
1. Route new traffic to single-level (existing orchestrator)
2. Keep two-level aggregators running (no impact)

**Short-term** (1-5 minutes):
1. Investigate root cause
2. Fix configuration/code
3. Restart affected components

**Long-term** (> 5 minutes):
1. Full rollback to single-level
2. Post-incident review
3. Fix and re-deploy

---

## Expected Production Impact

### Latency Improvement
- From 237ms to ~120ms (50% improvement)
- Training time: 5.2 min/epoch → 2.6 min/epoch (2x speedup)

### Bandwidth Reduction
- 96% fewer aggregation messages
- Cluster links: High throughput, low latency
- Global link: Aggregate models only (14GB every hour)

### Operational Complexity
- More services to monitor (cluster aggregators)
- More failure points (mitigated by cluster isolation)
- Better fault containment (cluster failures don't affect network)

---

## Next Steps After Phase 3 Success

1. **Optimize for 100K nodes**: Tune cluster sizes, aggregation timeouts
2. **Prepare Phase 4**: Federation sharding for 10M+ nodes
3. **Enable multi-region**: Deploy clusters in different regions, periodic merging
4. **Add dynamic scaling**: Auto-scale cluster aggregators based on load

---

## Commands Reference

```bash
# Start Phase 3 staging
docker compose -f docker-compose.phase3-staging.yml up -d

# Check status
docker compose -f docker-compose.phase3-staging.yml ps

# View logs
docker compose -f docker-compose.phase3-staging.yml logs -f global-aggregator

# Monitor metrics
watch -n 1 'curl -s http://localhost:9091/api/v1/query?query=up | jq ".data.result | length"'

# Cleanup
docker compose -f docker-compose.phase3-staging.yml down

# Full cleanup (including volumes)
docker compose -f docker-compose.phase3-staging.yml down -v
```

---

**Status**: Ready for staging deployment and benchmarking  
**Timeline**: 2 weeks to production (Phase 3 canary)  
**Risk Level**: Low (staging isolated, easy rollback)
