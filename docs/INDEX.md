# Sovereign-Mohawk Documentation Index

**Last Updated:** May 9, 2026  
**Status:** Complete with Phase 4 Production Deployment

---

## Quick Navigation

- **[Getting Started](GETTING_STARTED.md)** - Installation, quickstart, first steps
- **[Architecture Guide](ARCHITECTURE.md)** - System design, component overview
- **[API Reference](API_REFERENCE.md)** - Go packages, gRPC services, Python SDK
- **[Deployment Guide](DEPLOYMENT.md)** - Docker, Kubernetes, Cloud deployment
- **[Operations Guide](OPERATIONS.md)** - Monitoring, troubleshooting, runbooks
- **[Security](SECURITY.md)** - PQC, TPM, Byzantine resilience, compliance
- **[Archive Index](archive/root-cleanup-2026-04/README.md)** - Historical root cleanup inventory

---

## Implementation Phases

### Phase 1: Foundation & Formal Verification
- [Formal Verification Guide](FORMAL_VERIFICATION_GUIDE.md) - Lean proofs, traceability matrix
- [Byzantine Resilience Architecture](architecture/BYZANTINE_RESILIENCE.md) - Multi-Krum filtering
- [Differential Privacy](architecture/DIFFERENTIAL_PRIVACY.md) - RDP accounting

### Phase 2: Streaming & Core Aggregation
- [Streaming Aggregator](architecture/STREAMING_AGGREGATOR.md) - Chunk assembly, batching
- [Transport Layer](architecture/TRANSPORT_LAYER.md) - Multi-path packet spraying
- [Integration Points](architecture/INTEGRATION_POINTS.md) - Byzantine, DP hooks

### Phase 3: Multi-Tier Federation
- [Federation Protocol](architecture/FEDERATION_PROTOCOL.md) - Tier hierarchy, RPC
- [Gossip Protocol](architecture/GOSSIP_PROTOCOL.md) - Node discovery, health monitoring
- [Routing & Topology](architecture/ROUTING_TOPOLOGY.md) - DAG consistency, failover

### Phase 4: Production Deployment
- **[Production Deployment](PHASE_4_PRODUCTION_DEPLOYMENT.md)** - Docker, K8s, Cloud, operations
- [Performance Benchmarks](BENCHMARKS_AND_REPRODUCIBILITY.md) - Throughput, latency, tuning
- [Post-Deployment Validation](guides/POST_DEPLOYMENT_VALIDATION.md) - Smoke tests, runbooks

---

## Core Documentation

### Architecture & Design
```
docs/architecture/
├── BYZANTINE_RESILIENCE.md         - Multi-Krum, Byzantine tolerance
├── DIFFERENTIAL_PRIVACY.md          - RDP, epsilon accounting
├── STREAMING_AGGREGATOR.md          - Hot-path ingestion, reassembly
├── TRANSPORT_LAYER.md               - MRC packet spraying
├── FEDERATION_PROTOCOL.md           - Cross-tier communication
├── GOSSIP_PROTOCOL.md               - Component discovery
├── ROUTING_TOPOLOGY.md              - DAG routing, consistency
└── INTEGRATION_POINTS.md            - Hook architecture
```

### Deployment & Operations
```
docs/guides/
├── GETTING_STARTED.md               - Installation, quickstart
├── DEPLOYMENT.md                    - Docker, K8s, Cloud templates
├── DOCKER_DEPLOYMENT.md             - Docker Compose, image building
├── KUBERNETES_DEPLOYMENT.md         - EKS, GKE, AKS setup
├── CLOUD_DEPLOYMENT.md              - AWS, GCP, Azure templates
├── OPERATIONS.md                    - Monitoring, troubleshooting
├── MONITORING_OBSERVABILITY.md      - Prometheus, Grafana, Jaeger
├── TROUBLESHOOTING.md               - Common issues, solutions
├── POST_DEPLOYMENT_VALIDATION.md    - Smoke tests, validation matrix
├── SCALING_OPERATIONS.md            - Tier scaling, auto-scaling
└── FAILOVER_RECOVERY.md             - Disaster recovery runbooks
```

