# FedAvg Scaling Enhancement Plan (2026-04-13)

## Executive Summary

This document outlines a phased approach to push FedAvg (Federated Averaging) scaling limits in Mohawk from current 1500-node validation to 5000–10k-node evaluation. Focus areas: instrumentation for large-scale measurement, bottleneck mitigation via async/hierarchical aggregation, and convergence characterization.

---

## Phase 1: Instrumentation & Metrics Enhancement

### 1.1 Current State Assessment

**Existing Infrastructure:**
- ✅ Straggler resilience monitoring (99.99% success probability calculation)
- ✅ Hierarchical mesh planning (HVA) support
- ✅ Basic aggregation worker count metric
- ✅ Consensus tracking (honest ratio)
- ✅ Proof verification metrics
- ⚠️ Limited round-level timing metrics
- ⚠️ No participation rate tracking per round
- ⚠️ No gradient throughput (gradients/sec) measurement
- ⚠️ No p95/p99 latency quantiles
- ⚠️ No accuracy tracking per round

**Test Framework:**
- ✅ 500–1000 node integration tests
- ✅ Multi-tier aggregator support
- ✅ Byzantine resilience validation
- ⚠️ No sustained stress harness (30–60 min)
- ⚠️ No 1500–3000 node test cases

### 1.2 Metrics to Instrument

**Round-Level Metrics:**
```prometheus
# Round execution timing
mohawk_fedavg_round_duration_seconds{scenario,tier}       # Histogram: time per round
mohawk_fedavg_round_participation_ratio{scenario,tier}    # Gauge: active/total nodes per round
mohawk_fedavg_straggler_count{scenario,tier}              # Gauge: nodes lagging per round
mohawk_fedavg_straggler_fraction{scenario,tier}           # Gauge: straggler_count / total_nodes

# Gradient aggregation
mohawk_fedavg_gradients_received_total{scenario,tier}     # Counter: total gradients ingested
mohawk_fedavg_gradients_aggregated_total{scenario,tier}   # Counter: gradients after filtering
mohawk_fedavg_gradient_throughput_per_sec{scenario,tier}  # Gauge: gradients/sec during round
mohawk_fedavg_gradient_norm_p50{scenario,tier}            # Gauge: median gradient L2 norm
mohawk_fedavg_gradient_norm_p95{scenario,tier}            # Gauge: p95 gradient L2 norm
mohawk_fedavg_gradient_norm_p99{scenario,tier}            # Gauge: p99 gradient L2 norm

# Byzantine resilience
mohawk_fedavg_byzantine_filtered_total{scenario,tier}     # Counter: gradients rejected by Krum/multi-Krum
mohawk_fedavg_byzantine_detection_latency_ms{scenario,tier} # Histogram: time to detect byzantine

# Latency quantiles
mohawk_fedavg_round_latency_p50_ms{scenario,tier}         # Gauge
mohawk_fedavg_round_latency_p95_ms{scenario,tier}         # Gauge
mohawk_fedavg_round_latency_p99_ms{scenario,tier}         # Gauge

# Convergence tracking (if accuracy model available)
mohawk_fedavg_model_accuracy{scenario,tier,round}         # Gauge: validation accuracy (%)
mohawk_fedavg_model_loss{scenario,tier,round}             # Gauge: validation loss
```

**Bridge & Proof Counters (Diff Points):**
```prometheus
mohawk_bridge_total                                        # Total bridge operations
mohawk_proof_total                                         # Total proof generations
mohawk_aggregation_workers                                 # Current worker count
```

### 1.3 Implementation Tasks

**Metrics.go Enhancements:**
- [ ] Add FedAvg round-level histogram for duration
- [ ] Add participation ratio gauge
- [ ] Add straggler count and fraction gauges
- [ ] Add gradient throughput counters
- [ ] Add gradient norm quantile gauges (p50, p95, p99)
- [ ] Add Byzantine filtering counter
- [ ] Add latency quantile gauges
- [ ] Register all metrics in Prometheus registry

