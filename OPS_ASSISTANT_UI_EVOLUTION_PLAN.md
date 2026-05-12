# Ops Assistant UI Evolution Plan

## Objective
Evolve the Ops Assistant into a production-grade, user-friendly, multi-persona AI operations UI using:
- A2UI (Google DeepMind) for interactive protocol-driven UI payloads
- AG-UI (CopilotKit) for agent-to-frontend transport/events
- CopilotKit for embedded copilot UX in React
- MCP Apps for live, structured tool UIs

## Current State Summary
- CopilotKit chat is present, but the app is not wired as a protocol-native A2UI/AG-UI experience.
- Metrics and dashboard views are mostly custom widgets with hardcoded local URLs.
- Multiple backend actions exist, but runtime orchestration is not integrated end-to-end with a role-aware UX.

## User Personas and UX Targets
1. SRE / NOC Operator
- Needs: fast incident triage, alert context, one-click runbooks, low-noise defaults.
- UX target: command palette + alert timeline + guided remediation cards.

2. Platform Engineer
- Needs: PromQL exploration, dashboard composition, topology and capacity analysis.
- UX target: split workspace (chat + panels), query/result explainers, exportable insights.

3. Security / Compliance Analyst
- Needs: auditability, provenance, policy status, cryptographic health visibility.
- UX target: compliance cockpit, immutable event trace, policy drift warnings.

4. Executive / Program Manager
- Needs: plain-language status, SLA risk, trend summaries.
- UX target: read-only narrative briefings and KPI scorecards.

5. Developer / Integrator
- Needs: predictable API contracts, embeddable components, testability.
- UX target: typed protocol schemas, mock harness, integration cookbook.

## Architecture Blueprint
### Frontend (React + CopilotKit)
- Introduce a unified shell with role-based navigation, not separate hardcoded pages.
- Keep CopilotKit as primary conversational surface.
- Add A2UI render zone for agent-sent interactive cards/forms/tables.
- Add MCP App dock for live tools (logs, traces, dashboards, approvals).

### Transport and Protocol
- Standardize all agent UI updates as AG-UI events.
- Use A2UI payloads for interactive widgets and action callbacks.
- Define message contract versioning (schema version + backward compatibility guards).

### Backend Runtime
- Introduce a dedicated agent runtime gateway endpoint for CopilotKit and AG-UI streams.
- Register advanced actions as tools with role-aware policy checks.
- Add observability for tool calls, latency, failures, and user flow completion.

## Phased Delivery Plan
## Phase 0 (2-3 days): Stabilize Baseline
- Replace hardcoded localhost URLs with environment-driven config.
- Add connection/retry states for WebSocket and API calls.
- Remove static quick-stats placeholders and bind to real health endpoints.
- Add smoke tests for chat, metrics, dashboards, and health.

Acceptance criteria:
- UI works from compose, local dev, and non-localhost deployments.
- No broken view when backend or Grafana is unavailable.

## Phase 1 (1 week): AG-UI Foundation
- Implement AG-UI event pipeline between backend runtime and frontend.
- Convert current ad hoc message patterns to typed event envelopes.
- Add frontend event store (connection state, inflight actions, streamed outputs).
- Add replay panel for recent agent events (debug mode).

Acceptance criteria:
- Every tool invocation and UI mutation is represented as AG-UI events.
- Event stream survives reconnect and resumes safely.

## Phase 2 (1 week): A2UI Interactive Surfaces
- Add A2UI renderer region in main workspace.
- Create canonical A2UI components for:
  - Alert triage card
  - Metric drill-down table/chart
  - Runbook stepper with approvals
  - Incident timeline
- Backend emits A2UI payloads based on context and user role.

Acceptance criteria:
- At least 4 critical workflows execute through agent-sent A2UI components.
- UI fallback exists when a component payload is invalid.

## Phase 3 (1 week): MCP Apps Integration
- Add MCP App host zone with discoverable app launcher.
- Integrate core MCP apps:
  - Prometheus explorer
  - Grafana deep-link viewer
  - Alert manager console
  - Audit/provenance viewer
- Define app-to-agent context handoff (selected entity, time range, filters).

Acceptance criteria:
- Users can open MCP apps from chat context and return without losing state.
- Agent can reference MCP app outputs in subsequent responses.

## Phase 4 (1 week): Persona UX and Accessibility
- Build role-specific home layouts and onboarding prompts.
- Add keyboard-first navigation, focus management, and WCAG contrast fixes.
- Add internationalization-ready copy keys.
- Add explainability layer: "why this suggestion" and confidence labels.

Acceptance criteria:
- Each persona has a default view with relevant cards and actions.
- Keyboard-only completion path for top 5 workflows.

## Phase 5 (3-5 days): Hardening and Launch
- Add authN/authZ middleware and per-tool authorization.
- Add rate limiting, audit logs, and PII redaction in chat/events.
- Load/perf test AG-UI stream and A2UI render throughput.
- Release checklist + rollback + canary deployment.

Acceptance criteria:
- Security review passes for runtime endpoints and tool execution.
- p95 chat-to-first-token and tool-to-first-UI-update SLOs met.

## Backlog by Track
### UX Track
- Unified command bar (ask + act)
- Incident workspace templates
- Progressive disclosure for novice vs expert

### Data Track
- Metric semantic layer (human-friendly metric aliases)
- Time range synchronization across chat and panels
- Derived KPI service for executive summaries

### Reliability Track
- Circuit breakers for external dependencies
- Offline/error states with actionable retries
- Contract tests for AG-UI and A2UI schema changes

### Governance Track
- Role matrix for tool permissions
- Action confirmation policies (destructive vs read-only)
- Compliance evidence export

## Test Strategy
- Unit: payload builders, policy guards, event reducers.
- Integration: AG-UI stream + A2UI render + MCP app launch flows.
- E2E: top workflows per persona (incident triage, dashboard explain, anomaly response).
- Chaos: injected Prometheus/Grafana/API failures with graceful degradation assertions.

## Metrics and Success KPIs
- User productivity:
  - Mean time to detect (MTTD) and resolve (MTTR)
  - % incidents resolved with guided workflow
- UX quality:
  - Task completion rate by persona
  - Error/retry rate per workflow
- Platform health:
  - AG-UI stream reconnect success rate
  - A2UI render failure rate
  - Tool call success/latency distribution

## Immediate Next Sprint (Concrete)
1. Replace hardcoded endpoints with environment config and shared URL builder.
2. Implement AG-UI typed event schema and frontend event bus.
3. Add A2UI renderer zone and first two components (alert triage, metric drill-down).
4. Integrate first MCP app (Prometheus explorer) with context handoff.
5. Add role model scaffolding and hide unauthorized tools.
6. Add E2E smoke pack for operator + engineer personas.

## Deliverables
- Updated frontend architecture diagram
- Typed protocol contracts (AG-UI events + A2UI payload schema)
- Persona-specific UX flows
- Security and reliability checklists
- Release-ready runbook for ops-assistant deployment
