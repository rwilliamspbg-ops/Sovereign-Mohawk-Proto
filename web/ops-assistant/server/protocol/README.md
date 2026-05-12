# Protocol Starter Pack

This directory contains the initial typed contracts for protocol-driven UI integration.

## Files
- `ag-ui-events.schema.json`: JSON Schema for AG-UI event envelopes.
- `a2ui-envelope.schema.json`: JSON Schema for A2UI payload envelopes.
- `types.ts`: Runtime validators and TypeScript types backed by zod.

## Usage
1. Validate outbound AG-UI event payloads against `AgUiEventSchema`.
2. Validate outbound A2UI layout payloads against `A2UiEnvelopeSchema`.
3. Version new contract changes by bumping `version` and maintaining backward compatibility.

## Notes
- These are intentionally minimal starter contracts for incremental adoption.
- Keep this contract versioned with app releases and CI schema checks.