### API & Integration
```
docs/api/
├── API_REFERENCE.md                 - Go packages, types, methods
├── PYTHON_SDK_GUIDE.md              - Python SDK examples
├── GRPC_SERVICES.md                 - Service definitions, endpoints
├── WEBHOOK_INTEGRATION.md           - Event webhooks, callbacks
├── REST_API.md                      - HTTP endpoints
└── EXAMPLES.md                      - Code samples, patterns
```

### Security & Compliance
```
docs/security/
├── SECURITY.md                      - PQC, TPM, XMSS
├── COMPLIANCE.md                    - EU AI Act, regulatory alignment
├── THREAT_MODEL.md                  - Attack scenarios, mitigations
├── INCIDENT_RESPONSE.md             - Response procedures
├── SUPPLY_CHAIN_SECURITY.md         - Artifact verification
└── VULNERABILITY_DISCLOSURE.md      - Responsible disclosure
```

### Performance & Benchmarking
```
docs/performance/
├── BENCHMARKS_AND_REPRODUCIBILITY.md - Full benchmark suite
├── PERFORMANCE_TUNING.md            - Parameter optimization
├── LOAD_TESTING.md                  - Stress test scenarios
├── PROFILING_GUIDE.md               - CPU, memory profiling
├── RESOURCE_REQUIREMENTS.md         - Hardware recommendations
└── PERFORMANCE_REGRESSION.md        - CI gates, thresholds
```

### Formal Verification & Proofs
```
docs/formal-verification/
├── FORMAL_VERIFICATION_GUIDE.md     - Lean setup, verification
├── THEOREM_SPECIFICATIONS.md        - 6 theorem claims
├── PROOF_TRACEABILITY_MATRIX.md     - Claim → Proof → Runtime Evidence
├── PROOF_CHECKLIST.md               - Lean verification checklist
└── EXTENDING_PROOFS.md              - Adding new theorems
```

### Examples & Tutorials
```
docs/examples/
├── QUICKSTART_PYTORCH.md            - PyTorch federated learning
├── QUICKSTART_TENSORFLOW.md         - TensorFlow federated learning
├── FLOWER_INTEGRATION.md            - Flower framework integration
├── CUSTOM_AGGREGATION.md            - Custom aggregation functions
├── BYZANTINE_ATTACK_SIMULATION.md   - Intentional Byzantine nodes
├── MONITORING_SETUP.md              - Full monitoring stack
└── MULTI_CLOUD_DEPLOYMENT.md        - Cross-cloud federation
```

---

## Documentation Organization Strategy

### Root Level (`/docs/`)
Only index and quick reference files:
- `INDEX.md` (this file) - Central navigation hub
- `README.md` - Docs overview
- `ARCHITECTURE.md` - System overview (1 page)
- `PHASE_4_PRODUCTION_DEPLOYMENT.md` - Latest phase summary

### Subdirectories
- `architecture/` - System design deep dives (8-15 pages each)
- `guides/` - Step-by-step operational procedures (10-20 pages each)
- `api/` - API documentation and examples (5-10 pages each)
- `security/` - Security, compliance, threat model (5-10 pages each)
- `performance/` - Benchmarks, tuning, profiling (5-15 pages each)
- `formal-verification/` - Lean proofs, specifications (20+ pages total)
- `examples/` - Working code samples, tutorials (5-10 pages each)
- `archive/` - Deprecated/historical documentation with dated inventory pages
- `tdf/` - Trusted Datacenter Federation specifications

---

## Documentation Maintenance

### Version Control
- Major version docs: Tagged with release version
- API docs: Maintained in sync with `go.mod`
- Examples: Updated with each SDK release
- Benchmarks: Refreshed with each performance gate

### PR Review Process
1. New documentation added in appropriate `docs/` subdirectory
2. Link updated in relevant `INDEX.md` or section README
3. No documentation files should exist in repo root (except README.md)
4. Cross-references validated before merge

### Refresh Cadence
- **Weekly:** Performance benchmarks, operational metrics
- **Monthly:** Examples, tutorials, integrations
- **Quarterly:** Architecture diagrams, API reference
- **Annually:** Compliance, security audit findings

---

## Quick Lookup by Role

### For Developers
1. [Getting Started](guides/GETTING_STARTED.md)
2. [API Reference](api/API_REFERENCE.md)
3. [Architecture Overview](ARCHITECTURE.md)
4. [Examples](examples/)
5. [Testing & Development](guides/DEVELOPMENT.md)

