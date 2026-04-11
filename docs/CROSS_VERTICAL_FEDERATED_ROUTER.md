# Cross-Vertical Federated Router

This module turns Sovereign-Mohawk-Proto into a switching layer for verifiable intelligence transfer between domain silos.

## What It Adds

- Policy-gated discovery: `internal/router.PolicyEngine` controls source->target vertical routes.
- TPM-gated identities: publishers and subscribers are attested before offer publish/subscribe.
- zk-backed trust checks: optional proof validation for insight offers.
- Model-agnostic translation: schema-level gradient remapping via `SchemaTranslator`.
- Cross-domain provenance ledger: append-only hash-chained records for impact audit trails.

## Package Layout

- `internal/router/router.go`: publish, subscribe, discover, provenance APIs.
- `internal/router/policy.go`: route allow/block engine.
- `internal/router/translation.go`: schema translation and WASM module guardrail validation.
- `internal/router/provenance.go`: immutable record chain.
- `cmd/federated-router/main.go`: minimal HTTP service exposing router endpoints.

## HTTP Endpoints

- `POST /router/publish`
- `POST /router/subscribe`
- `GET /router/discover?subscriber_vertical=<vertical>`
- `POST /router/provenance`
- `GET /router/provenance`
- `GET /metrics`

## Runtime Configuration

- `MOHAWK_ROUTER_ADDR` (default `:8087`)
- `MOHAWK_ROUTER_ALLOWED_ROUTES`
- `MOHAWK_ROUTER_PROVENANCE_PATH` (optional persisted provenance JSON file)
- `MOHAWK_ROUTER_ALLOW_INSECURE_DEV_QUOTES` (dev-only, default `false`)

`MOHAWK_ROUTER_ALLOWED_ROUTES` format example:

```text
climate->agriculture,climate->supply-chain,oncology->supply-chain
```

## Build

```bash
go build ./cmd/federated-router
```

## Test

```bash
go test ./internal/router
go test ./cmd/federated-router
```

## Local Compose Validation

```bash
docker compose up -d runtime-secrets-init federated-router prometheus
./scripts/router_smoke_discovery.sh
```

The smoke script publishes a Climate insight, subscribes Supply Chain, verifies discovery, records provenance, and confirms retrieval.

## Threat Model Notes

- Policy bypass attempts:
	Route ACLs are default-deny and evaluated on subscription and discovery. Blocked and policy-rejected attempts are exported via `mohawk_router_requests_total`.
- Forged quote attempts:
	Publisher/subscriber identity quotes are verified by TPM attestation (`tpm.Verify`) unless explicit dev override is enabled.
- Proof replay/tampering:
	Publish operations with `expected_proof_root` enforce proof validation; failures are surfaced as `reason="proof_verification"` and alertable.

## Router SLO Targets

- Publish success ratio: `>= 99.0%` over 30 days.
- Subscribe success ratio: `>= 99.0%` over 30 days.
- Discover availability: `>= 99.9%` over 30 days.
- Proof verification failures: `0` tolerated in steady state.

## Prometheus Signals and Alerts

- Metrics:
	`mohawk_router_requests_total`, `mohawk_router_provenance_records`.
- Alerts:
	`MohawkRouterRejectedRequestsHigh`, `MohawkRouterBlockedRouteSpike`, `MohawkRouterProofVerificationFailuresPresent`.