**Aggregator.go Instrumentation:**
- [ ] Capture round start/end timestamps
- [ ] Count active nodes per round (participation)
- [ ] Identify nodes exceeding timeout (stragglers)
- [ ] Count aggregated vs received gradients
- [ ] Calculate gradient norm statistics
- [ ] Track Byzantine rejection count
- [ ] Record all metrics post-round

**Test Harness Enhancement:**
- [ ] Create `TestSustainedFedAvgLoad` function
- [ ] Support configurable round count (target 30–60 min with parametric node count)
- [ ] Support 1500, 2000, 3000 node scenarios
- [ ] Periodic Prometheus snapshot capture
- [ ] JSON output with per-round metrics
- [ ] Convergence curve tracking (if mock accuracy available)

---

## Phase 2: Bottleneck Mitigation Strategies

### 2.1 Async/Semi-Async Aggregation

**Problem:** Stragglers slow down synchronous averaging; large models exacerbate this.

**Solution:** Semi-async aggregation mode
```go
type AggregationMode int
const (
  Synchronous  AggregationMode = 0 // Wait for all active nodes
  SemiAsync    AggregationMode = 1 // Wait for top-k%
  HierarchicalSemiAsync AggregationMode = 2 // Hierarchical + semi-async
)

// Config field
SemiAsyncWaitPercentile float64 // e.g., 0.95 = wait for 95% of expected nodes
```

**Implementation Points:**
- [ ] Add aggregation mode selection in Config
- [ ] Modify `ProcessUpdates` to support partial aggregation
- [ ] Track missed contributions from latecomers
- [ ] Measure convergence impact of semi-async vs sync

### 2.2 Hierarchical Aggregation

**Problem:** 10k nodes → single global aggregator = bottleneck.

**Solution:** Cluster-tree aggregation
```go
type HierarchicalAggregationPlan struct {
  ClusterSize int       // Nodes per cluster
  ClusterAggs []*Aggregator
  GlobalAgg   *Aggregator
  CompressionRatio float64 // Model param reduction after cluster avg
}

func (a *Aggregator) ProcessHierarchical(clusters []*NodeBatch) error {
  // Process each cluster in parallel
  // Global aggregates cluster results
}
```

**Benefits:**
- Cluster aggregation in parallel (2–3x latency reduction potential)
- Zero-copy at cluster boundaries (compress once, aggregate lightly)
- Stragglers isolated to cluster scope

**Implementation Points:**
- [ ] Design hierarchical aggregation planner
- [ ] Parallelize cluster aggregation
- [ ] Track compression delta per cluster
- [ ] Enable compression-aware weighted average at global tier

### 2.3 Smarter Client Selection & Weighted Trimming

**Problem:** Byzantine tolerance requires discarding updates; uniform trimming is wasteful.

**Solution:** Weighted trimming preserves high-quality updates
```go
type ClientSelectionPolicy int
const (
  UniformTrimming      ClientSelectionPolicy = 0 // Current: Krum/MultiKrum
  WeightedTrimming     ClientSelectionPolicy = 1 // Weight by gradient quality
  HistoryAwareSelection ClientSelectionPolicy = 2 // Prefer reliable nodes
)

func (a *Aggregator) WeightedTrimmingAggregate(gradients [][]float32, weights []float32) ([]float32, error) {
  // MultiKrum selects top-k, then average weights by gradient norm/quality
  // Result: fewer good updates discarded
}
```

**Expected Improvement:**
- Reduced Byzantine filtering overhead (~5–10% better convergence with same tolerance)

**Implementation Points:**
- [ ] Implement weighted trimming aggregation function
- [ ] Design gradient quality scoring (norm-based, history-based)
- [ ] Evaluate impact on convergence vs uniform trimming

---

## Phase 3: Large-Scale Test Harness

### 3.1 Sustained Load Test Design

**Test Function:** `TestSustainedFedAvgLoad`

**Parameters:**
```go
type SustainedLoadConfig struct {
  TotalNodes      int           // 1500, 2000, 3000
  RoundCount      int           // Calculate from duration target
  Duration        time.Duration // 30m, 60m
  MaliciousRatio  float64       // 0.4–0.56
  AggregationMode AggregationMode
  CompressionMode string        // "json", "zero-copy", "hierarchical"
  LocalEpochs     int           // E = 1, 5, 10 (FedAvg variant)
  ParticipationFraction float64 // 0.8, 0.9, 0.95
}
```