### For DevOps / SRE
1. [Deployment Guide](guides/DEPLOYMENT.md)
2. [Operations Guide](guides/OPERATIONS.md)
3. [Monitoring & Observability](guides/MONITORING_OBSERVABILITY.md)
4. [Scaling Operations](guides/SCALING_OPERATIONS.md)
5. [Troubleshooting](guides/TROUBLESHOOTING.md)

### For Security Officers
1. [Security Overview](security/SECURITY.md)
2. [Compliance](security/COMPLIANCE.md)
3. [Threat Model](security/THREAT_MODEL.md)
4. [Incident Response](security/INCIDENT_RESPONSE.md)
5. [Supply Chain](security/SUPPLY_CHAIN_SECURITY.md)

### For Data Scientists
1. [Getting Started](guides/GETTING_STARTED.md)
2. [Python SDK Guide](api/PYTHON_SDK_GUIDE.md)
3. [Examples](examples/)
4. [Custom Aggregation](examples/CUSTOM_AGGREGATION.md)
5. [Performance Tuning](performance/PERFORMANCE_TUNING.md)

### For Researchers
1. [Formal Verification](formal-verification/FORMAL_VERIFICATION_GUIDE.md)
2. [Theorem Specifications](formal-verification/THEOREM_SPECIFICATIONS.md)
3. [Byzantine Resilience Architecture](architecture/BYZANTINE_RESILIENCE.md)
4. [Differential Privacy](architecture/DIFFERENTIAL_PRIVACY.md)
5. [Academic Paper](../ACADEMIC_PAPER.md)

---

## Documentation Status

### Complete ✅
- [x] Phase 1 Documentation (Formal Verification, Foundation)
- [x] Phase 2 Documentation (Streaming, Transport, Core)
- [x] Phase 3 Documentation (Federation, Multi-Tier)
- [x] Phase 4 Documentation (Production Deployment)
- [x] Architecture guides (8 modules)
- [x] Deployment guides (6-7 templates)
- [x] Security documentation (5 documents)
- [x] Performance benchmarks (continuous)
- [x] Examples and tutorials (6-8 samples)
- [x] Formal proofs and specifications
- [x] API reference (Go, Python, gRPC)

### In Progress 🔄
- Publishing guides to external wiki
- Adding video tutorials
- Community contribution examples

### Planned 📋
- Multi-language documentation (Chinese, Spanish, German)
- Academy/certification program
- Integration partner documentation

---

## Contributing to Documentation

### Adding New Documentation
1. Place file in appropriate `docs/subdirectory/`
2. Use template from `docs/CONTRIBUTING_DOCS.md`
3. Cross-reference from relevant index page
4. Submit PR with documentation changes

### Updating Existing Documentation
1. Make changes in appropriate file
2. Verify all cross-references still valid
3. Run link checker: `make validate-docs-links`
4. Submit PR with documentation changes

### Documentation Standards
- **Format:** Markdown (GitHub-flavored)
- **Max Length:** 30 pages per document (split if longer)
- **Code Examples:** Must be tested and reproducible
- **Links:** Must be relative (within docs/) or absolute (to main repo)
- **Diagrams:** Use Mermaid or ASCII art, no images
- **Tables:** Use markdown format, max 10 rows per table

---

## Feedback & Issues

**Have a documentation issue?**
- Report: [GitHub Issues](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
- Discuss: [GitHub Discussions](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/discussions)
- Contribute: See [CONTRIBUTING.md](../CONTRIBUTING.md)

**Need something clarified?**
- Check this index first
- Search existing issues
- Open new issue with `docs` label
- Propose improvement via PR

---

## Related Resources

- **GitHub Repository:** https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto
- **Academic Paper:** [ACADEMIC_PAPER.md](../ACADEMIC_PAPER.md)
- **White Paper:** [WHITE_PAPER.md](../WHITE_PAPER.md)
- **Roadmap:** [ROADMAP.md](../ROADMAP.md)
- **Contributing:** [CONTRIBUTING.md](../CONTRIBUTING.md)
- **Security Policy:** [SECURITY.md](security/SECURITY.md)

---

**Last Updated:** May 9, 2026  
**Maintainer:** Sovereign-Mohawk Core Team  
**License:** Apache 2.0
