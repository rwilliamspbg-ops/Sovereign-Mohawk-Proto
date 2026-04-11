# Router Integration Validation (Published Docker Images)

- Date (UTC): 2026-04-11
- Validation scope: published `:main` images in GHCR
- Validation status: PASS

## Images Validated

- `ghcr.io/rwilliamspbg-ops/sovereign-mohawk-orchestrator:main`
  - digest: `sha256:ca9c041b490be43eb0ae452dd8855d1f9158451b673695c2b237c54eb922af6a`
- `ghcr.io/rwilliamspbg-ops/sovereign-mohawk-node-agent:main`
  - digest: `sha256:e946cbc553e15e53e3949f4208ab76b574cfece7bf7ef4b2ef3e6147238cbc87`
- `ghcr.io/rwilliamspbg-ops/sovereign-mohawk-fl-aggregator:main`
  - digest: `sha256:948d5bc49a674cb985e69d92f3e8dc9567ddb2db3ad6a02532aa8570593611fe`
- `ghcr.io/rwilliamspbg-ops/sovereign-mohawk-api-dashboard:main`
  - digest: `sha256:fd0aa63e9c2c3b4c7f36f37b263572511da6a7f3f1a7256d158689347dfc1960`

## Router Integration Probe

Validation method:

1. Pull published `node-agent:main` image from GHCR.
2. Start a local mock router endpoint that accepts:
   - `POST /router/publish`
   - `POST /router/provenance`
3. Run published node-agent image with router URL set to the mock endpoint.
4. Confirm mock router receives both publish and provenance payloads.

Observed mock-router requests:

- `POST /router/publish` with keys:
  - `expected_proof_root`, `model_id`, `offer_id`, `publisher_node_id`, `publisher_quote`, `source_vertical`, `summary`
- `POST /router/provenance` with keys:
  - `impact_delta`, `impact_metric`, `offer_id`, `source_vertical`, `subscriber_model`, `target_vertical`

Observed node-agent runtime markers:

- `Node Agent operational. Entering supervised runtime loop...`
- Router endpoints were reached successfully during startup and supervisor cycle.

## Conclusion

Published Docker images include working node-agent router integration path (`/router/publish` and `/router/provenance`) and are suitable for production integration testing and release evidence trails.