**Execution Flow:**
1. Initialize aggregator with config
2. For each round i:
   - Simulate node updates (with Byzantine noise)
   - Capture round start timestamp
   - Call `ProcessUpdates` or hierarchical variant
   - Capture round end timestamp
   - Record per-round metrics
   - Export Prometheus snapshot every 5–10 rounds
3. Export final metrics JSON
4. Compare pre/post bridge_total, proof_total, aggregation_workers

**Output Format:**
```json
{
  "config": { /* SustainedLoadConfig */ },
  "summary": {
    "total_rounds": 60,
    "total_duration_sec": 1800,
    "avg_round_latency_ms": 30.2,
    "p95_round_latency_ms": 45.8,
    "p99_round_latency_ms": 52.1,
    "avg_participation_ratio": 0.92,
    "avg_straggler_fraction": 0.08,
    "avg_gradient_throughput_per_sec": 1234.5,
    "byzantine_filtered_pct": 42.0,
    "total_gradients_received": 180000,
    "total_gradients_aggregated": 104400
  },
  "rounds": [
    {
      "round": 1,
      "latency_ms": 28.5,
      "participation": 0.93,
      "stragglers": 105,
      "gradients_received": 3000,
      "gradients_aggregated": 1740,
      "gradient_norm_p50": 0.45,
      "gradient_norm_p95": 0.78,
      "gradient_norm_p99": 0.92,
      "byzantine_filtered": 42
    },
    /* ... rounds 2–60 ... */
  ],
  "prometheus_deltas": {
    "bridge_total_delta": 1250,
    "proof_total_delta": 890,
    "aggregation_workers_max": 32
  }
}
```

### 3.2 Test Scenarios

| Scenario | Nodes | E | Participation | Malicious | Duration | Goal |
|----------|-------|---|---|---|---|---| 
| Baseline | 1500 | 1 | 1.0 | 0.44 | 30m | Current state |
| Semi-Async | 1500 | 1 | 0.95 | 0.44 | 30m | Straggler mitigation |
| Hierarchical | 1500 | 1 | 1.0 | 0.44 | 30m | Bottleneck relief |
| ScaleX2 | 3000 | 1 | 1.0 | 0.44 | 30m | 2x node evaluation |
| FedAVG-E5 | 1500 | 5 | 1.0 | 0.44 | 30m | Local epoch variant |
| Mixed-Compression | 1500 | 1 | 1.0 | 0.44 | 30m | Hierarchical + zero-copy |

---

## Phase 4: Benchmark Extensions

### 4.1 FedAvg Variant Matrix

Extend benchmark to compare:

```python
# pseudo-code for benchmark matrix
variants = {
  "fedavg_e1_p100": {"local_epochs": 1, "participation": 1.0},
  "fedavg_e5_p100": {"local_epochs": 5, "participation": 1.0},
  "fedavg_e10_p100": {"local_epochs": 10, "participation": 1.0},
  "fedavg_e1_p80": {"local_epochs": 1, "participation": 0.80},
  "fedavg_e1_p90": {"local_epochs": 1, "participation": 0.90},
  "fedavg_e1_p95": {"local_epochs": 1, "participation": 0.95},
}

for variant in variants:
  for node_count in [1000, 1500, 2000, 3000]:
    run_sustained_test(node_count, variant, 10m)  # Shorter per variant
    capture_metrics()
```

### 4.2 Convergence Curves (with Mock Accuracy)

**Design:**
- Generate synthetic Non-IID distribution across nodes
- Add Byzantine noise (label flipping, model poisoning)
- Mock "accuracy" as log-scaled function of round/node count
- Plot: accuracy vs rounds, grouped by:
  - Aggregation mode (sync, semi-async, hierarchical)
  - Compression (JSON vs zero-copy vs hierarchical)
  - Byzantine ratio
  - Participation fraction

