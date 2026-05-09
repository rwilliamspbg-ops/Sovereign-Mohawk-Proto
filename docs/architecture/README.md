# System Architecture Overview

---

## MRC Transport Layer

**File:** `transport/ARCHITECTURE.md`

- Multi-path packet spraying (2-4 concurrent paths)
- Adaptive path scoring (0.0-1.0 health metric)
- Chunk integrity verification (SHA256)
- Health monitoring (latency, packet loss, throughput)
- Context-aware cancellation
- Performance: 2,525 chunks/sec

---

## Streaming Aggregator

**File:** `streaming/ARCHITECTURE.md`

- Non-blocking hot-path ingestion
- Out-of-order chunk reassembly
- Multi-tensor concurrent buffering
- Timeout-based batch flushing (500ms default)
- Stale buffer eviction (60s TTL)
- Byzantine filter integration hooks
- Performance: 160K+ ops/sec

---

## Multi-Tier Federation

**File:** `federation/ARCHITECTURE.md`

- Regional → Continental → Global hierarchy
- Parent-child RPC protocol (forward & batch)
- Per-tier health monitoring
- Exponential backoff with jitter
- Circuit breaker overflow protection
- Breadcrumb trail for audit

---

## Byzantine Resilience

**File:** `BYZANTINE_RESILIENCE.md`

- Multi-Krum gradient filtering
- Configurable Byzantine tolerance (0.33× default)
- Per-tier Byzantine thresholds
- Anomaly detection and isolation

---

## Differential Privacy

**File:** `DIFFERENTIAL_PRIVACY.md`

- RDPAccountant epsilon tracking
- Per-aggregation noise injection
- Cross-tier epsilon composition

---

See [INDEX.md](../INDEX.md) for complete documentation navigation.
