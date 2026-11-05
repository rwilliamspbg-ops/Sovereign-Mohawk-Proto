# Gossip Protocol

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Node discovery and health monitoring across the federation.

- Implementation: `internal/federation/` (health tracking via `FederationHealth`); gossip-style discovery is part of the federation package.

## 2. Health tracking

`FederationHealth` (in `internal/federation/types.go`) tracks tier-to-tier link status. Health checks use `HealthCheckRequest` / `HealthCheckResponse` from the federation proto.

## 3. Open items

- A standalone gossip module with explicit fanout/anti-entropy parameters is not present as a separate package; discovery is folded into the federation coordinator. If a dedicated gossip protocol is needed, it is a roadmap item.

## 4. Cross-references

- Federation protocol: `docs/architecture/FEDERATION_PROTOCOL.md`
- Routing/topology: `docs/architecture/ROUTING_TOPOLOGY.md`