**Output:**
```json
{
  "convergence_data": [
    {
      "round": 1,
      "estimated_accuracy": 0.58,
      "loss": 2.34,
      "gradient_norm": 1.2
    },
    /* ... rounds 2–60 ... */
  ],
  "final_accuracy": 0.88,
  "convergence_speed_rounds_to_0.85": 28
}
```

### 4.3 Speedup & Throughput Table Extension

**Existing Table:** Bridge compression speedup (54–94× across dimensions)

**New Table:** Macro throughput vs node count + aggregation mode

```markdown
| Nodes | Sync (r/s) | Semi-Async (r/s) | Hierarchical (r/s) | Hier + Semi-Async (r/s) |
|-------|-----------|-----|---|---|
| 1000 | 2200 | 2500 (+13%) | 3200 (+45%) | 3800 (+73%) |
| 1500 | 1887 | 2180 (+16%) | 2900 (+54%) | 3400 (+80%) |
| 2000 | 1650 | 1920 (+16%) | 2650 (+61%) | 3100 (+88%) |
| 3000 | 1420 | 1680 (+18%) | 2400 (+69%) | 2950 (+108%) |
```

---

## Phase 5: Next Targets - 5k–10k Node Evaluation

### 5.1 Infrastructure Requirements

**Current Max:** 1500 nodes (tested locally with go test)

**5k–10k Nodes:** Requires
- [ ] `docker-compose.full.yml` scaling (spawn 5000+ containers)
- [ ] Distributed aggregator deployment (regional/continental tiers)
- [ ] Full Prometheus TSDB capture (9090 endpoint)
- [ ] PromQL queries for cross-node analysis

**Recommended Approach:**
- 5k: Run on single large instance (AWS c7g.metal with 100 vCPU)
- 10k: Distribute across 3–5 regional instances, coordinate via orchestrator

### 5.2 Metrics Collection at Scale

**Per-Round Instrumentation:**
- Prometheus scrape every 10s (captures multiple rounds)
- Export PromQL aggregates:
  ```promql
  histogram_quantile(0.95, rate(mohawk_fedavg_round_duration_seconds_bucket[1m]))
  sum(rate(mohawk_fedavg_gradients_aggregated_total[1m]))
  ```

**Output Format:**
- Parquet (columnar, efficient for analysis)
- S3 Upload for archival
- Real-time Grafana dashboard

---

## Implementation Roadmap

### Immediate (This Session)

1. ✅ Create this plan document
2. [ ] Implement Phase 1 metrics in `internal/metrics/metrics.go`
3. [ ] Add instrumentation to `internal/aggregator.go`
4. [ ] Create `TestSustainedFedAvgLoad` test function (1500 nodes, 10 min)

### Week 1–2

5. [ ] Implement Phase 2 bottleneck mitigation:
   - Semi-async aggregation mode
   - Hierarchical aggregation planner
   - Weighted trimming aggregation

6. [ ] Expand test harness:
   - Support 2000, 3000 node scenarios
   - 30–60 min sustained runs
   - Prometheus snapshot export

### Week 3–4

7. [ ] Phase 4 extensions:
   - FedAvg variant matrix
   - Convergence curve tracking
   - Extend speedup table

8. [ ] Phase 5 setup:
   - Docker-compose scaling validation
   - 5k node test dry-run
   - Metrics export pipeline (Parquet/S3)

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Sustained 1500-node throughput | ≥ 1500 req/sec (vs current 1887) |
| Semi-async overhead | ≤ 5% latency increase for +20% throughput |
| Hierarchical speedup | ≥ 2x latency reduction at 3000 nodes |
| Byzantine filtering | ≥ 95% accuracy preservation with weighted trimming |
| Convergence curve | ≤ 50 rounds to 0.85 accuracy |
| 5k node readiness | All metrics exported, no errors |

---

## References

- `/internall/straggler_resilience.go` – Theorem 4 implementation
- `/proofs/communication.md` – Byzantine resilience proofs
- `/captured_artifacts/extended_stress_200cycle_2026-04-13.md` – Recent stress baseline
- `./go.mod` – Prometheus client libs already included
