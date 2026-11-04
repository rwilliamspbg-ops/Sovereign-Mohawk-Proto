# gRPC Federation Service Reference

**Status**: Real content as of 2026-11-04; verified against
`api/federation/federation.proto`.
**Package**: `federation`
**Go package**: `github.com/sovereign-mohawk/proto-gen/federation;federationpb`

## Service: FederationService

Handles gradient forwarding and aggregation across tiers (L1 to L4).

| RPC | Request | Response | Type |
|---|---|---|---|
| `ForwardGradient` | `GradientRequest` | `ForwardResponse` | unary |
| `ForwardBatch` | `BatchRequest` | `ForwardResponse` | unary |
| `ReceiveGradients` | stream `GradientStreamMessage` | stream `AggregationStreamResponse` | bidirectional |

## Messages

### GradientRequest

Single gradient forwarded to parent tier.

| Field | Number | Type | Description |
|---|---|---|---|
| gradient_id | 1 | string | Gradient identity |
| source_node_id | 2 | string | Originating node |
| source_tier_node_id | 3 | string | Tier node id |
| aggregation_round | 4 | uint64 | Round number |
| dimension_count | 5 | int32 | Tensor dimensionality |
| gradient_data | 6 | repeated double (packed) | Gradient values |
| norm | 7 | double | Gradient norm |
| timestamp | 8 | google.protobuf.Timestamp | Creation time |
| path_hops | 9 | repeated string | Breadcrumb trail |
| proof | 10 | bytes | Byzantine resilience proof |

### BatchRequest

| Field | Number | Type | Description |
|---|---|---|---|
| gradients | 1 | repeated GradientRequest | Gradients to forward |
| batch_id | 2 | string | Batch identifier |
| batch_size | 3 | int32 | Number of gradients |

### ForwardResponse

| Field | Number | Type | Description |
|---|---|---|---|
| success | 1 | bool | Whether accepted |
| message | 2 | string | Status message |
| accepted_count | 3 | int32 | Gradients accepted |
| server_process_time_ms | 4 | int64 | Server processing time |

### GradientStreamMessage

Sent by child nodes to parent (stream client to server).

| Field | Number | Type | Description |
|---|---|---|---|
| source_node_id | 1 | string | Originating node |
| source_tier_node_id | 2 | string | Tier node id |
| gradients | 3 | repeated SingleGradient | One or more gradients |
| aggregation_round | 4 | uint64 | Round number |
| timestamp | 5 | google.protobuf.Timestamp | Creation time |

### SingleGradient

| Field | Number | Type | Description |
|---|---|---|---|
| gradient_id | 1 | string | Gradient identity |
| dimension_count | 2 | int32 | Tensor dimensionality |
| gradient_data | 3 | repeated double (packed) | Gradient values |
| norm | 4 | double | Gradient norm |
| proof | 5 | bytes | Byzantine resilience proof |

### AggregationStreamResponse

Sent by parent to children (stream server to client).

| Field | Number | Type | Description |
|---|---|---|---|
| gradient_id | 1 | string | Acknowledged gradient |
| received | 2 | bool | Whether received |
| aggregation_status | 3 | string | "received" / "processing" / "aggregated" |
| server_process_time_ms | 4 | int64 | Server processing time |
| timestamp | 5 | google.protobuf.Timestamp | Response time |
| round_result | 6 | AggregationResult | Batch result when round complete |

### AggregationResult

| Field | Number | Type | Description |
|---|---|---|---|
| round_id | 1 | uint64 | Round identifier |
| tier_node_id | 2 | string | Aggregating tier node |
| aggregated_count | 3 | int32 | Gradients aggregated |
| skipped_count | 4 | int32 | Byzantine-filtered count |
| gradient_result | 5 | repeated double (packed) | Aggregated gradient |
| gradient_norm | 6 | double | Aggregated norm |
| aggregation_time_ms | 7 | int64 | Aggregation duration |
| aggregation_method | 8 | string | "mean" / "median" / "multikrum" / etc. |

### HealthCheckRequest / HealthCheckResponse

| Message | Field | Number | Type |
|---|---|---|---|
| HealthCheckRequest | tier_node_id | 1 | string |
| HealthCheckResponse | healthy | 1 | bool |
| HealthCheckResponse | latency_ms | 2 | double |
| HealthCheckResponse | packet_loss | 3 | double |
| HealthCheckResponse | gradients_forwarded | 4 | int64 |
| HealthCheckResponse | gradients_received | 5 | int64 |
| HealthCheckResponse | last_check | 6 | google.protobuf.Timestamp |

## Regeneration

This document is hand-maintained from `api/federation/federation.proto`.
When the proto changes, update this file in the same PR. A future
`make docs-api` target will regenerate it automatically (open item).
